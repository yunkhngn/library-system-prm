package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateVisitorRequest(
        @NotBlank(message = "fullName is required")
        @Size(min = 1, max = 150, message = "fullName must be between 1 and 150 characters")
        String fullName
) {}
