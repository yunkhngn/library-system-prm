package com.library.checkin.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.entity.Kiosk;
import com.library.checkin.exception.ApiError;
import com.library.checkin.repository.KioskRepository;
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
public class KioskAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final KioskRepository kioskRepository;
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
            // Let other filter or authenticationEntryPoint handle invalid/expired tokens
            filterChain.doFilter(request, response);
            return;
        }

        String purpose = claims.get("purpose", String.class);
        if (!JwtService.PURPOSE_KIOSK.equals(purpose)) {
            // Not a KIOSK token, proceed to next filter (e.g. JwtAuthenticationFilter for users)
            filterChain.doFilter(request, response);
            return;
        }

        String kioskIdStr = claims.get("kioskId", String.class);
        if (kioskIdStr == null) {
            kioskIdStr = claims.getSubject();
        }

        UUID kioskId;
        try {
            kioskId = UUID.fromString(kioskIdStr);
        } catch (Exception e) {
            sendError(response, HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Invalid kiosk token subject");
            return;
        }

        Optional<Kiosk> kioskOpt = kioskRepository.findById(kioskId);
        if (kioskOpt.isEmpty() || !"ACTIVE".equalsIgnoreCase(kioskOpt.get().getStatus())) {
            sendError(response, HttpStatus.FORBIDDEN, "KIOSK_REVOKED", "Kiosk is revoked or not found");
            return;
        }

        Kiosk kiosk = kioskOpt.get();
        Long tokenCredVersion = claims.get("credentialVersion", Long.class);
        if (tokenCredVersion == null || !tokenCredVersion.equals(kiosk.getCredentialVersion())) {
            sendError(response, HttpStatus.UNAUTHORIZED, "TOKEN_REVOKED", "Kiosk credential has been rotated");
            return;
        }

        CurrentPrincipal principal = new CurrentPrincipal(
                PrincipalType.KIOSK,
                kiosk.getId(),
                null,
                null,
                kiosk.getCredentialVersion(),
                "KIOSK",
                kiosk.getCode()
        );

        UsernamePasswordAuthenticationToken authentication = new UsernamePasswordAuthenticationToken(
                principal,
                null,
                List.of(new SimpleGrantedAuthority("ROLE_KIOSK"))
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
