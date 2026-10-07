package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record SystemConfig(
        String timezone,
        List<OpeningSlot> openingHours,
        int maxCapacity,
        double nearCapacityRatio,
        boolean capacityEnforcement,
        Integer maxSessionDurationMinutes,
        int scanCooldownSeconds,
        String faceModelVersion,
        Double faceMaxCosineDistance,
        Double faceMinDistanceGap,
        Double livenessMinScore,
        long version,
        OffsetDateTime updatedAt,
        Actor updatedBy
) {}
