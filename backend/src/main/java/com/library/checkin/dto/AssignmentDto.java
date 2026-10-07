package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AssignmentDto(
        UUID id,
        UUID shiftId,
        Actor staff,
        OffsetDateTime startsAt,
        OffsetDateTime endsAt,
        String status,
        Long version,
        Actor assignedBy,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}
