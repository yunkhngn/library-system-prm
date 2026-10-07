package com.library.checkin.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.library.checkin.dto.*;
import com.library.checkin.entity.LibraryState;
import com.library.checkin.entity.SystemConfigEntity;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.LibraryStateRepository;
import com.library.checkin.repository.SystemConfigRepository;
import com.library.checkin.repository.UserRepository;
import org.springframework.http.HttpStatus;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;

@Service
public class SystemConfigService {

    private final SystemConfigRepository repository;
    private final UserRepository userRepository;
    private final LibraryStateRepository libraryStateRepository;
    private final com.library.checkin.repository.CheckinLogRepository checkinLogRepository;
    private final ObjectMapper objectMapper;
    private final SimpMessagingTemplate messagingTemplate;

    public SystemConfigService(SystemConfigRepository repository,
                               UserRepository userRepository,
                               LibraryStateRepository libraryStateRepository,
                               com.library.checkin.repository.CheckinLogRepository checkinLogRepository,
                               ObjectMapper objectMapper,
                               SimpMessagingTemplate messagingTemplate) {
        this.repository = repository;
        this.userRepository = userRepository;
        this.libraryStateRepository = libraryStateRepository;
        this.checkinLogRepository = checkinLogRepository;
        this.objectMapper = objectMapper;
        this.messagingTemplate = messagingTemplate;
    }

    @Transactional(readOnly = true)
    public SystemConfig getOperational() {
        SystemConfigEntity entity = repository.findById("operational")
                .orElseThrow(() -> new IllegalStateException("Operational configuration missing in database"));

        return toDto(entity);
    }

    @Transactional
    public SystemConfig updateOperational(PatchSystemConfigRequest request, UUID adminUserId) {
        SystemConfigEntity entity = repository.findById("operational")
                .orElseThrow(() -> new IllegalStateException("Operational configuration missing in database"));

        if (!Objects.equals(request.version(), entity.getVersion())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "System configuration version conflict");
        }

        // Validate that at least one field besides version is present
        boolean hasUpdate = request.timezone() != null
                || request.openingHours() != null
                || request.maxCapacity() != null
                || request.nearCapacityRatio() != null
                || request.capacityEnforcement() != null
                || request.maxSessionDurationMinutes() != null
                || request.scanCooldownSeconds() != null
                || request.faceModelVersion() != null
                || request.faceMaxCosineDistance() != null
                || request.faceMinDistanceGap() != null
                || request.livenessMinScore() != null;

        if (!hasUpdate) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "At least one field must be updated");
        }

        // 1. Timezone validation
        if (request.timezone() != null && !"Asia/Ho_Chi_Minh".equals(request.timezone())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Timezone must be Asia/Ho_Chi_Minh");
        }

        // 2. Opening hours validation
        if (request.openingHours() != null) {
            if (request.openingHours().size() > 7) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "openingHours cannot exceed 7 days");
            }
            Set<Integer> seenDays = new HashSet<>();
            for (OpeningSlot slot : request.openingHours()) {
                if (slot.dayOfWeek() < 1 || slot.dayOfWeek() > 7) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "dayOfWeek must be between 1 and 7");
                }
                if (!seenDays.add(slot.dayOfWeek())) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Duplicate dayOfWeek in openingHours");
                }
                if (slot.opensAt() == null || slot.closesAt() == null) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "opensAt and closesAt required");
                }
                try {
                    LocalTime opens = LocalTime.parse(slot.opensAt());
                    LocalTime closes = LocalTime.parse(slot.closesAt());
                    if (opens.equals(closes)) {
                        throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "opensAt=closesAt is invalid");
                    }
                } catch (Exception e) {
                    if (e instanceof ApiException) throw (ApiException) e;
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Invalid time format for opening hours");
                }
            }
        }

        // 3. Capacity validation
        if (request.maxCapacity() != null && (request.maxCapacity() < 1 || request.maxCapacity() > 100000)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "maxCapacity must be between 1 and 100000");
        }

        if (request.nearCapacityRatio() != null && (request.nearCapacityRatio() < 0.1 || request.nearCapacityRatio() > 1.0)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "nearCapacityRatio must be between 0.1 and 1.0");
        }

        if (request.maxSessionDurationMinutes() != null && (request.maxSessionDurationMinutes() < 1 || request.maxSessionDurationMinutes() > 10080)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "maxSessionDurationMinutes must be between 1 and 10080");
        }

        if (request.scanCooldownSeconds() != null && (request.scanCooldownSeconds() < 1 || request.scanCooldownSeconds() > 60)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "scanCooldownSeconds must be between 1 and 60");
        }

        // 4. Biometrics / Calibration group validation
        boolean anyCalibration = request.faceModelVersion() != null
                || request.faceMaxCosineDistance() != null
                || request.faceMinDistanceGap() != null
                || request.livenessMinScore() != null;

        if (anyCalibration) {
            if (request.faceMaxCosineDistance() != null && (request.faceMaxCosineDistance() < 0.0 || request.faceMaxCosineDistance() > 2.0)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "faceMaxCosineDistance must be between 0.0 and 2.0");
            }
            if (request.faceMinDistanceGap() != null && (request.faceMinDistanceGap() < 0.0 || request.faceMinDistanceGap() > 2.0)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "faceMinDistanceGap must be between 0.0 and 2.0");
            }
            if (request.livenessMinScore() != null && (request.livenessMinScore() < 0.0 || request.livenessMinScore() > 1.0)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "livenessMinScore must be between 0.0 and 1.0");
            }
            if (request.faceModelVersion() != null && (request.faceModelVersion().isBlank() || request.faceModelVersion().length() > 128)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "faceModelVersion must be 1 to 128 characters");
            }
        }

        // Read and mutate JSONB
        try {
            ObjectNode root = (ObjectNode) objectMapper.readTree(entity.getValue());

            if (request.timezone() != null) {
                root.put("timezone", request.timezone());
            }
            if (request.openingHours() != null) {
                ArrayNode hoursNode = root.putArray("openingHours");
                for (OpeningSlot slot : request.openingHours()) {
                    ObjectNode slotObj = hoursNode.addObject();
                    slotObj.put("dayOfWeek", slot.dayOfWeek());
                    slotObj.put("opensAt", slot.opensAt());
                    slotObj.put("closesAt", slot.closesAt());
                }
            }
            if (request.maxCapacity() != null) {
                root.put("maxCapacity", request.maxCapacity());
            }
            if (request.nearCapacityRatio() != null) {
                root.put("nearCapacityRatio", request.nearCapacityRatio());
            }
            if (request.capacityEnforcement() != null) {
                root.put("capacityEnforcement", request.capacityEnforcement());
            }
            if (request.maxSessionDurationMinutes() != null) {
                root.put("maxSessionDurationMinutes", request.maxSessionDurationMinutes());
            }
            if (request.scanCooldownSeconds() != null) {
                root.put("scanCooldownSeconds", request.scanCooldownSeconds());
            }
            if (request.faceModelVersion() != null) {
                root.put("faceModelVersion", request.faceModelVersion());
            }
            if (request.faceMaxCosineDistance() != null) {
                root.put("faceMaxCosineDistance", request.faceMaxCosineDistance());
            }
            if (request.faceMinDistanceGap() != null) {
                root.put("faceMinDistanceGap", request.faceMinDistanceGap());
            }
            if (request.livenessMinScore() != null) {
                root.put("livenessMinScore", request.livenessMinScore());
            }

            entity.setValue(objectMapper.writeValueAsString(root));
            entity.setVersion(entity.getVersion() + 1);
            entity.setUpdatedAt(OffsetDateTime.now());
            entity.setUpdatedBy(adminUserId);

            entity = repository.saveAndFlush(entity);

            SystemConfig updatedConfig = toDto(entity);

            // Publish WebSocket notification on /topic/occupancy if capacity changed
            if (request.maxCapacity() != null || request.nearCapacityRatio() != null) {
                publishConfigChangeEvent(updatedConfig);
            }

            return updatedConfig;
        } catch (Exception e) {
            if (e instanceof ApiException) throw (ApiException) e;
            throw new RuntimeException("Failed to update operational configuration", e);
        }
    }

    private void publishConfigChangeEvent(SystemConfig config) {
        try {
            LibraryState state = libraryStateRepository.findById((short) 1).orElse(null);
            long currentCount = checkinLogRepository.countByCheckOutTimeIsNull();
            long maxCapacity = config.maxCapacity();
            boolean near = currentCount >= (long) Math.floor(maxCapacity * config.nearCapacityRatio());
            long revision = state != null ? state.getOccupancyRevision() : 0L;

            ConfigChangedEvent event = new ConfigChangedEvent(
                    UUID.randomUUID(),
                    OffsetDateTime.now(),
                    revision,
                    currentCount,
                    maxCapacity,
                    near,
                    Map.of("action", "CONFIG_CHANGED")
            );

            messagingTemplate.convertAndSend("/topic/occupancy", event);
        } catch (Exception e) {
            org.slf4j.LoggerFactory.getLogger(SystemConfigService.class).warn("Failed to broadcast ConfigChangedEvent: {}", e.getMessage());
        }
    }

    public boolean isLibraryOpen(OffsetDateTime time, SystemConfig config) {
        if (config == null || config.openingHours() == null || config.openingHours().isEmpty()) {
            return true;
        }

        ZoneId zone = ZoneId.of(config.timezone() != null ? config.timezone() : "Asia/Ho_Chi_Minh");
        OffsetDateTime zonedTime = time.atZoneSameInstant(zone).toOffsetDateTime();
        int dayOfWeek = zonedTime.getDayOfWeek().getValue();
        LocalTime currentTime = zonedTime.toLocalTime();

        for (OpeningSlot slot : config.openingHours()) {
            if (slot.dayOfWeek() == dayOfWeek) {
                LocalTime opens = LocalTime.parse(slot.opensAt());
                LocalTime closes = LocalTime.parse(slot.closesAt());

                if (opens.equals(closes)) {
                    return true;
                }
                if (opens.isBefore(closes)) {
                    if (!currentTime.isBefore(opens) && currentTime.isBefore(closes)) {
                        return true;
                    }
                } else {
                    // overnight slot
                    if (!currentTime.isBefore(opens) || currentTime.isBefore(closes)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    private SystemConfig toDto(SystemConfigEntity entity) {
        try {
            JsonNode root = objectMapper.readTree(entity.getValue());
            List<OpeningSlot> slots = new ArrayList<>();
            if (root.has("openingHours") && root.get("openingHours").isArray()) {
                for (JsonNode slotNode : root.get("openingHours")) {
                    slots.add(new OpeningSlot(
                            slotNode.path("dayOfWeek").asInt(),
                            slotNode.path("opensAt").asText(),
                            slotNode.path("closesAt").asText()
                    ));
                }
            }

            Actor updatedByActor = null;
            if (entity.getUpdatedBy() != null) {
                User user = userRepository.findById(entity.getUpdatedBy()).orElse(null);
                if (user != null) {
                    updatedByActor = new Actor(user.getId(), user.getCode(), user.getFullName());
                }
            }

            return new SystemConfig(
                    root.path("timezone").asText("Asia/Ho_Chi_Minh"),
                    slots,
                    root.path("maxCapacity").asInt(250),
                    root.path("nearCapacityRatio").asDouble(0.9),
                    root.path("capacityEnforcement").asBoolean(false),
                    root.hasNonNull("maxSessionDurationMinutes") ? root.get("maxSessionDurationMinutes").asInt() : null,
                    root.path("scanCooldownSeconds").asInt(10),
                    root.hasNonNull("faceModelVersion") ? root.get("faceModelVersion").asText() : null,
                    root.hasNonNull("faceMaxCosineDistance") ? root.get("faceMaxCosineDistance").asDouble() : null,
                    root.hasNonNull("faceMinDistanceGap") ? root.get("faceMinDistanceGap").asDouble() : null,
                    root.hasNonNull("livenessMinScore") ? root.get("livenessMinScore").asDouble() : null,
                    entity.getVersion() != null ? entity.getVersion() : 0L,
                    entity.getUpdatedAt(),
                    updatedByActor
            );
        } catch (Exception e) {
            throw new RuntimeException("Failed to parse operational configuration JSON", e);
        }
    }
}
