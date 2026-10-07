package com.library.checkin.dto;

import java.util.UUID;

public record Actor(
        UUID id,
        String type,
        String code,
        String fullName
) {}
