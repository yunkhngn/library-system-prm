package com.library.checkin.dto;

import java.util.List;

public record AccessSessionPage(
        List<AccessSession> items,
        long page,
        long size,
        long totalElements,
        long totalPages
) {}
