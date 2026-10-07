package com.library.checkin.service.strategy;

import com.library.checkin.dto.QrAccessRequest;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.JwtService;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class QrCheckInStrategy implements CheckInStrategy<QrAccessRequest> {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    @Override
    public AccessMethod method() {
        return AccessMethod.QR;
    }

    @Override
    public IdentityProof authenticate(QrAccessRequest input) {
        if (input == null || input.token() == null || input.token().isBlank()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Token cannot be empty");
        }

        Claims claims;
        try {
            claims = jwtService.parseAndValidateToken(input.token());
        } catch (ExpiredJwtException e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_EXPIRED", "QR token has expired");
        } catch (Exception e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Invalid QR token format or signature");
        }

        String purpose = claims.get("purpose", String.class);
        if (!JwtService.PURPOSE_QR.equals(purpose)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Token purpose is not QR_ACCESS");
        }

        String userIdStr = claims.getSubject();
        UUID userId;
        try {
            userId = UUID.fromString(userIdStr);
        } catch (Exception e) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Invalid user ID in QR token");
        }

        var user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "User not found"));

        if (!"ACTIVE".equalsIgnoreCase(user.getStatus())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "User account is not ACTIVE");
        }

        if (!"STUDENT".equalsIgnoreCase(user.getRole())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Only students may use QR access");
        }

        String nonce = claims.get("nonce", String.class);
        if (nonce == null || nonce.isBlank()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "QR_INVALID", "Missing nonce in QR token");
        }

        String nonceHash = sha256Hex(nonce);
        return new QrProof(input.token(), userId, nonceHash);
    }

    private String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash);
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 unavailable", e);
        }
    }
}
