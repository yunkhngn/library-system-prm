package com.library.checkin.service;

import com.library.checkin.dto.QrToken;
import com.library.checkin.entity.QrGrant;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.QrGrantRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;

@Service
@RequiredArgsConstructor
public class QrService {

    private final QrGrantRepository qrGrantRepository;
    private final UserRepository userRepository;
    private final JwtService jwtService;

    @Transactional
    public QrToken issueMyQr(CurrentPrincipal principal) {
        if (!principal.isStudent()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Only students can generate QR access tokens");
        }

        User user = userRepository.findById(principal.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));

        if (!"ACTIVE".equalsIgnoreCase(user.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Account is locked");
        }

        String rawNonce = jwtService.generateRawRefreshToken();
        String nonceHash = jwtService.hashToken(rawNonce);

        OffsetDateTime now = OffsetDateTime.now();
        OffsetDateTime expiresAt = now.plusSeconds(JwtService.QR_TOKEN_VALIDITY_SECONDS);

        QrGrant grant = new QrGrant();
        grant.setUser(user);
        grant.setNonceHash(nonceHash);
        grant.setExpiresAt(expiresAt);
        qrGrantRepository.save(grant);

        String qrToken = jwtService.generateQrToken(user, rawNonce);
        return new QrToken(qrToken, expiresAt, 25L);
    }
}
