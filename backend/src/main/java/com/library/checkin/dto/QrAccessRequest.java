package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record QrAccessRequest(
        @NotBlank
        @Size(min = 20, max = 4096)
        String token
) {}
