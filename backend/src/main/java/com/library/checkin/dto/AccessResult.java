package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AccessResult(
        UUID requestId,
        UUID sessionId,
        String action, // CHECK_IN, CHECK_OUT
        Subject subject,
        String method, // FACE, QR, MANUAL
        OffsetDateTime occurredAt,
        Occupancy occupancy,
        boolean simulated
) {}
