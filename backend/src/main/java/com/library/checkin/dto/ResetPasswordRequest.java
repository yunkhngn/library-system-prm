package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ResetPasswordRequest(
        @NotNull(message = "Version is required for optimistic locking")
        Long version,

        @NotBlank(message = "New password is required")
        @Size(min = 12, max = 64, message = "Password must be between 12 and 64 characters")
        String newPassword
) {}
