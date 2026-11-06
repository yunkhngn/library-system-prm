package com.library.checkin.service;

import com.library.checkin.dto.*;
import com.library.checkin.entity.Kiosk;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.KioskRepository;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class KioskService {

    private final KioskRepository kioskRepository;
    private final SystemConfigService systemConfigService;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    @Transactional(readOnly = true)
    public KioskPage listKiosks(String query, String status, Boolean isOnline, int page, int size, String sortParam) {
        Sort sort = Sort.by(Sort.Direction.DESC, "createdAt");
        if ("code,asc".equalsIgnoreCase(sortParam)) {
            sort = Sort.by(Sort.Direction.ASC, "code");
        }

        int pageSize = Math.min(Math.max(size, 1), 100);
        int pageIndex = Math.max(page, 0);
        Pageable pageable = PageRequest.of(pageIndex, pageSize, sort);

        Specification<Kiosk> spec = (root, q, cb) -> cb.conjunction();

        if (status != null && !status.trim().isEmpty()) {
            spec = spec.and((root, q, cb) -> cb.equal(root.get("status"), status.trim().toUpperCase()));
        }

        if (query != null && !query.trim().isEmpty()) {
            String pattern = "%" + query.trim().toLowerCase() + "%";
            spec = spec.and((root, q, cb) -> cb.or(
                    cb.like(cb.lower(root.get("code")), pattern),
                    cb.like(cb.lower(root.get("name")), pattern)
            ));
        }

        if (isOnline != null) {
            OffsetDateTime threshold = OffsetDateTime.now().minusSeconds(90);
            if (isOnline) {
                spec = spec.and((root, q, cb) -> cb.and(
                        cb.equal(root.get("status"), "ACTIVE"),
                        cb.isNotNull(root.get("lastSeenAt")),
                        cb.greaterThan(root.get("lastSeenAt"), threshold)
                ));
            } else {
                spec = spec.and((root, q, cb) -> cb.or(
                        cb.notEqual(root.get("status"), "ACTIVE"),
                        cb.isNull(root.get("lastSeenAt")),
                        cb.lessThanOrEqualTo(root.get("lastSeenAt"), threshold)
                ));
            }
        }

        Page<Kiosk> kioskPage = kioskRepository.findAll(spec, pageable);
        List<KioskDto> items = kioskPage.getContent().stream()
                .map(this::toKioskDto)
                .toList();

        return new KioskPage(items, kioskPage.getNumber(), kioskPage.getSize(), kioskPage.getTotalElements(), kioskPage.getTotalPages());
    }

    @Transactional
    public KioskCredential createKiosk(CreateKioskRequest req) {
        String code = req.code().trim().toUpperCase();
        if (kioskRepository.existsByCode(code)) {
            throw new ApiException(HttpStatus.CONFLICT, "CODE_EXISTS", "Kiosk code already exists");
        }

        String rawCredential = jwtService.generateRawRefreshToken(); // ≥32 bytes base64
        String hashedCredential = passwordEncoder.encode(rawCredential);

        Kiosk kiosk = new Kiosk();
        kiosk.setCode(code);
        kiosk.setName(req.name().trim());
        kiosk.setMode(req.mode());
        kiosk.setStatus("ACTIVE");
        kiosk.setCredentialHash(hashedCredential);
        kiosk.setCredentialVersion(0L);

        kiosk = kioskRepository.save(kiosk);
        return new KioskCredential(toKioskDto(kiosk), rawCredential);
    }

    @Transactional(readOnly = true)
    public KioskDto getKiosk(UUID kioskId) {
        Kiosk kiosk = kioskRepository.findById(kioskId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Kiosk not found"));
        return toKioskDto(kiosk);
    }

    @Transactional
    public KioskDto updateKiosk(UUID kioskId, PatchKioskRequest req) {
        Kiosk kiosk = kioskRepository.findById(kioskId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Kiosk not found"));

        if (!kiosk.getVersion().equals(req.version())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Stale version: expected " + kiosk.getVersion() + ", got " + req.version());
        }

        if (req.name() != null && !req.name().trim().isEmpty()) {
            kiosk.setName(req.name().trim());
        }

        if (req.mode() != null) {
            kiosk.setMode(req.mode());
        }

        if (req.status() != null) {
            kiosk.setStatus(req.status());
        }

        kiosk = kioskRepository.save(kiosk);
        return toKioskDto(kiosk);
    }

    @Transactional
    public KioskCredential rotateCredential(UUID kioskId, VersionRequest req) {
        Kiosk kiosk = kioskRepository.findById(kioskId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Kiosk not found"));

        if (!kiosk.getVersion().equals(req.version())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Stale version: expected " + kiosk.getVersion() + ", got " + req.version());
        }

        String rawCredential = jwtService.generateRawRefreshToken();
        String hashedCredential = passwordEncoder.encode(rawCredential);

        kiosk.setCredentialHash(hashedCredential);
        kiosk.setCredentialVersion(kiosk.getCredentialVersion() + 1);
        kiosk.setStatus("ACTIVE");

        kiosk = kioskRepository.save(kiosk);
        return new KioskCredential(toKioskDto(kiosk), rawCredential);
    }

    @Transactional
    public KioskToken loginKiosk(KioskLoginRequest req) {
        Optional<Kiosk> found = req.kioskId() != null
                ? kioskRepository.findById(req.kioskId())
                : kioskRepository.findByCode(req.kioskCode().trim().toUpperCase());
        Kiosk kiosk = found
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Invalid kiosk credentials"));

        if (!passwordEncoder.matches(req.credential(), kiosk.getCredentialHash())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Invalid kiosk credentials");
        }

        if (!"ACTIVE".equalsIgnoreCase(kiosk.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "KIOSK_REVOKED", "Kiosk is revoked");
        }

        String accessToken = jwtService.generateKioskToken(kiosk);
        return new KioskToken(accessToken, "Bearer", JwtService.KIOSK_TOKEN_VALIDITY_SECONDS, toKioskDto(kiosk));
    }

    @Transactional
    public HeartbeatResult heartbeat(CurrentPrincipal principal, HeartbeatRequest req) {
        Kiosk kiosk = kioskRepository.findById(principal.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Kiosk not found"));

        if (!"ACTIVE".equalsIgnoreCase(kiosk.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "KIOSK_REVOKED", "Kiosk is revoked");
        }

        kiosk.setLastSeenAt(OffsetDateTime.now());
        kiosk.setAppVersion(req.appVersion());
        kiosk.setCameraStatus(req.cameraStatus());

        kiosk = kioskRepository.save(kiosk);
        return new HeartbeatResult(OffsetDateTime.now(), 30L, toKioskDto(kiosk));
    }

    @Transactional(readOnly = true)
    public KioskRuntimeConfig getRuntimeConfig(CurrentPrincipal principal) {
        Kiosk kiosk = kioskRepository.findById(principal.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Kiosk not found"));

        if (!"ACTIVE".equalsIgnoreCase(kiosk.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "KIOSK_REVOKED", "Kiosk is revoked");
        }

        SystemConfig config = systemConfigService.getOperational();
        return new KioskRuntimeConfig(
                kiosk.getId(),
                kiosk.getMode(),
                config.timezone() != null ? config.timezone() : "Asia/Ho_Chi_Minh",
                config.openingHours(),
                30L,
                config.scanCooldownSeconds(),
                config.faceModelVersion() != null && !config.faceModelVersion().isBlank()
                        && config.faceMaxCosineDistance() != null
                        && config.faceMinDistanceGap() != null
                        && config.livenessMinScore() != null,
                FaceCaptureRules.defaultRules(),
                OffsetDateTime.now(),
                config.version()
        );
    }

    public KioskDto toKioskDto(Kiosk kiosk) {
        return new KioskDto(
                kiosk.getId(),
                kiosk.getCode(),
                kiosk.getName(),
                kiosk.getMode(),
                kiosk.getStatus(),
                kiosk.isOnline(),
                kiosk.getLastSeenAt(),
                kiosk.getVersion(),
                kiosk.getCreatedAt(),
                kiosk.getUpdatedAt()
        );
    }
}
