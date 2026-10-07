package com.library.checkin.dto;

public record KioskToken(
        String accessToken,
        String tokenType,
        long expiresIn,
        KioskDto kiosk
) {}
