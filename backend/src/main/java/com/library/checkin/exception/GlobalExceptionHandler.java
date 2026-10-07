package com.library.checkin.exception;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ApiException.class)
    public ResponseEntity<ApiError> handleApiException(ApiException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                ex.getCode(),
                ex.getMessage(),
                ex.getFieldErrors(),
                traceId,
                OffsetDateTime.now(),
                ex.isFallbackRecommended()
        );
        return ResponseEntity.status(ex.getStatus()).body(error);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> handleValidationException(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        List<ApiError.FieldErrorItem> fieldErrors = new ArrayList<>();
        for (FieldError fe : ex.getBindingResult().getFieldErrors()) {
            fieldErrors.add(new ApiError.FieldErrorItem(fe.getField(), fe.getDefaultMessage()));
        }
        ApiError error = new ApiError(
                "VALIDATION_ERROR",
                "Validation failed for request payload",
                fieldErrors,
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(error);
    }

    @ExceptionHandler(AccessDeniedException.class)
    public ResponseEntity<ApiError> handleAccessDenied(AccessDeniedException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "FORBIDDEN",
                ex.getMessage() != null ? ex.getMessage() : "Access denied",
                List.of(),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.FORBIDDEN).body(error);
    }

    @ExceptionHandler(AuthenticationException.class)
    public ResponseEntity<ApiError> handleAuthenticationException(AuthenticationException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "UNAUTHENTICATED",
                ex.getMessage() != null ? ex.getMessage() : "Authentication required",
                List.of(),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(error);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiError> handleGeneralException(Exception ex, HttpServletRequest request) {
        org.slf4j.LoggerFactory.getLogger(GlobalExceptionHandler.class).error("Unhandled exception processing request " + request.getRequestURI(), ex);
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "INTERNAL_ERROR",
                "An unexpected server error occurred",
                List.of(),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(error);
    }

    private String getOrCreateTraceId(HttpServletRequest request) {
        String headerTraceId = request.getHeader("X-Trace-Id");
        return headerTraceId != null && !headerTraceId.isBlank() ? headerTraceId : UUID.randomUUID().toString();
    }
}
