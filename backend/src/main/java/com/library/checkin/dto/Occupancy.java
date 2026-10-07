package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record Occupancy(
        long count,
        long maxCapacity,
        boolean nearCapacity,
        boolean capacityEnforcement,
        long revision,
        OffsetDateTime asOf
) {}
