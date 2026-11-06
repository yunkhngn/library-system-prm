package com.library.checkin.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.UUID;

/** Identifies the kiosk by id or by its human-readable code (e.g. KIOSK-01). */
public record KioskLoginRequest(
        UUID kioskId,

        @Size(max = 64)
        String kioskCode,

        @NotBlank(message = "credential is required")
        @Size(min = 32, max = 256)
        String credential
) {
    @AssertTrue(message = "kioskId or kioskCode is required")
    boolean isIdentified() {
        return kioskId != null || (kioskCode != null && !kioskCode.isBlank());
    }
}
