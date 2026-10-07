package com.library.checkin.dto;

import java.util.List;

public record AssignmentPage(
        List<AssignmentDto> items,
        Long page,
        Long size,
        Long totalElements,
        Long totalPages
) {}
