package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

public record CreateShiftRequest(
        @NotBlank
        @Size(min = 1, max = 150)
        String name,

        @NotNull
        OffsetDateTime startsAt,

        @NotNull
        OffsetDateTime endsAt
) {}
