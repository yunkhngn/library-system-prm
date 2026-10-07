package com.library.checkin.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record FaceConsent(
        UUID id,
        String policyVersion,
        OffsetDateTime grantedAt,
        OffsetDateTime revokedAt,
        long version
) {}
