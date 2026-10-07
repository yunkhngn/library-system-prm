package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.UUID;

public record KioskLoginRequest(
        @NotNull(message = "kioskId is required")
        UUID kioskId,

        @NotBlank(message = "credential is required")
        @Size(min = 32, max = 256)
        String credential
) {}
