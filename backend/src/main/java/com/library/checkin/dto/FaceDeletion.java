package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record FaceDeletion(
        boolean isEnrolled,
        long version,
        OffsetDateTime deletedAt
) {}
