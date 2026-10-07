package com.library.checkin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record HeartbeatRequest(
        @NotBlank(message = "appVersion is required")
        @Size(min = 1, max = 32)
        String appVersion,

        @NotBlank(message = "cameraStatus is required")
        @Pattern(regexp = "^(OK|ERROR|UNAVAILABLE)$", message = "cameraStatus must be OK, ERROR, or UNAVAILABLE")
        String cameraStatus
) {}
