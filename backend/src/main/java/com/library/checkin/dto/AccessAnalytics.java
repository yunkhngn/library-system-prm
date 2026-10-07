package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record AccessAnalytics(
        OffsetDateTime from,
        OffsetDateTime to,
        String timezone,
        String bucket,
        long totalCheckIns,
        long totalCheckOuts,
        Double averageStaySeconds,
        List<AccessBucket> buckets
) {}
