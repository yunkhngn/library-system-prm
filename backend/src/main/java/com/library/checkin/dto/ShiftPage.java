package com.library.checkin.dto;

import java.util.List;

public record ShiftPage(
        List<ShiftDto> items,
        Long page,
        Long size,
        Long totalElements,
        Long totalPages
) {}
