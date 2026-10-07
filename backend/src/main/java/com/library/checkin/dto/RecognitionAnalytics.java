package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record RecognitionAnalytics(
        OffsetDateTime from,
        OffsetDateTime to,
        long totalAttempts,
        long matched,
        long failed,
        Double failureRate,
        Double p50LatencyMs,
        Double p95LatencyMs,
        List<OutcomeCount> outcomes
) {}
