package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record KioskDto(
        UUID id,
        String code,
        String name,
        String mode,
        String status,
        boolean isOnline,
        OffsetDateTime lastSeenAt,
        long version,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}
