package com.library.checkin.service.strategy;

import java.util.UUID;

public record QrProof(
        String token,
        UUID userId,
        String nonceHash
) implements IdentityProof {

    @Override
    public AccessMethod method() {
        return AccessMethod.QR;
    }

    @Override
    public UUID subjectId() {
        return userId;
    }
}
