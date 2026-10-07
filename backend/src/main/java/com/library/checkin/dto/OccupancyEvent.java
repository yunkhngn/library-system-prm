package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record OccupancyEvent(
        UUID eventId,
        OffsetDateTime occurredAt,
        long revision,
        long count,
        long maxCapacity,
        boolean nearCapacity,
        OccupancyChange change
) {}
