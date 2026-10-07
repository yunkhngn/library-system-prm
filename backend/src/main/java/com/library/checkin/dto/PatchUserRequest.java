package com.library.checkin.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record PatchUserRequest(
        @NotNull(message = "Version is required for optimistic locking")
        Long version,

        @Size(max = 50)
        String code,

        @Size(max = 254)
        String email,

        @Size(max = 255)
        String fullName,

        @Pattern(regexp = "^(STUDENT|LIBRARIAN|ADMIN)$", message = "Role must be STUDENT, LIBRARIAN, or ADMIN")
        String role,

        @Pattern(regexp = "^(ACTIVE|LOCKED)$", message = "Status must be ACTIVE or LOCKED")
        String status
) {}
