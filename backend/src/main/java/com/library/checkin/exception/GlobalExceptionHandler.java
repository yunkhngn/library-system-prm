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

    @ExceptionHandler(org.springframework.dao.DataIntegrityViolationException.class)
    public ResponseEntity<ApiError> handleDataIntegrityViolation(org.springframework.dao.DataIntegrityViolationException ex, HttpServletRequest request) {
        String msg = ex.getMessage() != null ? ex.getMessage() : "";
        Throwable rootCause = ex.getRootCause();
        if (rootCause != null && rootCause.getMessage() != null) {
            msg += " " + rootCause.getMessage();
        }
        String traceId = getOrCreateTraceId(request);

        if (msg.contains("no_staff_overlap")) {
            ApiError error = new ApiError(
                    "SHIFT_OVERLAP",
                    "Staff member has an overlapping shift assignment",
                    List.of(),
                    traceId,
                    OffsetDateTime.now(),
                    false
            );
            return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
        }
        if (msg.contains("chk_shift_duration") || msg.contains("chk_assignment_duration")) {
            ApiError error = new ApiError(
                    "INVALID_TIME_RANGE",
                    "Invalid shift duration or time range",
                    List.of(),
                    traceId,
                    OffsetDateTime.now(),
                    false
            );
            return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(error);
        }

        ApiError error = new ApiError(
                "DATA_INTEGRITY_VIOLATION",
                "Database constraint violation",
                List.of(),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.CONFLICT).body(error);
    }

    @ExceptionHandler(org.springframework.web.bind.MissingRequestHeaderException.class)
    public ResponseEntity<ApiError> handleMissingHeader(org.springframework.web.bind.MissingRequestHeaderException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        String code = "Idempotency-Key".equalsIgnoreCase(ex.getHeaderName()) ? "IDEMPOTENCY_KEY_REQUIRED" : "HEADER_MISSING";
        ApiError error = new ApiError(
                code,
                ex.getMessage(),
                List.of(new ApiError.FieldErrorItem(ex.getHeaderName(), "Required header is missing")),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(org.springframework.web.bind.MissingServletRequestParameterException.class)
    public ResponseEntity<ApiError> handleMissingParam(org.springframework.web.bind.MissingServletRequestParameterException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "MISSING_PARAMETER",
                ex.getMessage(),
                List.of(new ApiError.FieldErrorItem(ex.getParameterName(), "Required parameter is missing")),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler({org.springframework.web.multipart.MultipartException.class, org.springframework.web.multipart.support.MissingServletRequestPartException.class})
    public ResponseEntity<ApiError> handleMultipartException(Exception ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "MULTIPART_ERROR",
                ex.getMessage(),
                List.of(),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(error);
    }

    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ApiError> handleMediaTypeNotSupported(org.springframework.web.HttpMediaTypeNotSupportedException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "UNSUPPORTED_MEDIA_TYPE",
                ex.getMessage(),
                List.of(),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.UNSUPPORTED_MEDIA_TYPE).body(error);
    }

    @ExceptionHandler(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiError> handleTypeMismatch(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException ex, HttpServletRequest request) {
        String traceId = getOrCreateTraceId(request);
        ApiError error = new ApiError(
                "VALIDATION_ERROR",
                "Invalid parameter format: " + ex.getName(),
                List.of(new ApiError.FieldErrorItem(ex.getName(), "Invalid format")),
                traceId,
                OffsetDateTime.now(),
                false
        );
        return ResponseEntity.status(HttpStatus.UNPROCESSABLE_ENTITY).body(error);
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
