package com.library.checkin.dto;

import java.util.List;

public record MyShiftPage(
        List<MyShift> items,
        Long page,
        Long size,
        Long totalElements,
        Long totalPages
) {}
