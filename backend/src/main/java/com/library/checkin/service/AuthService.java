package com.library.checkin.service;

import com.library.checkin.dto.*;
import com.library.checkin.entity.RefreshToken;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.RefreshTokenRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final JwtService jwtService;
    private final PasswordEncoder passwordEncoder;

    @Transactional
    public TokenPair login(LoginRequest req) {
        String identifier = req.identifier().trim();
        Optional<User> userOpt = userRepository.findByCode(identifier.toUpperCase())
                .or(() -> userRepository.findByEmail(identifier.toLowerCase()));

        if (userOpt.isEmpty() || !passwordEncoder.matches(req.password(), userOpt.get().getPasswordHash())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Invalid credentials");
        }

        User user = userOpt.get();
        if ("LOCKED".equalsIgnoreCase(user.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Account is locked");
        }

        UUID familyId = UUID.randomUUID();
        String rawRefreshToken = jwtService.generateRawRefreshToken();

        RefreshToken rt = new RefreshToken();
        rt.setUser(user);
        rt.setTokenHash(jwtService.hashToken(rawRefreshToken));
        rt.setFamilyId(familyId);
        rt.setExpiresAt(OffsetDateTime.now().plusDays(7));
        refreshTokenRepository.save(rt);

        String accessToken = jwtService.generateAccessToken(user, familyId);
        return new TokenPair(accessToken, rawRefreshToken, "Bearer", JwtService.ACCESS_TOKEN_VALIDITY_SECONDS, toUserDto(user));
    }

    @Transactional(noRollbackFor = ApiException.class)
    public TokenPair refresh(RefreshTokenRequest req) {
        String rawToken = req.refreshToken();
        String tokenHash = jwtService.hashToken(rawToken);

        RefreshToken rt = refreshTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_REFRESH_TOKEN", "Invalid refresh token"));

        if (rt.isExpired()) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_EXPIRED", "Refresh token is expired");
        }

        if (rt.isRevoked()) {
            // Replay attack detection: revoke entire family immediately
            refreshTokenRepository.revokeFamily(rt.getFamilyId(), OffsetDateTime.now());
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_REVOKED", "Refresh token has been revoked");
        }

        User user = rt.getUser();
        if ("LOCKED".equalsIgnoreCase(user.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Account is locked");
        }

        String newRawRefreshToken = jwtService.generateRawRefreshToken();
        RefreshToken newRt = new RefreshToken();
        newRt.setUser(user);
        newRt.setTokenHash(jwtService.hashToken(newRawRefreshToken));
        newRt.setFamilyId(rt.getFamilyId());
        newRt.setExpiresAt(rt.getExpiresAt());
        newRt = refreshTokenRepository.save(newRt);

        rt.setRevokedAt(OffsetDateTime.now());
        rt.setReplacedBy(newRt.getId());
        refreshTokenRepository.save(rt);

        String accessToken = jwtService.generateAccessToken(user, rt.getFamilyId());
        return new TokenPair(accessToken, newRawRefreshToken, "Bearer", JwtService.ACCESS_TOKEN_VALIDITY_SECONDS, toUserDto(user));
    }

    @Transactional
    public void logout(CurrentPrincipal principal, RefreshTokenRequest req) {
        String tokenHash = jwtService.hashToken(req.refreshToken());
        RefreshToken rt = refreshTokenRepository.findByTokenHash(tokenHash)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Refresh token not found"));

        if (!rt.getUser().getId().equals(principal.id())) {
            throw new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Refresh token does not belong to user");
        }

        if (rt.isRevoked()) {
            return; // 204 No Content for already revoked tokens
        }

        refreshTokenRepository.revokeFamily(rt.getFamilyId(), OffsetDateTime.now());
    }

    @Transactional(readOnly = true)
    public UserDto getMyProfile(CurrentPrincipal principal) {
        User user = userRepository.findById(principal.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));
        return toUserDto(user);
    }

    @Transactional
    public TokenPair changePassword(CurrentPrincipal principal, ChangePasswordRequest req) {
        User user = userRepository.findById(principal.id())
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));

        if ("LOCKED".equalsIgnoreCase(user.getStatus())) {
            throw new ApiException(HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Account is locked");
        }

        if (!passwordEncoder.matches(req.currentPassword(), user.getPasswordHash())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "CURRENT_PASSWORD_INVALID", "Current password does not match");
        }

        if (passwordEncoder.matches(req.newPassword(), user.getPasswordHash())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "PASSWORD_UNCHANGED", "New password must differ from current password");
        }

        if (req.newPassword().getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Password exceeds 72 UTF-8 bytes");
        }

        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        user.setMustChangePassword(false);
        user.setAuthVersion(user.getAuthVersion() + 1);
        userRepository.save(user);

        refreshTokenRepository.revokeAllForUser(user.getId(), OffsetDateTime.now());

        UUID newFamilyId = UUID.randomUUID();
        String newRawRefreshToken = jwtService.generateRawRefreshToken();
        RefreshToken newRt = new RefreshToken();
        newRt.setUser(user);
        newRt.setTokenHash(jwtService.hashToken(newRawRefreshToken));
        newRt.setFamilyId(newFamilyId);
        newRt.setExpiresAt(OffsetDateTime.now().plusDays(7));
        refreshTokenRepository.save(newRt);

        String accessToken = jwtService.generateAccessToken(user, newFamilyId);
        return new TokenPair(accessToken, newRawRefreshToken, "Bearer", JwtService.ACCESS_TOKEN_VALIDITY_SECONDS, toUserDto(user));
    }

    public UserDto toUserDto(User user) {
        boolean faceEnrolled = userRepository.hasEnrolledFace(user.getId());
        return new UserDto(
                user.getId(),
                user.getCode(),
                user.getEmail(),
                user.getFullName(),
                user.getRole(),
                user.getStatus(),
                user.isMustChangePassword(),
                faceEnrolled,
                user.getVersion(),
                user.getCreatedAt(),
                user.getUpdatedAt()
        );
    }
}
