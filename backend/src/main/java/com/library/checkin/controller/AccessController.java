package com.library.checkin.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
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

import org.springframework.web.multipart.MultipartFile;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.OffsetDateTime;
import java.util.HexFormat;
import java.util.List;
import java.util.UUID;

@Slf4j
@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
@Tag(name = "Access", description = "Access control, check-in, check-out and history endpoints")
public class AccessController {

    private final AccessService accessService;
    private final AccessRequestService accessRequestService;
    private final QrCheckInStrategy qrCheckInStrategy;
    private final com.library.checkin.service.FaceAccessService faceAccessService;
    private final ObjectMapper objectMapper;

    @Operation(summary = "issueFaceChallenge", operationId = "issueFaceChallenge")
    @PreAuthorize("hasRole('KIOSK')")
    @PostMapping("/access/face-challenge")
    public ResponseEntity<FaceChallenge> issueFaceChallenge(
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        FaceChallenge challenge = faceAccessService.issueFaceChallenge(principal.id());
        return ResponseEntity.created(URI.create("/api/v1/access/face-challenge/" + challenge.challengeId()))
                .body(challenge);
    }

    @Operation(summary = "recordFaceAccess", operationId = "recordFaceAccess")
    @PreAuthorize("hasRole('KIOSK')")
    @PostMapping(value = "/access/face", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> recordFaceAccess(
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKeyHeader,
            @AuthenticationPrincipal CurrentPrincipal principal,
            @RequestParam("challengeId") String challengeIdStr,
            @RequestParam("clip") MultipartFile clip
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

        UUID challengeId;
        try {
            challengeId = UUID.fromString(challengeIdStr.trim());
        } catch (IllegalArgumentException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CHALLENGE_INVALID", "Invalid challengeId format", true);
        }

        String rawDigestInput = challengeId + ":" + (clip != null ? clip.getSize() : 0);
        String digest = sha256Hex(rawDigestInput);

        AccessRequestService.AccessClaim claim = accessRequestService.claim(
                principal, idempotencyKey, "POST", "/api/v1/access/face", digest
        );

        if (claim.state() == AccessRequestService.ClaimState.COMPLETED) {
            int status = claim.responseStatus() != null ? claim.responseStatus() : 200;
            return ResponseEntity.status(status)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(claim.responseBody());
        }

        try {
            AccessResult result = faceAccessService.recordFaceAccess(principal, claim.requestId(), challengeId, clip);
            return ResponseEntity.ok(result);
        } catch (ApiException e) {
            if (e.getStatus().is4xxClientError() || "SIMULATED_RESULT_REJECTED".equals(e.getCode())) {
                ApiError err = new ApiError(e.getCode(), e.getMessage(), List.of(), UUID.randomUUID().toString(), OffsetDateTime.now(), e.isFallbackRecommended());
                try {
                    accessRequestService.complete(claim.requestId(), e.getStatus().value(), objectMapper.writeValueAsString(err));
                } catch (Exception ex) {
                    log.error("Failed to persist error for face idempotency key", ex);
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

    @Operation(summary = "Record QR access", operationId = "recordQrAccess")
    @PreAuthorize("hasRole('KIOSK')")
    @PostMapping("/access/qr")
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

    @Operation(summary = "Record manual access", operationId = "recordManualAccess")
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @PostMapping("/access/manual")
    public ResponseEntity<?> recordManualAccess(
            @RequestHeader(value = "Idempotency-Key", required = false) String idempotencyKeyHeader,
            @AuthenticationPrincipal CurrentPrincipal principal,
            @Valid @RequestBody ManualAccessRequest body
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

        String rawDigestInput = (body.userId() != null ? body.userId().toString() : "") + ":" +
                                (body.visitorId() != null ? body.visitorId().toString() : "") + ":" +
                                body.action() + ":" + body.reason();
        String digest = sha256Hex(rawDigestInput);

        AccessRequestService.AccessClaim claim = accessRequestService.claim(
                principal, idempotencyKey, "POST", "/api/v1/access/manual", digest
        );

        if (claim.state() == AccessRequestService.ClaimState.COMPLETED) {
            int status = claim.responseStatus() != null ? claim.responseStatus() : 200;
            return ResponseEntity.status(status)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(claim.responseBody());
        }

        try {
            AccessResult result = accessService.recordManualAccess(principal.getUserId(), claim.requestId(), body);
            return ResponseEntity.ok(result);
        } catch (ApiException e) {
            if (e.getStatus().is4xxClientError()) {
                ApiError err = new ApiError(e.getCode(), e.getMessage(), List.of(), UUID.randomUUID().toString(), OffsetDateTime.now(), false);
                try {
                    accessRequestService.complete(claim.requestId(), e.getStatus().value(), objectMapper.writeValueAsString(err));
                } catch (Exception ex) {
                    log.error("Failed to persist error for manual idempotency key", ex);
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
    @GetMapping("/access/requests/{idempotencyKey}")
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

    @Operation(summary = "List access history", operationId = "listAccessHistory")
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @GetMapping("/access-history")
    public ResponseEntity<AccessSessionPage> listAccessHistory(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "from", required = false) OffsetDateTime from,
            @RequestParam(name = "to", required = false) OffsetDateTime to,
            @RequestParam(name = "q", required = false) String q,
            @RequestParam(name = "userId", required = false) UUID userId,
            @RequestParam(name = "visitorId", required = false) UUID visitorId,
            @RequestParam(name = "isOpen", required = false) Boolean isOpen,
            @RequestParam(name = "method", required = false) String method,
            @RequestParam(name = "sort", defaultValue = "checkInTime,desc") String sort
    ) {
        AccessSessionPage result = accessService.listAccessHistory(from, to, q, userId, visitorId, isOpen, method, page, size, sort);
        return ResponseEntity.ok(result);
    }

    @Operation(summary = "Get access session", operationId = "getAccessSession")
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @GetMapping("/access-history/{sessionId}")
    public ResponseEntity<AccessSession> getAccessSession(@PathVariable("sessionId") UUID sessionId) {
        AccessSession session = accessService.getAccessSession(sessionId);
        return ResponseEntity.ok(session);
    }

    @Operation(summary = "Get my access status", operationId = "getMyAccessStatus")
    @PreAuthorize("hasRole('STUDENT')")
    @GetMapping("/me/access-status")
    public ResponseEntity<AccessStatus> getMyAccessStatus(@AuthenticationPrincipal CurrentPrincipal principal) {
        AccessStatus status = accessService.getMyAccessStatus(principal.getUserId());
        return ResponseEntity.ok(status);
    }

    @Operation(summary = "List my access history", operationId = "listMyAccessHistory")
    @PreAuthorize("hasRole('STUDENT')")
    @GetMapping("/me/access-history")
    public ResponseEntity<AccessSessionPage> listMyAccessHistory(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "from", required = false) OffsetDateTime from,
            @RequestParam(name = "to", required = false) OffsetDateTime to,
            @RequestParam(name = "sort", defaultValue = "checkInTime,desc") String sort,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        AccessSessionPage result = accessService.listMyAccessHistory(principal.getUserId(), from, to, page, size, sort);
        return ResponseEntity.ok(result);
    }

    @Operation(summary = "Get my access session", operationId = "getMyAccessSession")
    @PreAuthorize("hasRole('STUDENT')")
    @GetMapping("/me/access-history/{sessionId}")
    public ResponseEntity<AccessSession> getMyAccessSession(
            @PathVariable("sessionId") UUID sessionId,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        AccessSession session = accessService.getMyAccessSession(principal.getUserId(), sessionId);
        return ResponseEntity.ok(session);
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
