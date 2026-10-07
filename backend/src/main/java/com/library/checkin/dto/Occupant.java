package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record Occupant(
        UUID sessionId,
        Subject subject,
        OffsetDateTime checkInTime,
        long durationSeconds,
        String checkInMethod
) {}
