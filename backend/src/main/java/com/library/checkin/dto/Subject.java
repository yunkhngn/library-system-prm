package com.library.checkin.dto;

import java.util.UUID;

public record Subject(
        UUID id,
        String kind, // USER, VISITOR
        String code,
        String fullName
) {}
