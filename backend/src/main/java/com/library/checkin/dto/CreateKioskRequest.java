package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateKioskRequest(
        @NotBlank(message = "Code is required")
        @Size(max = 50)
        String code,

        @NotBlank(message = "Name is required")
        @Size(max = 100)
        String name,

        @NotBlank(message = "Mode is required")
        @Pattern(regexp = "^(ENTRY|EXIT|AUTO)$", message = "Mode must be ENTRY, EXIT, or AUTO")
        String mode
) {}
