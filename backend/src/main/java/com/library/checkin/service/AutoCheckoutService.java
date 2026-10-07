package com.library.checkin.service;

import com.library.checkin.dto.Occupancy;
import com.library.checkin.dto.Subject;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.CheckinLog;
import com.library.checkin.entity.LibraryState;
import com.library.checkin.event.OccupancyChangedEvent;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.LibraryStateRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

@Slf4j
@Service
public class AutoCheckoutService {

    private final SystemConfigService systemConfigService;
    private final CheckinLogRepository checkinLogRepository;
    private final LibraryStateRepository libraryStateRepository;
    private final ApplicationEventPublisher eventPublisher;

    public AutoCheckoutService(SystemConfigService systemConfigService,
                               CheckinLogRepository checkinLogRepository,
                               LibraryStateRepository libraryStateRepository,
                               ApplicationEventPublisher eventPublisher) {
        this.systemConfigService = systemConfigService;
        this.checkinLogRepository = checkinLogRepository;
        this.libraryStateRepository = libraryStateRepository;
        this.eventPublisher = eventPublisher;
    }

    @Scheduled(fixedDelay = 60000)
    public void scheduledAutoCheckout() {
        try {
            processAutoCheckouts();
        } catch (Exception e) {
            log.error("Error during scheduled auto-checkout: {}", e.getMessage(), e);
        }
    }

    @Transactional
    public int processAutoCheckouts() {
        SystemConfig config = systemConfigService.getOperational();
        OffsetDateTime now = OffsetDateTime.now();
        boolean isOpen = systemConfigService.isLibraryOpen(now, config);

        List<CheckinLog> openSessions = checkinLogRepository.findAllOpenSessionsForUpdate();
        List<CheckinLog> checkedOut = new ArrayList<>();

        for (CheckinLog session : openSessions) {
            String exitReason = null;
            if (!isOpen) {
                exitReason = "CLOSING_TIME";
            } else if (config.maxSessionDurationMinutes() != null) {
                long durationMinutes = Duration.between(session.getCheckInTime(), now).toMinutes();
                if (durationMinutes >= config.maxSessionDurationMinutes()) {
                    exitReason = "MAX_DURATION";
                }
            }

            if (exitReason != null) {
                session.setCheckOutTime(now);
                session.setCheckoutReason(exitReason);
                checkedOut.add(session);
            }
        }

        if (checkedOut.isEmpty()) {
            return 0;
        }

        checkinLogRepository.saveAllAndFlush(checkedOut);

        LibraryState state = libraryStateRepository.findById((short) 1).orElseGet(() -> {
            LibraryState s = new LibraryState();
            s.setId((short) 1);
            s.setOccupancyRevision(0L);
            return s;
        });

        long newRevision = state.getOccupancyRevision() + 1;
        state.setOccupancyRevision(newRevision);
        libraryStateRepository.saveAndFlush(state);

        long newCount = checkinLogRepository.countByCheckOutTimeIsNull();
        long maxCapacity = config.maxCapacity();
        boolean near = newCount >= (long) Math.floor(maxCapacity * config.nearCapacityRatio());
        Occupancy occupancy = new Occupancy(newCount, maxCapacity, near, config.capacityEnforcement(), newRevision, now);

        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override
                public void afterCommit() {
                    for (CheckinLog session : checkedOut) {
                        Subject subject = session.getUserId() != null
                                ? new Subject(session.getUserId(), "USER", null, null)
                                : new Subject(session.getVisitorId(), "VISITOR", null, null);

                        eventPublisher.publishEvent(new OccupancyChangedEvent(
                                occupancy,
                                session.getId(),
                                "CHECK_OUT",
                                subject,
                                "AUTO",
                                now
                        ));
                    }
                }
            });
        }

        log.info("Auto-checked out {} sessions at {}", checkedOut.size(), now);
        return checkedOut.size();
    }
}
