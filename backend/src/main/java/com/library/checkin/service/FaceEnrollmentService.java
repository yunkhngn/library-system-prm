package com.library.checkin.service;

import com.library.checkin.dto.*;
import com.library.checkin.entity.BiometricConsent;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.BiometricConsentRepository;
import com.library.checkin.repository.FaceEmbeddingRepository;
import com.library.checkin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class FaceEnrollmentService {

    public static final String CURRENT_POLICY_VERSION = "1.0";

    private final UserRepository userRepository;
    private final BiometricConsentRepository biometricConsentRepository;
    private final FaceEmbeddingRepository faceEmbeddingRepository;
    private final AiClient aiClient;

    public FacePolicy getFacePolicy() {
        return new FacePolicy(
                CURRENT_POLICY_VERSION,
                "Thỏa thuận xử lý dữ liệu sinh trắc học và nhận diện khuôn mặt",
                "Chính sách quản lý, mã hóa và bảo mật dữ liệu mẫu khuôn mặt phục vụ kiểm soát ra vào thư viện theo tiêu chuẩn bảo mật dữ liệu.",
                FaceCaptureRules.defaultRules()
        );
    }

    public record ConsentResult(FaceConsent consent, boolean isNew) {}

    @Transactional
    public ConsentResult grantConsent(UUID userId, ConsentRequest request) {
        if (request.accepted() == null || !request.accepted()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Consent must be explicitly accepted");
        }
        if (request.policyVersion() == null || !CURRENT_POLICY_VERSION.equals(request.policyVersion())) {
            throw new ApiException(HttpStatus.CONFLICT, "CONSENT_POLICY_CHANGED", "Consent policy version mismatch or superseded");
        }

        User user = userRepository.findByIdForUpdate(userId).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found")
        );

        if (!"STUDENT".equals(user.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Only students can grant biometric consent");
        }

        Optional<BiometricConsent> existingActive = biometricConsentRepository.findActiveConsentByUserId(userId);
        if (existingActive.isPresent()) {
            BiometricConsent active = existingActive.get();
            if (CURRENT_POLICY_VERSION.equals(active.getPolicyVersion())) {
                return new ConsentResult(toConsentDto(active), false);
            } else {
                throw new ApiException(HttpStatus.CONFLICT, "CONSENT_POLICY_CHANGED", "Active consent has older policy version");
            }
        }

        BiometricConsent newConsent = new BiometricConsent();
        newConsent.setUserId(userId);
        newConsent.setPolicyVersion(request.policyVersion());
        newConsent.setGrantedAt(OffsetDateTime.now());
        newConsent.setVersion(0L);

        newConsent = biometricConsentRepository.saveAndFlush(newConsent);
        log.info("Granted new biometric consent for student {}", user.getCode());
        return new ConsentResult(toConsentDto(newConsent), true);
    }

    @Transactional(readOnly = true)
    public FaceEnrollment getMyEnrollment(UUID userId) {
        User user = userRepository.findById(userId).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found")
        );

        Optional<BiometricConsent> activeConsent = biometricConsentRepository.findActiveConsentByUserId(userId);
        long count = faceEmbeddingRepository.countByUserId(userId);
        Optional<FaceEmbeddingRepository.EmbeddingMetadata> meta = faceEmbeddingRepository.findLatestMetadataByUserId(userId);

        long version = user.getBiometricVersion() != null ? user.getBiometricVersion() : 0L;
        boolean isEnrolled = count > 0 && activeConsent.isPresent();

        return new FaceEnrollment(
                isEnrolled,
                activeConsent.map(this::toConsentDto).orElse(null),
                count,
                meta.map(FaceEmbeddingRepository.EmbeddingMetadata::modelId).orElse(null),
                meta.map(FaceEmbeddingRepository.EmbeddingMetadata::modelVersion).orElse(null),
                meta.map(FaceEmbeddingRepository.EmbeddingMetadata::createdAt).orElse(null),
                version
        );
    }

    @Transactional
    public FaceEnrollment enrollMyFace(UUID userId, List<MultipartFile> images, Long version) {
        User user = userRepository.findByIdForUpdate(userId).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found")
        );

        if (!"STUDENT".equals(user.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Only students can enroll face biometrics");
        }
        if (!"ACTIVE".equals(user.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Account is not active");
        }

        long currentVersion = user.getBiometricVersion() != null ? user.getBiometricVersion() : 0L;
        if (version == null || version != currentVersion) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Biometric version conflict: expected " + currentVersion);
        }

        Optional<BiometricConsent> activeConsent = biometricConsentRepository.findActiveConsentByUserId(userId);
        if (activeConsent.isEmpty()) {
            throw new ApiException(HttpStatus.CONFLICT, "CONSENT_REQUIRED", "Active biometric consent is required before enrollment");
        }
        if (!CURRENT_POLICY_VERSION.equals(activeConsent.get().getPolicyVersion())) {
            throw new ApiException(HttpStatus.CONFLICT, "CONSENT_POLICY_CHANGED", "Consent policy has been updated. Re-consent is required");
        }

        // Validate image limits
        if (images == null || images.size() < 3 || images.size() > 5) {
            throw new ApiException(
                    HttpStatus.UNPROCESSABLE_ENTITY,
                    "IMAGE_INVALID",
                    "Enrollment requires between 3 and 5 images (received " + (images != null ? images.size() : 0) + ")"
            );
        }

        long totalBytes = 0;
        for (MultipartFile img : images) {
            if (img.getSize() > 5242880L) {
                throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "PAYLOAD_TOO_LARGE", "Single image size exceeds 5 MB limit");
            }
            totalBytes += img.getSize();
            if (totalBytes > 26214400L) {
                throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "PAYLOAD_TOO_LARGE", "Total upload size exceeds 25 MB limit");
            }
        }

        // Call AI Service
        InternalEmbeddingResult aiResult = aiClient.extractEmbeddings(images);
        if (aiResult.embeddings() == null || aiResult.embeddings().size() != images.size()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INCONSISTENT_FACES", "Failed to extract embeddings for all provided face images");
        }

        // Atomic replacement
        faceEmbeddingRepository.deleteByUserId(userId);
        faceEmbeddingRepository.insertEmbeddings(
                userId,
                activeConsent.get().getId(),
                aiResult.embeddings(),
                aiResult.modelId(),
                aiResult.modelVersion()
        );

        long newVersion = currentVersion + 1;
        user.setBiometricVersion(newVersion);
        userRepository.saveAndFlush(user);

        log.info("Successfully enrolled {} face images for student {}", images.size(), user.getCode());

        return new FaceEnrollment(
                true,
                toConsentDto(activeConsent.get()),
                images.size(),
                aiResult.modelId(),
                aiResult.modelVersion(),
                OffsetDateTime.now(),
                newVersion
        );
    }

    @Transactional
    public FaceDeletion deleteMyEnrollment(UUID userId, Long version) {
        User user = userRepository.findByIdForUpdate(userId).orElseThrow(
                () -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found")
        );

        if (!"STUDENT".equals(user.getRole())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Only students can manage biometric enrollment");
        }

        long currentVersion = user.getBiometricVersion() != null ? user.getBiometricVersion() : 0L;
        if (version == null || version != currentVersion) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Biometric version conflict: expected " + currentVersion);
        }

        OffsetDateTime now = OffsetDateTime.now();
        Optional<BiometricConsent> activeConsent = biometricConsentRepository.findActiveConsentByUserId(userId);
        long count = faceEmbeddingRepository.countByUserId(userId);

        if (activeConsent.isEmpty() && count == 0) {
            // Already clean and not enrolled; return without increment
            return new FaceDeletion(false, currentVersion, now);
        }

        if (activeConsent.isPresent()) {
            BiometricConsent consent = activeConsent.get();
            consent.setRevokedAt(now);
            biometricConsentRepository.saveAndFlush(consent);
        }

        if (count > 0) {
            faceEmbeddingRepository.deleteByUserId(userId);
        }

        long newVersion = currentVersion + 1;
        user.setBiometricVersion(newVersion);
        userRepository.saveAndFlush(user);

        log.info("Revoked consent and deleted biometric enrollment for student {}", user.getCode());
        return new FaceDeletion(false, newVersion, now);
    }

    private FaceConsent toConsentDto(BiometricConsent bc) {
        return new FaceConsent(
                bc.getId(),
                bc.getPolicyVersion(),
                bc.getGrantedAt(),
                bc.getRevokedAt(),
                bc.getVersion() != null ? bc.getVersion() : 0L
        );
    }
}
