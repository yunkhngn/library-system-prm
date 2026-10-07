package com.library.checkin.config;

import com.library.checkin.entity.User;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.security.JwtService;
import com.library.checkin.security.PrincipalType;
import io.jsonwebtoken.Claims;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

import java.security.Principal;
import java.util.List;
import java.util.UUID;

@Slf4j
@Configuration
@EnableWebSocketMessageBroker
@Order(Ordered.HIGHEST_PRECEDENCE + 99)
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {

    private final JwtService jwtService;
    private final UserRepository userRepository;

    @Override
    public void registerStompEndpoints(StompEndpointRegistry registry) {
        // Native WebSocket, no SockJS, allowed origins *
        registry.addEndpoint("/ws")
                .setAllowedOriginPatterns("*");
    }

    @Override
    public void configureMessageBroker(MessageBrokerRegistry registry) {
        registry.enableSimpleBroker("/topic");
        registry.setApplicationDestinationPrefixes("/app");
    }

    @Override
    public void configureClientInboundChannel(ChannelRegistration registration) {
        registration.interceptors(new ChannelInterceptor() {
            @Override
            public Message<?> preSend(Message<?> message, MessageChannel channel) {
                StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
                if (accessor == null) {
                    return message;
                }

                if (StompCommand.CONNECT.equals(accessor.getCommand())) {
                    List<String> authHeaders = accessor.getNativeHeader("Authorization");
                    if (authHeaders == null || authHeaders.isEmpty()) {
                        throw new BadCredentialsException("UNAUTHENTICATED: missing Authorization header");
                    }
                    String authHeader = authHeaders.get(0);
                    if (!authHeader.startsWith("Bearer ")) {
                        throw new BadCredentialsException("UNAUTHENTICATED: missing Bearer prefix");
                    }
                    String token = authHeader.substring(7).trim();

                    Claims claims;
                    try {
                        claims = jwtService.parseAndValidateToken(token);
                    } catch (Exception e) {
                        throw new BadCredentialsException("UNAUTHENTICATED: invalid token", e);
                    }

                    String purpose = claims.get("purpose", String.class);
                    if (purpose != null && !"ACCESS".equalsIgnoreCase(purpose)) {
                        throw new AccessDeniedException("INVALID_TOKEN_PURPOSE: realtime requires access token");
                    }

                    String role = claims.get("role", String.class);
                    if (!"LIBRARIAN".equalsIgnoreCase(role) && !"ADMIN".equalsIgnoreCase(role)) {
                        throw new AccessDeniedException("FORBIDDEN: Only LIBRARIAN or ADMIN may connect to realtime feed");
                    }

                    String userIdStr = claims.getSubject();
                    UUID userId = UUID.fromString(userIdStr);
                    User user = userRepository.findById(userId).orElse(null);
                    if (user == null || !"ACTIVE".equalsIgnoreCase(user.getStatus())) {
                        throw new AccessDeniedException("ACCOUNT_LOCKED: User account is not active");
                    }

                    Number authVerNum = claims.get("authVersion", Number.class);
                    long tokenAuthVersion = authVerNum != null ? authVerNum.longValue() : 0L;
                    if (user.getAuthVersion() > tokenAuthVersion) {
                        throw new BadCredentialsException("TOKEN_REVOKED: Token has been revoked");
                    }

                    UUID sid = claims.get("sid", String.class) != null ? UUID.fromString(claims.get("sid", String.class)) : null;
                    CurrentPrincipal principal = new CurrentPrincipal(
                            PrincipalType.USER,
                            user.getId(),
                            sid,
                            tokenAuthVersion,
                            null,
                            user.getRole(),
                            user.getCode()
                    );
                    Authentication auth = new UsernamePasswordAuthenticationToken(
                            principal,
                            null,
                            List.of(new SimpleGrantedAuthority("ROLE_" + user.getRole()))
                    );
                    if (accessor.getSessionAttributes() != null) {
                        accessor.getSessionAttributes().put("AUTH", auth);
                    }
                    accessor.setUser(auth);
                    log.info("WebSocket STOMP connected for user: {} ({})", user.getCode(), user.getRole());
                } else if (StompCommand.SUBSCRIBE.equals(accessor.getCommand())) {
                    Principal p = accessor.getUser();
                    if (p == null && accessor.getSessionAttributes() != null) {
                        p = (Principal) accessor.getSessionAttributes().get("AUTH");
                        if (p instanceof Authentication auth) {
                            accessor.setUser(auth);
                        }
                    }
                    if (!(p instanceof Authentication auth) || !auth.isAuthenticated()) {
                        throw new AccessDeniedException("UNAUTHENTICATED: Subscription requires authentication");
                    }
                    String destination = accessor.getDestination();
                    if (destination != null && destination.startsWith("/topic/occupancy")) {
                        boolean hasRole = auth.getAuthorities().stream().anyMatch(a ->
                                a.getAuthority().equals("ROLE_LIBRARIAN") || a.getAuthority().equals("ROLE_ADMIN"));
                        if (!hasRole) {
                            throw new AccessDeniedException("FORBIDDEN: Only LIBRARIAN or ADMIN may subscribe to occupancy");
                        }
                    }
                } else if (StompCommand.SEND.equals(accessor.getCommand())) {
                    // Clients cannot send messages to broker/app destinations
                    throw new AccessDeniedException("FORBIDDEN: Client SEND is blocked; push only");
                }

                return message;
            }
        });
    }
}
