package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record UserDto(
        UUID id,
        String code,
        String email,
        String fullName,
        String role,
        String status,
        boolean mustChangePassword,
        boolean faceEnrolled,
        long version,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {}
