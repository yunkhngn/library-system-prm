package com.library.checkin.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.OffsetDateTime;

public record PatchShiftRequest(
        @NotNull
        Long version,

        @Size(min = 1, max = 150)
        String name,

        OffsetDateTime startsAt,

        OffsetDateTime endsAt
) {}
