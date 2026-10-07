package com.library.checkin.service.strategy;

import java.util.UUID;

public interface IdentityProof {
    AccessMethod method();
    UUID subjectId();
}
