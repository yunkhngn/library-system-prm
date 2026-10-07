package com.library.checkin.dto;

import com.library.checkin.exception.ApiError;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AccessRequestStatus(
        UUID requestId,
        UUID idempotencyKey,
        String status, // IN_PROGRESS, COMPLETED
        Integer httpStatus,
        AccessResult result,
        ApiError error,
        OffsetDateTime processingDeadline,
        OffsetDateTime expiresAt
) {}
