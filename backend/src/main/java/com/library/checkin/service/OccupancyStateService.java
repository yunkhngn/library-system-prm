package com.library.checkin.service;

import com.library.checkin.dto.Occupancy;
import com.library.checkin.dto.Occupant;
import com.library.checkin.dto.OccupantPage;
import com.library.checkin.dto.Subject;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.LibraryState;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.LibraryStateRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;

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

    @Transactional(readOnly = true)
    public OccupantPage listOccupants(int page, int size, String q, String kind) {
        if (size < 1) size = 20;
        if (size > 100) size = 100;
        if (page < 0) page = 0;

        String queryTrimmed = (q != null && !q.trim().isEmpty()) ? q.trim() : null;
        String kindTrimmed = (kind != null && !kind.trim().isEmpty()) ? kind.trim().toUpperCase() : null;

        PageRequest pageRequest = PageRequest.of(page, size);
        Page<Object[]> resultPage = checkinLogRepository.findOpenOccupants(kindTrimmed, queryTrimmed, pageRequest);

        OffsetDateTime now = OffsetDateTime.now();

        List<Occupant> occupants = resultPage.getContent().stream()
                .map(row -> {
                    UUID sessionId = (UUID) row[0];
                    OffsetDateTime checkInTime;
                    if (row[1] instanceof OffsetDateTime odt) {
                        checkInTime = odt;
                    } else if (row[1] instanceof java.sql.Timestamp ts) {
                        checkInTime = ts.toInstant().atOffset(ZoneOffset.UTC);
                    } else {
                        checkInTime = OffsetDateTime.parse(row[1].toString());
                    }
                    String method = (String) row[2];

                    UUID userId = (UUID) row[3];
                    String userCode = (String) row[4];
                    String userName = (String) row[5];

                    UUID visitorId = (UUID) row[6];
                    String visitorRef = (String) row[7];
                    String visitorName = (String) row[8];

                    Subject subject;
                    if (userId != null) {
                        subject = new Subject(userId, "USER", userCode, userName);
                    } else {
                        subject = new Subject(visitorId, "VISITOR", visitorRef, visitorName);
                    }

                    long duration = Math.max(0, Duration.between(checkInTime, now).toSeconds());
                    return new Occupant(sessionId, subject, checkInTime, duration, method);
                })
                .toList();

        return new OccupantPage(
                occupants,
                resultPage.getNumber(),
                resultPage.getSize(),
                resultPage.getTotalElements(),
                resultPage.getTotalPages()
        );
    }
}
