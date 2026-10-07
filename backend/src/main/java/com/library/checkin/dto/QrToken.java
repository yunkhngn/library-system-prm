package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record QrToken(
        String token,
        OffsetDateTime expiresAt,
        long refreshAfterSeconds
) {}
