package com.library.checkin.dto;

import java.util.List;

public record OccupantPage(
        List<Occupant> items,
        long page,
        long size,
        long totalElements,
        long totalPages
) {}
