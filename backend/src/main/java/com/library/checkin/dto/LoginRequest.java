package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record LoginRequest(
        @NotBlank(message = "Identifier is required")
        @Size(max = 254)
        String identifier,

        @NotBlank(message = "Password is required")
        @Size(max = 64)
        String password
) {}
