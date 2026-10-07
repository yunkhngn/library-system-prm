package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record HeartbeatResult(
        OffsetDateTime serverTime,
        long heartbeatIntervalSeconds,
        KioskDto kiosk
) {}
