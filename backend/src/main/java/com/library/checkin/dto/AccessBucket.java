package com.library.checkin.dto;

import java.time.OffsetDateTime;

public record AccessBucket(
        OffsetDateTime startsAt,
        OffsetDateTime endsAt,
        long checkIns,
        long checkOuts,
        long faceCheckIns,
        long qrCheckIns,
        long manualCheckIns
) {}
