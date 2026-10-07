package com.library.checkin.service.strategy;

import com.library.checkin.security.CurrentPrincipal;

import java.util.UUID;

public record AccessCommand(
        UUID requestId,
        CurrentPrincipal principal,
        AccessAction action,
        IdentityProof proof
) {}
