package com.library.checkin.exception;

import lombok.Getter;
import org.springframework.http.HttpStatus;

import java.util.List;

@Getter
public class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final String code;
    private final List<ApiError.FieldErrorItem> fieldErrors;
    private final boolean fallbackRecommended;

    public ApiException(HttpStatus status, String code, String message) {
        super(message);
        this.status = status;
        this.code = code;
        this.fieldErrors = List.of();
        this.fallbackRecommended = false;
    }

    public ApiException(HttpStatus status, String code, String message, List<ApiError.FieldErrorItem> fieldErrors) {
        super(message);
        this.status = status;
        this.code = code;
        this.fieldErrors = fieldErrors != null ? fieldErrors : List.of();
        this.fallbackRecommended = false;
    }

    public ApiException(HttpStatus status, String code, String message, boolean fallbackRecommended) {
        super(message);
        this.status = status;
        this.code = code;
        this.fieldErrors = List.of();
        this.fallbackRecommended = fallbackRecommended;
    }
}
