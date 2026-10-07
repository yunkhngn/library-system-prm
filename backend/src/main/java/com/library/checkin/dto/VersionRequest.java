package com.library.checkin.dto;

import jakarta.validation.constraints.NotNull;

public record VersionRequest(
        @NotNull(message = "Version is required for optimistic locking")
        Long version
) {}
