package com.library.checkin.dto;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record PatchAssignmentRequest(
        @NotNull
        Long version,

        @NotNull
        UUID staffId
) {}
