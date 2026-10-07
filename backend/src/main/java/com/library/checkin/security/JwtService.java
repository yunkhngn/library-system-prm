package com.library.checkin.security;

import com.library.checkin.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.UUID;

@Service
public class JwtService {

    public static final String AUDIENCE = "library-app";
    public static final String PURPOSE_ACCESS = "ACCESS";
    public static final String PURPOSE_QR = "QR_ACCESS";
    public static final String PURPOSE_KIOSK = "KIOSK";
    public static final long ACCESS_TOKEN_VALIDITY_SECONDS = 900; // 15 minutes

    private final SecretKey signingKey;
    private final SecureRandom secureRandom = new SecureRandom();

    public JwtService(@Value("${app.jwt.secret}") String secret) {
        byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
        if (keyBytes.length < 32) {
            byte[] padded = new byte[32];
            System.arraycopy(keyBytes, 0, padded, 0, keyBytes.length);
            keyBytes = padded;
        }
        this.signingKey = Keys.hmacShaKeyFor(keyBytes);
    }

    public String generateAccessToken(User user, UUID familyId) {
        Instant now = Instant.now();
        Instant expiry = now.plus(Duration.ofSeconds(ACCESS_TOKEN_VALIDITY_SECONDS));

        return Jwts.builder()
                .subject(user.getId().toString())
                .audience().add(AUDIENCE).and()
                .issuedAt(Date.from(now))
                .expiration(Date.from(expiry))
                .claim("purpose", PURPOSE_ACCESS)
                .claim("sid", familyId.toString())
                .claim("authVersion", user.getAuthVersion())
                .claim("role", user.getRole())
                .claim("code", user.getCode())
                .claim("mustChangePassword", user.isMustChangePassword())
                .signWith(signingKey)
                .compact();
    }

    public Claims parseAndValidateToken(String token) {
        return Jwts.parser()
                .verifyWith(signingKey)
                .build()
                .parseSignedClaims(token)
                .getPayload();
    }

    public String generateRawRefreshToken() {
        byte[] randomBytes = new byte[32];
        secureRandom.nextBytes(randomBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
    }

    public String hashToken(String rawToken) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(rawToken.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) hexString.append('0');
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new RuntimeException("SHA-256 algorithm missing", e);
        }
    }
}
