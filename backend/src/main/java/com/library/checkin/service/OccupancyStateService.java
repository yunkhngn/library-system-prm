package com.library.checkin.service;

import com.library.checkin.dto.Occupancy;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.LibraryState;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.LibraryStateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.ZoneId;

@Service
@RequiredArgsConstructor
public class OccupancyStateService {

    private final CheckinLogRepository checkinLogRepository;
    private final LibraryStateRepository libraryStateRepository;
    private final SystemConfigService systemConfigService;

    @Transactional(readOnly = true)
    public Occupancy snapshot() {
        SystemConfig config = systemConfigService.getOperational();
        long count = checkinLogRepository.countByCheckOutTimeIsNull();
        LibraryState state = libraryStateRepository.findById((short) 1)
                .orElseGet(() -> {
                    LibraryState initial = new LibraryState();
                    initial.setId((short) 1);
                    initial.setOccupancyRevision(0L);
                    return initial;
                });

        ZoneId zone = ZoneId.of(config.timezone() != null ? config.timezone() : "Asia/Ho_Chi_Minh");
        OffsetDateTime now = OffsetDateTime.now(zone);

        return new Occupancy(
                count,
                config.maxCapacity(),
                count >= (config.maxCapacity() * config.nearCapacityRatio()),
                config.capacityEnforcement(),
                state.getOccupancyRevision(),
                now
        );
    }
}
