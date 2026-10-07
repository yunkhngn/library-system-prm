package com.library.checkin.controller;

import com.library.checkin.dto.ChangePasswordRequest;
import com.library.checkin.dto.LoginRequest;
import com.library.checkin.dto.RefreshTokenRequest;
import com.library.checkin.dto.TokenPair;
import com.library.checkin.dto.UserDto;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.AuthService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1")
@RequiredArgsConstructor
public class AuthController {

    private final AuthService authService;
    private final com.library.checkin.service.QrService qrService;

    @Tag(name = "Auth")
    @Operation(summary = "login", operationId = "login")
    @PostMapping("/auth/login")
    public ResponseEntity<TokenPair> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(authService.login(req));
    }

    @Tag(name = "Auth")
    @Operation(summary = "refreshTokens", operationId = "refreshTokens")
    @PostMapping("/auth/refresh")
    public ResponseEntity<TokenPair> refresh(@Valid @RequestBody RefreshTokenRequest req) {
        return ResponseEntity.ok(authService.refresh(req));
    }

    @Tag(name = "Auth")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "logout", operationId = "logout")
    @PostMapping("/auth/logout")
    public ResponseEntity<Void> logout(@AuthenticationPrincipal CurrentPrincipal principal,
                                       @Valid @RequestBody RefreshTokenRequest req) {
        authService.logout(principal, req);
        return ResponseEntity.noContent().build();
    }

    @Tag(name = "Profile")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "getMyProfile", operationId = "getMyProfile")
    @GetMapping("/me")
    public ResponseEntity<UserDto> getMyProfile(@AuthenticationPrincipal CurrentPrincipal principal) {
        return ResponseEntity.ok(authService.getMyProfile(principal));
    }

    @Tag(name = "Profile")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "changeMyPassword", operationId = "changeMyPassword")
    @PutMapping("/me/password")
    public ResponseEntity<TokenPair> changeMyPassword(@AuthenticationPrincipal CurrentPrincipal principal,
                                                      @Valid @RequestBody ChangePasswordRequest req) {
        return ResponseEntity.ok(authService.changePassword(principal, req));
    }

    @Tag(name = "Student")
    @SecurityRequirement(name = "bearerAuth")
    @Operation(summary = "issueMyQr", operationId = "issueMyQr")
    @PostMapping("/me/qr")
    public ResponseEntity<com.library.checkin.dto.QrToken> issueMyQr(
            @AuthenticationPrincipal CurrentPrincipal principal) {
        return ResponseEntity.ok(qrService.issueMyQr(principal));
    }
}
