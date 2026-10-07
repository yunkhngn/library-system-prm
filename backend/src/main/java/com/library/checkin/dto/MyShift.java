package com.library.checkin.dto;

public record MyShift(
        ShiftDto shift,
        AssignmentDto assignment
) {}
