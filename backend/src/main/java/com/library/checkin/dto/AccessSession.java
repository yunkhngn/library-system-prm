package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record AccessSession(
        UUID id,
        Subject subject,
        OffsetDateTime checkInTime,
        OffsetDateTime checkOutTime,
        String checkInMethod,
        String checkOutMethod,
        KioskSummary checkInKiosk,
        KioskSummary checkOutKiosk,
        Actor checkInBy,
        Actor checkOutBy,
        String checkoutReason,
        String manualReason,
        String checkOutManualReason,
        long durationSeconds
) {}
