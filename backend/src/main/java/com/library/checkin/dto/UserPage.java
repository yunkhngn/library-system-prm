package com.library.checkin.dto;

import java.util.List;

public record UserPage(
        List<UserDto> items,
        int page,
        int size,
        long totalElements,
        int totalPages
) {}
