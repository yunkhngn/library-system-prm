package com.library.checkin.event;

import com.library.checkin.dto.Occupancy;
import com.library.checkin.dto.Subject;

import java.time.OffsetDateTime;
import java.util.UUID;

public record OccupancyChangedEvent(
        Occupancy occupancy,
        UUID sessionId,
        String action, // CHECK_IN, CHECK_OUT
        Subject subject,
        String method, // FACE, QR, MANUAL
        OffsetDateTime occurredAt
) {}
