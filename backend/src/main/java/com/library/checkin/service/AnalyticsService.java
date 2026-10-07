package com.library.checkin.service;

import com.library.checkin.dto.*;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.RecognitionAttemptRepository;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.*;
import java.util.*;

@Service
public class AnalyticsService {

    private final CheckinLogRepository checkinLogRepository;
    private final RecognitionAttemptRepository recognitionAttemptRepository;
    private final ZoneId vnZone = ZoneId.of("Asia/Ho_Chi_Minh");

    public AnalyticsService(CheckinLogRepository checkinLogRepository,
                            RecognitionAttemptRepository recognitionAttemptRepository) {
        this.checkinLogRepository = checkinLogRepository;
        this.recognitionAttemptRepository = recognitionAttemptRepository;
    }

    @Transactional(readOnly = true)
    public AccessAnalytics getAccessAnalytics(OffsetDateTime from, OffsetDateTime to, String bucketStr) {
        if (from == null || to == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "from and to parameters are required");
        }
        if (!to.isAfter(from)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "to boundary must be strictly after from boundary");
        }

        String bucket = (bucketStr != null && !bucketStr.isBlank()) ? bucketStr.toUpperCase() : "DAY";
        if (!"DAY".equals(bucket) && !"HOUR".equals(bucket)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "bucket must be DAY or HOUR");
        }

        long diffDays = Duration.between(from, to).toDays();
        if ("DAY".equals(bucket) && diffDays > 366) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "DAY bucket range cannot exceed 366 days");
        }
        if ("HOUR".equals(bucket) && diffDays > 31) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "HOUR bucket range cannot exceed 31 days");
        }

        long totalCheckIns = checkinLogRepository.countTotalCheckIns(from, to);
        long totalCheckOuts = checkinLogRepository.countTotalCheckOuts(from, to);
        Double averageStaySeconds = checkinLogRepository.getAverageStaySeconds(from, to);

        // Fetch bucketed data from DB
        List<Object[]> inData = "DAY".equals(bucket)
                ? checkinLogRepository.aggregateCheckInsByDay(from, to, "Asia/Ho_Chi_Minh")
                : checkinLogRepository.aggregateCheckInsByHour(from, to, "Asia/Ho_Chi_Minh");
        List<Object[]> outData = "DAY".equals(bucket)
                ? checkinLogRepository.aggregateCheckOutsByDay(from, to, "Asia/Ho_Chi_Minh")
                : checkinLogRepository.aggregateCheckOutsByHour(from, to, "Asia/Ho_Chi_Minh");

        Map<LocalDateTime, long[]> inMap = new HashMap<>();
        for (Object[] row : inData) {
            LocalDateTime dt = toLocalDateTime(row[0]);
            long totalIn = ((Number) row[1]).longValue();
            long faceIn = ((Number) row[2]).longValue();
            long qrIn = ((Number) row[3]).longValue();
            long manualIn = ((Number) row[4]).longValue();
            inMap.put(dt, new long[]{totalIn, faceIn, qrIn, manualIn});
        }

        Map<LocalDateTime, Long> outMap = new HashMap<>();
        for (Object[] row : outData) {
            LocalDateTime dt = toLocalDateTime(row[0]);
            long totalOut = ((Number) row[1]).longValue();
            outMap.put(dt, totalOut);
        }

        // Generate contiguous zero-filled buckets
        List<AccessBucket> buckets = new ArrayList<>();
        ZonedDateTime current = from.atZoneSameInstant(vnZone);
        ZonedDateTime end = to.atZoneSameInstant(vnZone);

        if ("DAY".equals(bucket)) {
            LocalDate startDate = current.toLocalDate();
            LocalDate endDate = end.toLocalDate();
            // If 'end' is exactly at midnight, the last day is not included
            if (end.toLocalTime().equals(LocalTime.MIDNIGHT) && endDate.isAfter(startDate)) {
                endDate = endDate.minusDays(1);
            }

            LocalDate d = startDate;
            while (!d.isAfter(endDate)) {
                ZonedDateTime bStart = d.atStartOfDay(vnZone);
                ZonedDateTime bEnd = d.plusDays(1).atStartOfDay(vnZone);
                LocalDateTime key = bStart.toLocalDateTime();

                long[] inCounts = inMap.getOrDefault(key, new long[]{0, 0, 0, 0});
                long outCount = outMap.getOrDefault(key, 0L);

                buckets.add(new AccessBucket(
                        bStart.toOffsetDateTime(),
                        bEnd.toOffsetDateTime(),
                        inCounts[0],
                        outCount,
                        inCounts[1],
                        inCounts[2],
                        inCounts[3]
                ));
                d = d.plusDays(1);
            }
        } else {
            // HOUR bucket
            ZonedDateTime hStart = current.truncatedTo(java.time.temporal.ChronoUnit.HOURS);
            while (hStart.isBefore(end)) {
                ZonedDateTime hEnd = hStart.plusHours(1);
                LocalDateTime key = hStart.toLocalDateTime();

                long[] inCounts = inMap.getOrDefault(key, new long[]{0, 0, 0, 0});
                long outCount = outMap.getOrDefault(key, 0L);

                buckets.add(new AccessBucket(
                        hStart.toOffsetDateTime(),
                        hEnd.toOffsetDateTime(),
                        inCounts[0],
                        outCount,
                        inCounts[1],
                        inCounts[2],
                        inCounts[3]
                ));
                hStart = hEnd;
            }
        }

        return new AccessAnalytics(
                from,
                to,
                "Asia/Ho_Chi_Minh",
                bucket,
                totalCheckIns,
                totalCheckOuts,
                averageStaySeconds,
                buckets
        );
    }

    @Transactional(readOnly = true)
    public RecognitionAnalytics getRecognitionAnalytics(OffsetDateTime from, OffsetDateTime to, UUID kioskId) {
        if (from == null || to == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "from and to parameters are required");
        }
        if (!to.isAfter(from)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "to boundary must be strictly after from boundary");
        }
        if (Duration.between(from, to).toDays() > 366) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "Date range cannot exceed 366 days");
        }

        List<Object[]> aggregated = recognitionAttemptRepository.getAggregatedMetrics(from, to, kioskId);
        long total = 0L;
        long matched = 0L;
        Double p50 = null;
        Double p95 = null;

        if (aggregated != null && !aggregated.isEmpty()) {
            Object[] row = aggregated.get(0);
            total = row[0] != null ? ((Number) row[0]).longValue() : 0L;
            matched = row[1] != null ? ((Number) row[1]).longValue() : 0L;
            p50 = row[2] != null ? ((Number) row[2]).doubleValue() : null;
            p95 = row[3] != null ? ((Number) row[3]).doubleValue() : null;
        }

        long failed = total - matched;
        Double failureRate = total > 0 ? (double) failed / total : null;

        List<Object[]> outcomeData = recognitionAttemptRepository.countOutcomes(from, to, kioskId);
        List<OutcomeCount> outcomes = new ArrayList<>();
        if (outcomeData != null) {
            for (Object[] r : outcomeData) {
                outcomes.add(new OutcomeCount(
                        (String) r[0],
                        ((Number) r[1]).longValue()
                ));
            }
        }

        return new RecognitionAnalytics(
                from,
                to,
                total,
                matched,
                failed,
                failureRate,
                p50,
                p95,
                outcomes
        );
    }

    private LocalDateTime toLocalDateTime(Object obj) {
        if (obj instanceof java.sql.Timestamp ts) {
            return ts.toLocalDateTime();
        } else if (obj instanceof LocalDateTime ldt) {
            return ldt;
        } else if (obj instanceof OffsetDateTime odt) {
            return odt.toLocalDateTime();
        }
        return LocalDateTime.parse(obj.toString().replace(" ", "T"));
    }
}
