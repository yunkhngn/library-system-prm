package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

public record FaceChallenge(
        UUID challengeId,
        OffsetDateTime expiresAt,
        List<ChallengeInstruction> instructions,
        FaceCaptureRules captureRules
) {}
