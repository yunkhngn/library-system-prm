package com.library.checkin.dto;

import java.util.UUID;

public record KioskSummary(
        UUID id,
        String code,
        String name
) {}
