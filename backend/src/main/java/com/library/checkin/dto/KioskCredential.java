package com.library.checkin.dto;

public record KioskCredential(
        KioskDto kiosk,
        String credential
) {}
