package com.library.checkin.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
import com.library.checkin.entity.FaceChallengeEntity;
import com.library.checkin.entity.RecognitionAttempt;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.FaceChallengeRepository;
import com.library.checkin.repository.RecognitionAttemptRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.strategy.AccessCommand;
import com.library.checkin.service.strategy.FaceProof;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Random;
import java.util.UUID;

@Service
@RequiredArgsConstructor
@Slf4j
public class FaceAccessService {

    // Used when the admin has not set a recognition threshold in the operational config.
    // ArcFace cosine distance: same person measured 0.27-0.53 on difficult frames, different people
    // 0.89-1.12. 0.35 rejected genuine users; 0.50 keeps a wide margin to impostors.
    static final double DEFAULT_MAX_COSINE_DISTANCE = 0.50;
    static final double DEFAULT_MIN_DISTANCE_GAP = 0.15;
    static final double DEFAULT_LIVENESS_MIN_SCORE = 0.90;

    private final AiClient aiClient;
    private final AccessService accessService;
    private final SystemConfigService systemConfigService;
    private final FaceChallengeRepository faceChallengeRepository;
    private final RecognitionAttemptRepository recognitionAttemptRepository;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;
    private final Random random = new Random();

    @Transactional
    public FaceChallenge issueFaceChallenge(UUID kioskId) {
        if (!aiClient.isReady()) {
            throw new ApiException(
                    HttpStatus.SERVICE_UNAVAILABLE,
                    "AI_UNAVAILABLE",
                    "AI facial recognition service is currently unavailable",
                    true
            );
        }

        SystemConfig config = systemConfigService.getOperational();
        String secondAction = random.nextBoolean() ? "TURN_LEFT" : "TURN_RIGHT";
        List<ChallengeInstruction> instructions = List.of(
                new ChallengeInstruction("BLINK", 1),
                new ChallengeInstruction(secondAction, 2)
        );

        String instructionsJson;
        try {
            instructionsJson = objectMapper.writeValueAsString(instructions);
        } catch (Exception e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Failed to serialize instructions");
        }

        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime expiresAt = now.plusSeconds(60);

        FaceChallengeEntity entity = new FaceChallengeEntity();
        entity.setKioskId(kioskId);
        entity.setInstructions(instructionsJson);
        entity.setModelVersion("arcface-512-v1");
        entity.setConfigVersion(config.version());
        entity.setCreatedAt(now);
        entity.setExpiresAt(expiresAt);

        entity = faceChallengeRepository.save(entity);

        return new FaceChallenge(
                entity.getId(),
                entity.getExpiresAt(),
                instructions,
                FaceCaptureRules.defaultRules()
        );
    }

    public AccessResult recordFaceAccess(
            CurrentPrincipal principal,
            UUID requestId,
            UUID challengeId,
            MultipartFile clip
    ) {
        UUID kioskId = principal.id();

        // 1. Validate video clip
        if (clip == null || clip.isEmpty()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VIDEO_INVALID", "Video clip is required", true);
        }

        if (clip.getSize() > 10 * 1024 * 1024) {
            throw new ApiException(HttpStatus.PAYLOAD_TOO_LARGE, "PAYLOAD_TOO_LARGE", "Video clip exceeds 10MB limit", true);
        }

        byte[] clipBytes;
        try {
            clipBytes = clip.getBytes();
        } catch (IOException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VIDEO_INVALID", "Failed reading clip bytes", true);
        }

        if (!isValidMp4Container(clipBytes)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VIDEO_INVALID", "Clip must be a valid MP4 container", true);
        }

        // 2. Validate face challenge
        FaceChallengeEntity challenge = faceChallengeRepository.findById(challengeId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CHALLENGE_INVALID", "Challenge not found", true));

        if (!challenge.getKioskId().equals(kioskId)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CHALLENGE_INVALID", "Challenge belongs to a different kiosk", true);
        }

        if (challenge.getConsumedAt() != null) {
            throw new ApiException(HttpStatus.CONFLICT, "CHALLENGE_ALREADY_USED", "Face challenge has already been used", true);
        }

        if (challenge.getExpiresAt().isBefore(OffsetDateTime.now())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CHALLENGE_EXPIRED", "Face challenge has expired", true);
        }

        List<ChallengeInstruction> instructions;
        try {
            instructions = objectMapper.readValue(challenge.getInstructions(), new TypeReference<List<ChallengeInstruction>>() {});
        } catch (Exception e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Failed parsing challenge instructions");
        }

        // 3. Inference call to AI service, using the thresholds the admin configured
        SystemConfig config = systemConfigService.getOperational();
        double maxCosineDistance = orDefault(config.faceMaxCosineDistance(), DEFAULT_MAX_COSINE_DISTANCE);
        double minDistanceGap = orDefault(config.faceMinDistanceGap(), DEFAULT_MIN_DISTANCE_GAP);
        double livenessMinScore = orDefault(config.livenessMinScore(), DEFAULT_LIVENESS_MIN_SCORE);

        long startTime = System.currentTimeMillis();
        InternalRecognitionResult aiResult;
        try {
            aiResult = aiClient.recognizeFace(
                    clipBytes,
                    challengeId,
                    instructions,
                    challenge.getModelVersion(),
                    maxCosineDistance,
                    minDistanceGap,
                    livenessMinScore
            );
        } catch (ApiException e) {
            int latency = (int) (System.currentTimeMillis() - startTime);
            recordAttempt(requestId, kioskId, null, e.getCode(), challenge.getModelVersion(), null, null, latency);
            throw e;
        }

        int latency = (int) (System.currentTimeMillis() - startTime);

        // Terminal attempt outcome: consume challenge
        challenge.setConsumedAt(OffsetDateTime.now());
        faceChallengeRepository.save(challenge);

        // Check simulated result
        if (aiResult.simulated()) {
            recordAttempt(requestId, kioskId, null, "SIMULATED_REJECTED", challenge.getModelVersion(), aiResult.cosineDistance(), aiResult.livenessScore(), latency);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "SIMULATED_RESULT_REJECTED", "Simulated face recognition cannot be used for access", true);
        }

        // Check liveness
        if (!aiResult.livenessPassed()) {
            recordAttempt(requestId, kioskId, null, "LIVENESS_FAILED", challenge.getModelVersion(), aiResult.cosineDistance(), aiResult.livenessScore(), latency);
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "LIVENESS_FAILED", "Face liveness verification failed", true);
        }

        // Check matching
        if (!aiResult.matched() || aiResult.userId() == null) {
            recordAttempt(requestId, kioskId, null, "NO_MATCH", challenge.getModelVersion(), aiResult.cosineDistance(), aiResult.livenessScore(), latency);
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "NO_MATCH", "No matching student identity found", true);
        }

        // Student identity matched
        UUID userId = aiResult.userId();
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "NO_MATCH", "Matched user not found", true));

        if (aiResult.biometricVersion() != null && user.getBiometricVersion() != null && !user.getBiometricVersion().equals(aiResult.biometricVersion())) {
            recordAttempt(requestId, kioskId, userId, "ENROLLMENT_CHANGED", challenge.getModelVersion(), aiResult.cosineDistance(), aiResult.livenessScore(), latency);
            throw new ApiException(HttpStatus.CONFLICT, "ENROLLMENT_CHANGED", "Biometric enrollment has changed since inference", true);
        }

        FaceProof proof = new FaceProof(
                user.getId(),
                challengeId,
                aiResult.cosineDistance() != null ? aiResult.cosineDistance() : 0.0,
                aiResult.livenessScore(),
                challenge.getModelVersion()
        );

        AccessCommand command = new AccessCommand(requestId, principal, null, proof);
        AccessResult result = accessService.record(command);

        recordAttempt(requestId, kioskId, userId, "MATCHED", challenge.getModelVersion(), aiResult.cosineDistance(), aiResult.livenessScore(), latency);

        return result;
    }

    private static double orDefault(Double value, double fallback) {
        return value != null ? value : fallback;
    }

    private void recordAttempt(
            UUID accessRequestId,
            UUID kioskId,
            UUID userId,
            String outcome,
            String modelVersion,
            Double cosineDistance,
            Double livenessScore,
            int latencyMs
    ) {
        try {
            RecognitionAttempt attempt = new RecognitionAttempt();
            attempt.setAccessRequestId(accessRequestId);
            attempt.setKioskId(kioskId);
            attempt.setUserId(userId);
            attempt.setOutcome(outcome);
            attempt.setModelVersion(modelVersion != null ? modelVersion : "arcface-512-v1");
            attempt.setCosineDistance(cosineDistance);
            attempt.setLivenessScore(livenessScore);
            attempt.setLatencyMs(latencyMs);
            attempt.setOccurredAt(OffsetDateTime.now());
            recognitionAttemptRepository.save(attempt);
        } catch (Exception e) {
            log.error("Failed recording recognition attempt: {}", e.getMessage(), e);
        }
    }

    private boolean isValidMp4Container(byte[] bytes) {
        if (bytes == null || bytes.length < 8) {
            return false;
        }
        // Check for ftyp at offset 4
        return bytes[4] == 'f' && bytes[5] == 't' && bytes[6] == 'y' && bytes[7] == 'p';
    }
}
