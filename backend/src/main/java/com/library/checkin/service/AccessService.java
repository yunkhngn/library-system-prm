package com.library.checkin.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
import com.library.checkin.entity.*;
import com.library.checkin.event.OccupancyChangedEvent;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.*;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.security.PrincipalType;
import com.library.checkin.service.strategy.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccessService {

    private final KioskRepository kioskRepository;
    private final UserRepository userRepository;
    private final VisitorRepository visitorRepository;
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
        } else if (command.proof() instanceof FaceProof faceProof) {
            user = userRepository.findById(faceProof.userId())
                    .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "NO_MATCH", "User not found"));

            if (!"ACTIVE".equalsIgnoreCase(user.getStatus())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "User account is not ACTIVE");
            }
            if (!"STUDENT".equalsIgnoreCase(user.getRole())) {
                throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Only students may use biometric access");
            }

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
        if (qrGrant != null) {
            qrGrant.setConsumedAt(now);
            qrGrantRepository.save(qrGrant);
        }

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

    @Transactional
    public AccessResult recordManualAccess(UUID staffId, UUID idempotencyKey, ManualAccessRequest request) {
        if ((request.userId() != null && request.visitorId() != null) ||
            (request.userId() == null && request.visitorId() == null)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Exactly one of userId or visitorId must be provided");
        }

        String actionStr = request.action() != null ? request.action().trim().toUpperCase() : "";
        if (!actionStr.equals("CHECK_IN") && !actionStr.equals("CHECK_OUT")) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "Action must be CHECK_IN or CHECK_OUT");
        }

        String reason = request.reason() != null ? request.reason().trim() : "";
        if (reason.isEmpty()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Reason is required");
        }

        User staffUser = userRepository.findById(staffId)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Staff user not found"));

        // Lock library_state
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

        Subject subject;
        UUID sessionId;
        long newCount;

        if (request.userId() != null) {
            User targetUser = userRepository.findById(request.userId())
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));

            subject = new Subject(targetUser.getId(), "USER", targetUser.getCode(), targetUser.getFullName());

            if ("CHECK_IN".equals(actionStr)) {
                if (!"STUDENT".equalsIgnoreCase(targetUser.getRole())) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SUBJECT_NOT_ELIGIBLE", "Only students can check in");
                }
                if ("LOCKED".equalsIgnoreCase(targetUser.getStatus())) {
                    throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "User account is locked");
                }
                if (!"ACTIVE".equalsIgnoreCase(targetUser.getStatus())) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "SUBJECT_NOT_ELIGIBLE", "User account is not active");
                }

                if (!systemConfigService.isLibraryOpen(now, config)) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "LIBRARY_CLOSED", "Library is currently closed");
                }

                Optional<CheckinLog> openSession = checkinLogRepository.findOpenSessionByUserIdForUpdate(targetUser.getId());
                if (openSession.isPresent()) {
                    throw new ApiException(HttpStatus.CONFLICT, "ALREADY_INSIDE", "User already has an open session");
                }

                long currentCount = checkinLogRepository.countByCheckOutTimeIsNull();
                if (config.capacityEnforcement() && currentCount >= config.maxCapacity()) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CAPACITY_REACHED", "Library has reached maximum capacity");
                }

                CheckinLog log = new CheckinLog();
                log.setUserId(targetUser.getId());
                log.setMethod("MANUAL");
                log.setPerformedBy(staffId);
                log.setManualReason(reason);
                log.setCheckInTime(now);
                log.setEntryConfigVersion(config.version());
                if (config.maxSessionDurationMinutes() != null) {
                    log.setScheduledCheckoutAt(now.plusMinutes(config.maxSessionDurationMinutes()));
                }
                log = checkinLogRepository.save(log);
                sessionId = log.getId();
                newCount = checkinLogRepository.countByCheckOutTimeIsNull();
            } else { // CHECK_OUT
                // Manual checkout for LOCKED users is explicitly allowed
                Optional<CheckinLog> openSession = checkinLogRepository.findOpenSessionByUserIdForUpdate(targetUser.getId());
                if (openSession.isEmpty()) {
                    throw new ApiException(HttpStatus.CONFLICT, "NOT_INSIDE", "User does not have an active session");
                }

                CheckinLog log = openSession.get();
                log.setCheckOutTime(now);
                log.setCheckOutMethod("MANUAL");
                log.setCheckedOutBy(staffId);
                log.setCheckoutReason("MANUAL");
                log.setCheckoutManualReason(reason);
                log = checkinLogRepository.save(log);
                sessionId = log.getId();
                newCount = Math.max(0, checkinLogRepository.countByCheckOutTimeIsNull());
            }
        } else { // visitorId != null
            Visitor visitor = visitorRepository.findById(request.visitorId())
                    .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Visitor not found"));

            subject = new Subject(visitor.getId(), "VISITOR", visitor.getReferenceCode(), visitor.getFullName());

            if ("CHECK_IN".equals(actionStr)) {
                if (!systemConfigService.isLibraryOpen(now, config)) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "LIBRARY_CLOSED", "Library is currently closed");
                }

                Optional<CheckinLog> openSession = checkinLogRepository.findOpenSessionByVisitorIdForUpdate(visitor.getId());
                if (openSession.isPresent()) {
                    throw new ApiException(HttpStatus.CONFLICT, "ALREADY_INSIDE", "Visitor already has an open session");
                }

                long currentCount = checkinLogRepository.countByCheckOutTimeIsNull();
                if (config.capacityEnforcement() && currentCount >= config.maxCapacity()) {
                    throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CAPACITY_REACHED", "Library has reached maximum capacity");
                }

                CheckinLog log = new CheckinLog();
                log.setVisitorId(visitor.getId());
                log.setMethod("MANUAL");
                log.setPerformedBy(staffId);
                log.setManualReason(reason);
                log.setCheckInTime(now);
                log.setEntryConfigVersion(config.version());
                if (config.maxSessionDurationMinutes() != null) {
                    log.setScheduledCheckoutAt(now.plusMinutes(config.maxSessionDurationMinutes()));
                }
                log = checkinLogRepository.save(log);
                sessionId = log.getId();
                newCount = checkinLogRepository.countByCheckOutTimeIsNull();
            } else { // CHECK_OUT
                Optional<CheckinLog> openSession = checkinLogRepository.findOpenSessionByVisitorIdForUpdate(visitor.getId());
                if (openSession.isEmpty()) {
                    throw new ApiException(HttpStatus.CONFLICT, "NOT_INSIDE", "Visitor does not have an active session");
                }

                CheckinLog log = openSession.get();
                log.setCheckOutTime(now);
                log.setCheckOutMethod("MANUAL");
                log.setCheckedOutBy(staffId);
                log.setCheckoutReason("MANUAL");
                log.setCheckoutManualReason(reason);
                log = checkinLogRepository.save(log);
                sessionId = log.getId();
                newCount = Math.max(0, checkinLogRepository.countByCheckOutTimeIsNull());
            }
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

        AccessResult result = new AccessResult(
                idempotencyKey,
                sessionId,
                actionStr,
                subject,
                "MANUAL",
                now,
                occupancy,
                false
        );

        // Finalize access request
        AccessRequest accessRequest = accessRequestRepository.findById(idempotencyKey).orElseThrow();
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
                            actionStr,
                            subject,
                            "MANUAL",
                            now
                    ));
                }
            });
        }

        return result;
    }

    @Transactional(readOnly = true)
    public StudentLookup lookupStudent(String code) {
        String normalized = code != null ? code.trim().toUpperCase() : "";
        if (normalized.isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "code must not be blank");
        }

        // Staff accounts are reported as not found so the endpoint cannot enumerate them.
        User student = userRepository.findByCode(normalized)
                .filter(u -> "STUDENT".equalsIgnoreCase(u.getRole()))
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Student not found"));

        Optional<CheckinLog> openSession = checkinLogRepository.findByUserIdAndCheckOutTimeIsNull(student.getId());
        return new StudentLookup(
                student.getId(),
                student.getCode(),
                student.getFullName(),
                student.getStatus(),
                openSession.isPresent(),
                openSession.map(CheckinLog::getId).orElse(null),
                openSession.map(CheckinLog::getCheckInTime).orElse(null)
        );
    }

    @Transactional(readOnly = true)
    public AccessStatus getMyAccessStatus(UUID studentId) {
        OffsetDateTime now = OffsetDateTime.now();
        Optional<CheckinLog> openSession = checkinLogRepository.findByUserIdAndCheckOutTimeIsNull(studentId);
        if (openSession.isPresent()) {
            AccessSession session = toAccessSession(openSession.get(), now);
            return new AccessStatus(true, session, now);
        } else {
            return new AccessStatus(false, null, now);
        }
    }

    @Transactional(readOnly = true)
    public AccessSession getMyAccessSession(UUID studentId, UUID sessionId) {
        CheckinLog log = checkinLogRepository.findById(sessionId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Session not found"));
        if (log.getUserId() == null || !log.getUserId().equals(studentId)) {
            throw new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Session not found");
        }
        return toAccessSession(log, OffsetDateTime.now());
    }

    @Transactional(readOnly = true)
    public AccessSessionPage listMyAccessHistory(UUID studentId, OffsetDateTime from, OffsetDateTime to, int page, int size, String sort) {
        OffsetDateTime now = OffsetDateTime.now();
        if (from == null && to == null) {
            to = now;
            from = now.minusDays(30);
        } else if (from == null) {
            from = to.minusDays(30);
        } else if (to == null) {
            to = from.plusDays(30);
        }

        if (!to.isAfter(from)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "to must be greater than from");
        }
        if (Duration.between(from, to).toDays() > 366) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "Time range must not exceed 366 days");
        }

        Sort sortObj;
        if (sort == null || sort.isBlank() || "checkInTime,desc".equals(sort)) {
            sortObj = Sort.by(Sort.Direction.DESC, "checkInTime");
        } else if ("checkInTime,asc".equals(sort)) {
            sortObj = Sort.by(Sort.Direction.ASC, "checkInTime");
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid sort option: " + sort);
        }

        if (size < 1) size = 20;
        if (size > 100) size = 100;
        if (page < 0) page = 0;

        Page<CheckinLog> resultPage = checkinLogRepository.findMyHistory(studentId, from, to, PageRequest.of(page, size, sortObj));
        List<AccessSession> items = resultPage.getContent().stream()
                .map(l -> toAccessSession(l, now))
                .toList();

        return new AccessSessionPage(items, resultPage.getNumber(), resultPage.getSize(), resultPage.getTotalElements(), resultPage.getTotalPages());
    }

    @Transactional(readOnly = true)
    public AccessSessionPage listAccessHistory(OffsetDateTime from, OffsetDateTime to, String q, UUID userId, UUID visitorId, Boolean isOpen, String method, int page, int size, String sort) {
        if (userId != null && visitorId != null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "userId and visitorId are mutually exclusive");
        }

        OffsetDateTime now = OffsetDateTime.now();
        if (from == null && to == null) {
            to = now;
            from = now.minusDays(30);
        } else if (from == null) {
            from = to.minusDays(30);
        } else if (to == null) {
            to = from.plusDays(30);
        }

        if (!to.isAfter(from)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "to must be greater than from");
        }
        if (Duration.between(from, to).toDays() > 366) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "Time range must not exceed 366 days");
        }

        Sort sortObj;
        if (sort == null || sort.isBlank() || "checkInTime,desc".equals(sort)) {
            sortObj = Sort.by(Sort.Direction.DESC, "check_in_time");
        } else if ("checkInTime,asc".equals(sort)) {
            sortObj = Sort.by(Sort.Direction.ASC, "check_in_time");
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid sort option: " + sort);
        }

        String methodTrimmed = null;
        if (method != null && !method.isBlank()) {
            methodTrimmed = method.trim().toUpperCase();
            if (!methodTrimmed.equals("FACE") && !methodTrimmed.equals("QR") && !methodTrimmed.equals("MANUAL")) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid method: " + method);
            }
        }

        String qTrimmed = (q != null && !q.trim().isEmpty()) ? q.trim() : null;

        if (size < 1) size = 20;
        if (size > 100) size = 100;
        if (page < 0) page = 0;

        Page<CheckinLog> resultPage = checkinLogRepository.searchAccessHistory(
                from, to, userId, visitorId, isOpen, methodTrimmed, qTrimmed,
                PageRequest.of(page, size, sortObj)
        );

        List<AccessSession> items = resultPage.getContent().stream()
                .map(l -> toAccessSession(l, now))
                .toList();

        return new AccessSessionPage(items, resultPage.getNumber(), resultPage.getSize(), resultPage.getTotalElements(), resultPage.getTotalPages());
    }

    @Transactional(readOnly = true)
    public AccessSession getAccessSession(UUID sessionId) {
        CheckinLog log = checkinLogRepository.findById(sessionId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Session not found"));
        return toAccessSession(log, OffsetDateTime.now());
    }

    public AccessSession toAccessSession(CheckinLog log, OffsetDateTime asOf) {
        Subject subject;
        if (log.getUserId() != null) {
            User u = userRepository.findById(log.getUserId()).orElse(null);
            subject = u != null
                    ? new Subject(u.getId(), "USER", u.getCode(), u.getFullName())
                    : new Subject(log.getUserId(), "USER", "UNKNOWN", "Unknown");
        } else {
            Visitor v = visitorRepository.findById(log.getVisitorId()).orElse(null);
            subject = v != null
                    ? new Subject(v.getId(), "VISITOR", v.getReferenceCode(), v.getFullName())
                    : new Subject(log.getVisitorId(), "VISITOR", "UNKNOWN", "Unknown");
        }

        KioskSummary inKiosk = null;
        if (log.getKioskId() != null) {
            Kiosk k = kioskRepository.findById(log.getKioskId()).orElse(null);
            if (k != null) inKiosk = new KioskSummary(k.getId(), k.getCode(), k.getName());
        }

        KioskSummary outKiosk = null;
        if (log.getCheckOutKioskId() != null) {
            Kiosk k = kioskRepository.findById(log.getCheckOutKioskId()).orElse(null);
            if (k != null) outKiosk = new KioskSummary(k.getId(), k.getCode(), k.getName());
        }

        Actor inActor = null;
        if (log.getPerformedBy() != null) {
            User u = userRepository.findById(log.getPerformedBy()).orElse(null);
            if (u != null) inActor = new Actor(u.getId(), u.getCode(), u.getFullName());
        }

        Actor outActor = null;
        if (log.getCheckedOutBy() != null) {
            User u = userRepository.findById(log.getCheckedOutBy()).orElse(null);
            if (u != null) outActor = new Actor(u.getId(), u.getCode(), u.getFullName());
        }

        OffsetDateTime endTime = log.getCheckOutTime() != null ? log.getCheckOutTime() : asOf;
        long duration = Math.max(0, Duration.between(log.getCheckInTime(), endTime).toSeconds());

        return new AccessSession(
                log.getId(),
                subject,
                log.getCheckInTime(),
                log.getCheckOutTime(),
                log.getMethod(),
                log.getCheckOutMethod(),
                inKiosk,
                outKiosk,
                inActor,
                outActor,
                log.getCheckoutReason(),
                log.getManualReason(),
                log.getCheckoutManualReason(),
                duration
        );
    }
}
