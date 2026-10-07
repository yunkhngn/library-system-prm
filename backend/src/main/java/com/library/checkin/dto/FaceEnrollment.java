package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record FaceEnrollment(
        boolean isEnrolled,
        FaceConsent consent,
        long imageCount,
        String modelId,
        String modelVersion,
        OffsetDateTime enrolledAt,
        long version
) {}
