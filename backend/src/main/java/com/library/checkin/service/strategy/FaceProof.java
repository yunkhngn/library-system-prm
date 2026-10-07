package com.library.checkin.service.strategy;

import java.util.UUID;

public record FaceProof(
        UUID userId,
        UUID challengeId,
        double cosineDistance,
        double livenessScore,
        String modelVersion
) implements IdentityProof {

    @Override
    public AccessMethod method() {
        return AccessMethod.FACE;
    }

    @Override
    public UUID subjectId() {
        return userId;
    }
}
