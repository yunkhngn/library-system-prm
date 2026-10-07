package com.library.checkin.dto;

import java.util.List;

public record AssignmentBatch(
        ShiftDto shift,
        List<AssignmentDto> assignments
) {}
