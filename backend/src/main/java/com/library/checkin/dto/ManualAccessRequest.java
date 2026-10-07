package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.UUID;

public record ManualAccessRequest(
        UUID userId,
        UUID visitorId,
        @NotNull(message = "action is required")
        String action,
        @NotBlank(message = "reason is required")
        @Size(min = 1, max = 1000, message = "reason must be between 1 and 1000 characters")
        String reason
) {}
