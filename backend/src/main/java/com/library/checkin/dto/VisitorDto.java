package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record VisitorDto(
        UUID id,
        String referenceCode,
        String fullName,
        Actor createdBy,
        OffsetDateTime createdAt
) {}
