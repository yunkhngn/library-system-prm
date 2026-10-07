package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record ShiftDto(
        UUID id,
        String name,
        OffsetDateTime startsAt,
        OffsetDateTime endsAt,
        String status,
        Long version,
        Long assignmentCount,
        Actor createdBy,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt,
        String cancellationReason
) {}
