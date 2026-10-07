package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record AccessStatus(
        boolean isInside,
        AccessSession currentSession,
        OffsetDateTime asOf
) {}
