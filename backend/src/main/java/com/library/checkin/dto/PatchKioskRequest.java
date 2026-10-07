package com.library.checkin.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PatchKioskRequest(
        @NotNull(message = "Version is required for optimistic locking")
        Long version,

        @Size(max = 100)
        String name,

        @Pattern(regexp = "^(ENTRY|EXIT|AUTO)$", message = "Mode must be ENTRY, EXIT, or AUTO")
        String mode,

        @Pattern(regexp = "^(ACTIVE|REVOKED)$", message = "Status must be ACTIVE or REVOKED")
        String status
) {}
