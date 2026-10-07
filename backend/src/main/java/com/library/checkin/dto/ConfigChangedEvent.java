package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.Map;
import java.util.UUID;

public record ConfigChangedEvent(
        UUID eventId,
        OffsetDateTime occurredAt,
        long revision,
        long count,
        long maxCapacity,
        boolean nearCapacity,
        Map<String, String> change
) {}
