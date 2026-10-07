package com.library.checkin.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.AccessResult;
import com.library.checkin.dto.Occupancy;
import com.library.checkin.dto.Subject;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.AccessRequest;
import com.library.checkin.entity.CheckinLog;
import com.library.checkin.entity.Kiosk;
import com.library.checkin.entity.LibraryState;
import com.library.checkin.entity.QrGrant;
import com.library.checkin.entity.User;
import com.library.checkin.event.OccupancyChangedEvent;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.*;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.security.PrincipalType;
import com.library.checkin.service.strategy.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccessService {

    private final KioskRepository kioskRepository;
    private final UserRepository userRepository;
    private final QrGrantRepository qrGrantRepository;
    private final CheckinLogRepository checkinLogRepository;
    private final LibraryStateRepository libraryStateRepository;
    private final AccessRequestRepository accessRequestRepository;
    private final SystemConfigService systemConfigService;
    private final ApplicationEventPublisher eventPublisher;
    private final ObjectMapper objectMapper;

    @Transactional
    public AccessResult record(AccessCommand command) {
        Kiosk kiosk = null;
        String kioskMode = "AUTO";

        if (command.principal().type() == PrincipalType.KIOSK) {
            kiosk = kioskRepository.findById(command.principal().id())
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Kiosk not found"));
            if (!"ACTIVE".equalsIgnoreCase(kiosk.getStatus())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "KIOSK_REVOKED", "Kiosk has been revoked");
            }
            kioskMode = kiosk.getMode();
        }

        // Lock library_state to serialize occupancy and sessions across kiosks
        LibraryState state = libraryStateRepository.findByIdForUpdate((short) 1)
                .orElseGet(() -> {
                    LibraryState initial = new LibraryState();
                    initial.setId((short) 1);
                    initial.setOccupancyRevision(0L);
                    return libraryStateRepository.save(initial);
                });

        SystemConfig config = systemConfigService.getOperational();
        ZoneId zone = ZoneId.of(config.timezone() != null ? config.timezone() : "Asia/Ho_Chi_Minh");
        OffsetDateTime now = OffsetDateTime.now(zone);

        // Validate proof
        User user = null;
        QrGrant qrGrant = null;

        if (command.proof() instanceof QrProof qrProof) {
            user = userRepository.findById(qrProof.userId())
                    .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "User not found"));

            if (!"ACTIVE".equalsIgnoreCase(user.getStatus())) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "User account is not ACTIVE");
            }
            if (!"STUDENT".equalsIgnoreCase(user.getRole())) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Only active students may use QR access");
            }

            qrGrant = qrGrantRepository.findByNonceHash(qrProof.nonceHash())
                    .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "QR grant not found"));

            if (qrGrant.getConsumedAt() != null) {
                throw new ApiException(HttpStatus.CONFLICT, "QR_ALREADY_USED", "QR token has already been used");
            }
            if (qrGrant.getExpiresAt().isBefore(now)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_EXPIRED", "QR token has expired");
            }

            // Cooldown check: different idempotency key within cooldown
            Optional<CheckinLog> latestLog = checkinLogRepository.findLatestByUserId(user.getId());
            if (latestLog.isPresent()) {
                OffsetDateTime lastTime = latestLog.get().getCheckOutTime() != null
                        ? latestLog.get().getCheckOutTime()
                        : latestLog.get().getCheckInTime();
                long elapsed = Duration.between(lastTime, now).abs().getSeconds();
                if (elapsed < config.scanCooldownSeconds()) {
                    throw new ApiException(HttpStatus.CONFLICT, "SCAN_TOO_SOON",
                            "Scan cooldown active. Please wait " + (config.scanCooldownSeconds() - elapsed) + " seconds");
                }
            }
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "Unsupported proof type");
        }

        // Determine action based on session and mode
        Optional<CheckinLog> openSession = checkinLogRepository.findOpenSessionByUserIdForUpdate(user.getId());
        AccessAction resolvedAction;

        if (command.action() == AccessAction.AUTO || (command.action() == null && "AUTO".equalsIgnoreCase(kioskMode))) {
            resolvedAction = openSession.isPresent() ? AccessAction.CHECK_OUT : AccessAction.CHECK_IN;
        } else if (command.action() == AccessAction.CHECK_IN || "ENTRY".equalsIgnoreCase(kioskMode)) {
            if (openSession.isPresent()) {
                throw new ApiException(HttpStatus.CONFLICT, "ALREADY_INSIDE", "User is already checked in");
            }
            resolvedAction = AccessAction.CHECK_IN;
        } else if (command.action() == AccessAction.CHECK_OUT || "EXIT".equalsIgnoreCase(kioskMode)) {
            if (openSession.isEmpty()) {
                throw new ApiException(HttpStatus.CONFLICT, "NOT_INSIDE", "User does not have an active session");
            }
            resolvedAction = AccessAction.CHECK_OUT;
        } else {
            resolvedAction = AccessAction.CHECK_IN;
        }

        // Action-specific validations
        if (resolvedAction == AccessAction.CHECK_IN) {
            if (!systemConfigService.isLibraryOpen(now, config)) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "LIBRARY_CLOSED", "Library is currently closed");
            }

            long currentCount = checkinLogRepository.countByCheckOutTimeIsNull();
            if (config.capacityEnforcement() && currentCount >= config.maxCapacity()) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CAPACITY_REACHED", "Library has reached maximum capacity");
            }
        }

        // Apply changes
        qrGrant.setConsumedAt(now);
        qrGrantRepository.save(qrGrant);

        UUID sessionId;
        long newCount;

        if (resolvedAction == AccessAction.CHECK_IN) {
            CheckinLog log = new CheckinLog();
            log.setUserId(user.getId());
            log.setMethod(command.proof().method().name());
            if (kiosk != null) log.setKioskId(kiosk.getId());
            log.setCheckInTime(now);
            log.setEntryConfigVersion(config.version());
            if (config.maxSessionDurationMinutes() != null) {
                log.setScheduledCheckoutAt(now.plusMinutes(config.maxSessionDurationMinutes()));
            }
            log = checkinLogRepository.save(log);
            sessionId = log.getId();
            newCount = checkinLogRepository.countByCheckOutTimeIsNull();
        } else {
            CheckinLog log = openSession.get();
            log.setCheckOutTime(now);
            log.setCheckOutMethod(command.proof().method().name());
            if (kiosk != null) log.setCheckOutKioskId(kiosk.getId());
            log.setCheckoutReason("USER_ACTION");
            log = checkinLogRepository.save(log);
            sessionId = log.getId();
            newCount = Math.max(0, checkinLogRepository.countByCheckOutTimeIsNull());
        }

        // Increment revision
        state.setOccupancyRevision(state.getOccupancyRevision() + 1);
        libraryStateRepository.save(state);

        Occupancy occupancy = new Occupancy(
                newCount,
                config.maxCapacity(),
                newCount >= (config.maxCapacity() * config.nearCapacityRatio()),
                config.capacityEnforcement(),
                state.getOccupancyRevision(),
                now
        );

        Subject subject = new Subject(user.getId(), "USER", user.getCode(), user.getFullName());

        AccessResult result = new AccessResult(
                command.requestId(),
                sessionId,
                resolvedAction.name(),
                subject,
                command.proof().method().name(),
                now,
                occupancy,
                false
        );

        // Finalize access request
        AccessRequest accessRequest = accessRequestRepository.findById(command.requestId()).orElseThrow();
        accessRequest.setStatus("COMPLETED");
        accessRequest.setResponseStatus(200);
        try {
            accessRequest.setResponseBody(objectMapper.writeValueAsString(result));
        } catch (Exception e) {
            throw new RuntimeException("Failed to serialize AccessResult", e);
        }
        accessRequestRepository.save(accessRequest);

        // Register after commit event
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    eventPublisher.publishEvent(new OccupancyChangedEvent(
                            occupancy,
                            sessionId,
                            resolvedAction.name(),
                            subject,
                            command.proof().method().name(),
                            now
                    ));
                }
            });
        }

        return result;
    }
}
