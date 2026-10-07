package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record ConsentRequest(
        @NotBlank(message = "policyVersion is required")
        String policyVersion,

        @NotNull(message = "accepted is required")
        Boolean accepted
) {}
