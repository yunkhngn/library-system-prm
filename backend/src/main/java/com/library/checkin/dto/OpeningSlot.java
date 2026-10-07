package com.library.checkin.dto;

public record OpeningSlot(
        int dayOfWeek,
        String opensAt,
        String closesAt
) {}
