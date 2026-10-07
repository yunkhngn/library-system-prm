package com.library.checkin.dto;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

public record AssignStaffRequest(
        @NotNull
        Long version,

        @NotEmpty
        @Size(min = 1, max = 100)
        List<UUID> staffIds
) {}
