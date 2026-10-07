package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CancelShiftRequest(
        @NotNull
        Long version,

        @NotBlank
        @Size(min = 1, max = 1000)
        String reason
) {}
