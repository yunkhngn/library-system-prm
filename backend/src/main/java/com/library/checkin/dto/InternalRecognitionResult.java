package com.library.checkin.dto;

import java.util.UUID;

public record InternalRecognitionResult(
        boolean matched,
        UUID userId,
        Long biometricVersion,
        UUID consentId,
        Double cosineDistance,
        Double distanceGap,
        boolean livenessPassed,
        double livenessScore,
        String modelId,
        String modelVersion,
        String livenessModelVersion,
        boolean simulated,
        String outcome
) {}
