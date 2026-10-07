package com.library.checkin.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.AccessRequestStatus;
import com.library.checkin.dto.AccessResult;
import com.library.checkin.dto.QrAccessRequest;
import com.library.checkin.exception.ApiError;
import com.library.checkin.exception.ApiException;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.AccessRequestService;
import com.library.checkin.service.AccessService;
import com.library.checkin.service.strategy.AccessCommand;
import com.library.checkin.service.strategy.IdentityProof;
import com.library.checkin.service.strategy.QrCheckInStrategy;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/v1/access")
@RequiredArgsConstructor
@Tag(name = "Access", description = "Access control, check-in and check-out endpoints")
public class AccessController {

    private final AccessService accessService;
    private final AccessRequestService accessRequestService;
    private final QrCheckInStrategy qrCheckInStrategy;
    private final ObjectMapper objectMapper;

    @Operation(summary = "Record QR access", operationId = "recordQrAccess")
    @PreAuthorize("hasRole('KIOSK')")
    @PostMapping("/qr")
    public ResponseEntity<?> recordQrAccess(
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKeyHeader,
            @AuthenticationPrincipal CurrentPrincipal principal,
            @Valid @RequestBody QrAccessRequest body
    ) {
        if (idempotencyKeyHeader == null || idempotencyKeyHeader.trim().isEmpty()) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "IDEMPOTENCY_KEY_REQUIRED", "Idempotency-Key header is required");
        }

        UUID idempotencyKey;
        try {
            idempotencyKey = UUID.fromString(idempotencyKeyHeader.trim());
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "Idempotency-Key must be a valid UUID");
        }

        String digest = sha256Hex(body.token());

        AccessRequestService.AccessClaim claim = accessRequestService.claim(
                principal, idempotencyKey, "POST", "/api/v1/access/qr", digest
        );

        if (claim.state() == AccessRequestService.ClaimState.COMPLETED) {
            int status = claim.responseStatus() != null ? claim.responseStatus() : 200;
            return ResponseEntity.status(status)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(claim.responseBody());
        }

        try {
            IdentityProof proof = qrCheckInStrategy.authenticate(body);
            AccessCommand command = new AccessCommand(claim.requestId(), principal, null, proof);
            AccessResult result = accessService.record(command);
            return ResponseEntity.ok(result);
        } catch (ApiException e) {
            if (e.getStatus().is4xxClientError()) {
                ApiError err = new ApiError(e.getCode(), e.getMessage(), List.of(), UUID.randomUUID().toString(), OffsetDateTime.now(), false);
                try {
                    accessRequestService.complete(claim.requestId(), e.getStatus().value(), objectMapper.writeValueAsString(err));
                } catch (Exception ex) {
                    log.error("Failed to persist error for idempotency key", ex);
                }
            } else {
                accessRequestService.abort(claim.requestId());
            }
            throw e;
        } catch (Exception e) {
            accessRequestService.abort(claim.requestId());
            throw e;
        }
    }

    @Operation(summary = "Get access request status", operationId = "getAccessRequestStatus")
    @PreAuthorize("hasAnyRole('KIOSK', 'LIBRARIAN', 'ADMIN')")
    @GetMapping("/requests/{idempotencyKey}")
    public ResponseEntity<AccessRequestStatus> getAccessRequestStatus(
            @PathVariable("idempotencyKey") String idempotencyKeyStr,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        UUID idempotencyKey;
        try {
            idempotencyKey = UUID.fromString(idempotencyKeyStr.trim());
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "idempotencyKey must be a valid UUID");
        }

        AccessRequestStatus status = accessRequestService.getStatus(principal, idempotencyKey);
        return ResponseEntity.ok(status);
    }

    private String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 unavailable", e);
        }
    }
}
