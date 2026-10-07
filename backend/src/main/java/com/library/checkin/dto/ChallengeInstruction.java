package com.library.checkin.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;

public record ChallengeInstruction(
        @NotNull String action,
        @Min(1) @Max(2) long order
) {}
