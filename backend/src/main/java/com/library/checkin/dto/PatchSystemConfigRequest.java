package com.library.checkin.dto;

import jakarta.validation.constraints.NotNull;
import java.util.List;

public record PatchSystemConfigRequest(
        @NotNull
        Long version,

        String timezone,
        List<OpeningSlot> openingHours,
        Integer maxCapacity,
        Double nearCapacityRatio,
        Boolean capacityEnforcement,
        Integer maxSessionDurationMinutes,
        Integer scanCooldownSeconds,
        String faceModelVersion,
        Double faceMaxCosineDistance,
        Double faceMinDistanceGap,
        Double livenessMinScore,
        Boolean resetFaceConfiguration
) {
    // Preserve the constructor used by existing integrations and tests.
    public PatchSystemConfigRequest(Long version, String timezone,
            List<OpeningSlot> openingHours, Integer maxCapacity,
            Double nearCapacityRatio, Boolean capacityEnforcement,
            Integer maxSessionDurationMinutes, Integer scanCooldownSeconds,
            String faceModelVersion, Double faceMaxCosineDistance,
            Double faceMinDistanceGap, Double livenessMinScore) {
        this(version, timezone, openingHours, maxCapacity, nearCapacityRatio,
                capacityEnforcement, maxSessionDurationMinutes, scanCooldownSeconds,
                faceModelVersion, faceMaxCosineDistance, faceMinDistanceGap,
                livenessMinScore, null);
    }
}
