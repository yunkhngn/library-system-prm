package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record KioskRuntimeConfig(
        UUID kioskId,
        String mode,
        String timezone,
        List<OpeningSlot> openingHours,
        long qrTtlSeconds,
        long scanCooldownSeconds,
        boolean faceEnabled,
        FaceCaptureRules faceCapture,
        OffsetDateTime serverTime,
        long configVersion
) {}
