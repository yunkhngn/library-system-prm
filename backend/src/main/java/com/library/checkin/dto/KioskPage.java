package com.library.checkin.dto;

import java.util.List;

public record KioskPage(
        List<KioskDto> items,
        int page,
        int size,
        long totalElements,
        int totalPages
) {}
