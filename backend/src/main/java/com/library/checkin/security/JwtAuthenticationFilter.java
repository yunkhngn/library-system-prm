package com.library.checkin.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiError;
import com.library.checkin.repository.RefreshTokenRepository;
import com.library.checkin.repository.UserRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final ObjectMapper objectMapper;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String authHeader = request.getHeader("Authorization");
        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7).trim();
        Claims claims;
        try {
            claims = jwtService.parseAndValidateToken(token);
        } catch (Exception e) {
            sendError(response, HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Invalid or expired token");
            return;
        }

        String purpose = claims.get("purpose", String.class);
        if (!JwtService.PURPOSE_ACCESS.equals(purpose)) {
            // Could be KIOSK token in Task 4, let other filters inspect or reject if destined for user endpoints
            if (JwtService.PURPOSE_KIOSK.equals(purpose)) {
                filterChain.doFilter(request, response);
                return;
            }
            sendError(response, HttpStatus.FORBIDDEN, "INVALID_TOKEN_PURPOSE", "Token purpose must be ACCESS");
            return;
        }

        String sub = claims.getSubject();
        UUID userId;
        try {
            userId = UUID.fromString(sub);
        } catch (Exception e) {
            sendError(response, HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Invalid token subject");
            return;
        }

        Optional<User> userOpt = userRepository.findById(userId);
        if (userOpt.isEmpty()) {
            sendError(response, HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "User not found");
            return;
        }

        User user = userOpt.get();
        if ("LOCKED".equalsIgnoreCase(user.getStatus())) {
            sendError(response, HttpStatus.FORBIDDEN, "ACCOUNT_LOCKED", "Account is locked");
            return;
        }

        Long tokenAuthVersion = claims.get("authVersion", Long.class);
        if (tokenAuthVersion == null || !tokenAuthVersion.equals(user.getAuthVersion())) {
            sendError(response, HttpStatus.UNAUTHORIZED, "TOKEN_REVOKED", "Token has been revoked due to credential changes");
            return;
        }

        // Handle forced password change restriction
        if (user.isMustChangePassword()) {
            String path = request.getRequestURI();
            String method = request.getMethod();
            boolean isAllowed = (path.equals("/api/v1/me") && "GET".equalsIgnoreCase(method)) ||
                                (path.equals("/api/v1/me/password") && "PUT".equalsIgnoreCase(method)) ||
                                (path.equals("/api/v1/auth/logout") && "POST".equalsIgnoreCase(method));
            if (!isAllowed) {
                sendError(response, HttpStatus.FORBIDDEN, "PASSWORD_CHANGE_REQUIRED", "Password change is required before accessing this resource");
                return;
            }
        }

        String sid = claims.get("sid", String.class);
        UUID familyId = sid != null ? UUID.fromString(sid) : null;
        boolean isLogoutEndpoint = "/api/v1/auth/logout".equals(request.getRequestURI());
        if (!isLogoutEndpoint && familyId != null && !refreshTokenRepository.existsByFamilyIdAndRevokedAtIsNull(familyId)) {
            sendError(response, HttpStatus.UNAUTHORIZED, "TOKEN_REVOKED", "Session has been logged out or revoked");
            return;
        }

        CurrentPrincipal principal = new CurrentPrincipal(
                PrincipalType.USER,
                user.getId(),
                familyId,
                user.getAuthVersion(),
                null,
                user.getRole(),
                user.getCode()
        );

        UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                principal,
                null,
                List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole()))
        );

        SecurityContextHolder.getContext().setAuthentication(authentication);
        filterChain.doFilter(request, response);
    }

    private void sendError(HttpServletResponse response, HttpStatus status, String code, String message) throws IOException {
        response.setStatus(status.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        ApiError error = new ApiError(code, message, List.of(), UUID.randomUUID().toString(), OffsetDateTime.now(), false);
        response.getWriter().write(objectMapper.writeValueAsString(error));
    }
}
