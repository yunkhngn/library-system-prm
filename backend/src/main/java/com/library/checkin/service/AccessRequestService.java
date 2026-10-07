package com.library.checkin.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.AccessRequestStatus;
import com.library.checkin.dto.AccessResult;
import com.library.checkin.entity.AccessRequest;
import com.library.checkin.exception.ApiError;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.AccessRequestRepository;
import com.library.checkin.security.CurrentPrincipal;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Optional;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class AccessRequestService {

    private final AccessRequestRepository accessRequestRepository;
    private final ObjectMapper objectMapper;

    public enum ClaimState {
        NEW,
        IN_PROGRESS,
        COMPLETED
    }

    public record AccessClaim(
            UUID requestId,
            ClaimState state,
            Integer responseStatus,
            String responseBody
    ) {}

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public AccessClaim claim(CurrentPrincipal principal, UUID idempotencyKey, String method, String path, String digest) {
        String principalType = principal.type().name();
        UUID principalId = principal.id();

        Optional<AccessRequest> existingOpt = accessRequestRepository.findByPrincipalTypeAndPrincipalIdAndIdempotencyKey(
                principalType, principalId, idempotencyKey
        );

        OffsetDateTime now = OffsetDateTime.now();

        if (existingOpt.isPresent()) {
            AccessRequest existing = existingOpt.get();

            if (!existing.getRequestDigest().equals(digest) ||
                !existing.getRequestMethod().equalsIgnoreCase(method) ||
                !existing.getRequestPath().equalsIgnoreCase(path)) {
                throw new ApiException(HttpStatus.CONFLICT, "IDEMPOTENCY_CONFLICT",
                        "Idempotency key was previously used with a different request payload or endpoint");
            }

            if ("COMPLETED".equalsIgnoreCase(existing.getStatus())) {
                return new AccessClaim(existing.getId(), ClaimState.COMPLETED, existing.getResponseStatus(), existing.getResponseBody());
            }

            if (now.isBefore(existing.getProcessingDeadline())) {
                throw new ApiException(HttpStatus.CONFLICT, "REQUEST_IN_PROGRESS", "Request is currently being processed");
            } else {
                throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "REQUEST_ABORTED", "Previous request timed out");
            }
        }

        AccessRequest newReq = new AccessRequest();
        newReq.setPrincipalType(principalType);
        newReq.setPrincipalId(principalId);
        newReq.setIdempotencyKey(idempotencyKey);
        newReq.setRequestMethod(method);
        newReq.setRequestPath(path);
        newReq.setRequestDigest(digest);
        newReq.setStatus("IN_PROGRESS");
        newReq.setCreatedAt(now);
        newReq.setProcessingDeadline(now.plus(60, ChronoUnit.SECONDS));
        newReq.setExpiresAt(now.plus(24, ChronoUnit.HOURS));

        newReq = accessRequestRepository.save(newReq);
        return new AccessClaim(newReq.getId(), ClaimState.NEW, null, null);
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void complete(UUID requestId, int status, String responseBody) {
        accessRequestRepository.findById(requestId).ifPresent(req -> {
            req.setStatus("COMPLETED");
            req.setResponseStatus(status);
            req.setResponseBody(responseBody);
            accessRequestRepository.save(req);
        });
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void abort(UUID requestId) {
        accessRequestRepository.deleteById(requestId);
    }

    @Transactional(readOnly = true)
    public AccessRequestStatus getStatus(CurrentPrincipal principal, UUID idempotencyKey) {
        String principalType = principal.type().name();
        UUID principalId = principal.id();

        AccessRequest req = accessRequestRepository.findByPrincipalTypeAndPrincipalIdAndIdempotencyKey(
                principalType, principalId, idempotencyKey
        ).orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Access request not found"));

        if (OffsetDateTime.now().isAfter(req.getExpiresAt())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Access request retention expired");
        }

        if ("IN_PROGRESS".equalsIgnoreCase(req.getStatus())) {
            return new AccessRequestStatus(
                    req.getId(),
                    req.getIdempotencyKey(),
                    "IN_PROGRESS",
                    null,
                    null,
                    null,
                    req.getProcessingDeadline(),
                    req.getExpiresAt()
            );
        }

        AccessResult result = null;
        ApiError error = null;
        if (req.getResponseStatus() != null && req.getResponseStatus() == 200) {
            try {
                result = objectMapper.readValue(req.getResponseBody(), AccessResult.class);
            } catch (Exception e) {
                log.error("Failed to deserialize stored AccessResult", e);
            }
        } else if (req.getResponseBody() != null) {
            try {
                error = objectMapper.readValue(req.getResponseBody(), ApiError.class);
            } catch (Exception e) {
                log.error("Failed to deserialize stored ApiError", e);
            }
        }

        return new AccessRequestStatus(
                req.getId(),
                req.getIdempotencyKey(),
                "COMPLETED",
                req.getResponseStatus(),
                result,
                error,
                req.getProcessingDeadline(),
                req.getExpiresAt()
        );
    }
}
