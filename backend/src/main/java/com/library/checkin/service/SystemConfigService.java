package com.library.checkin.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.OpeningSlot;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.SystemConfigEntity;
import com.library.checkin.repository.SystemConfigRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SystemConfigService {

    private final SystemConfigRepository repository;
    private final ObjectMapper objectMapper;

    @Transactional(readOnly = true)
    public SystemConfig getOperational() {
        SystemConfigEntity entity = repository.findById("operational")
                .orElseThrow(() -> new IllegalStateException("Operational configuration missing in database"));

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
                    null
            );
        } catch (Exception e) {
            throw new RuntimeException("Failed to parse operational configuration JSON", e);
        }
    }

    public boolean isLibraryOpen(OffsetDateTime time, SystemConfig config) {
        if (config == null || config.openingHours() == null || config.openingHours().isEmpty()) {
            return true;
        }

        java.time.ZoneId zone = java.time.ZoneId.of(config.timezone() != null ? config.timezone() : "Asia/Ho_Chi_Minh");
        OffsetDateTime zonedTime = time.atZoneSameInstant(zone).toOffsetDateTime();
        int dayOfWeek = zonedTime.getDayOfWeek().getValue();
        java.time.LocalTime currentTime = zonedTime.toLocalTime();

        for (OpeningSlot slot : config.openingHours()) {
            if (slot.dayOfWeek() == dayOfWeek) {
                java.time.LocalTime opens = java.time.LocalTime.parse(slot.opensAt());
                java.time.LocalTime closes = java.time.LocalTime.parse(slot.closesAt());

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
}

