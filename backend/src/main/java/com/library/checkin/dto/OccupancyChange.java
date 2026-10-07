package com.library.checkin.dto;

import java.util.UUID;

public record OccupancyChange(
        UUID sessionId,
        String action
) {}
