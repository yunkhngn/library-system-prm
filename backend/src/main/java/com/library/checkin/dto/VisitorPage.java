package com.library.checkin.dto;

import java.util.List;

public record VisitorPage(
        List<VisitorDto> items,
        long page,
        long size,
        long totalElements,
        long totalPages
) {}
