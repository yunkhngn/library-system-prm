package com.library.checkin.security;

import java.util.UUID;

public record CurrentPrincipal(
        PrincipalType type,
        UUID id,
        UUID familyId,
        Long authVersion,
        Long credentialVersion,
        String role,
        String code
) {
    public boolean isUser() {
        return type == PrincipalType.USER;
    }

    public boolean isKiosk() {
        return type == PrincipalType.KIOSK;
    }

    public boolean isAdmin() {
        return isUser() && "ADMIN".equalsIgnoreCase(role);
    }

    public boolean isLibrarian() {
        return isUser() && "LIBRARIAN".equalsIgnoreCase(role);
    }

    public boolean isStaff() {
        return isAdmin() || isLibrarian();
    }

    public boolean isStudent() {
        return isUser() && "STUDENT".equalsIgnoreCase(role);
    }
}
