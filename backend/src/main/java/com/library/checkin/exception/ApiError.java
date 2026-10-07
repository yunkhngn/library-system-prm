package com.library.checkin.exception;

import java.time.OffsetDateTime;
import java.util.List;

public record ApiError(
        String code,
        String message,
        List<FieldErrorItem> fieldErrors,
        String traceId,
        OffsetDateTime timestamp,
        boolean fallbackRecommended
) {
    public record FieldErrorItem(String field, String message) {}

    public static ApiError of(String code, String message, String traceId) {
        return new ApiError(code, message, List.of(), traceId, OffsetDateTime.now(), false);
    }

    public static ApiError of(String code, String message, List<FieldErrorItem> fieldErrors, String traceId) {
        return new ApiError(code, message, fieldErrors, traceId, OffsetDateTime.now(), false);
    }
}
