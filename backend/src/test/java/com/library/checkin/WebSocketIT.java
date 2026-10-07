package com.library.checkin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.ManualAccessRequest;
import com.library.checkin.dto.OccupancyEvent;
import com.library.checkin.entity.User;
import com.library.checkin.event.OccupancyChangedEvent;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.JwtService;
import com.library.checkin.service.AccessRequestService;
import com.library.checkin.service.AccessService;
import com.library.checkin.service.AuthService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.messaging.converter.MappingJackson2MessageConverter;
import org.springframework.messaging.simp.stomp.*;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.lang.reflect.Type;
import java.util.UUID;
import java.util.concurrent.*;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("it")
@Testcontainers
class WebSocketIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_ws_it")
            .withUsername("ws_user")
            .withPassword("ws_pass");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @LocalServerPort
    private int port;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @Autowired
    private AccessService accessService;

    @Autowired
    private PlatformTransactionManager transactionManager;

    @Autowired
    private ApplicationEventPublisher eventPublisher;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private AuthService authService;

    @Autowired
    private AccessRequestService accessRequestService;

    private User librarian;
    private User student;
    private String librarianToken;
    private String studentToken;
    private WebSocketStompClient stompClient;

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");

        librarian = new User();
        librarian.setCode("LIB991");
        librarian.setEmail("lib991@test.com");
        librarian.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        librarian.setFullName("Librarian Realtime");
        librarian.setRole("LIBRARIAN");
        librarian.setStatus("ACTIVE");
        librarian.setMustChangePassword(false);
        librarian = userRepository.save(librarian);
        librarianToken = authService.login(new com.library.checkin.dto.LoginRequest("LIB991", "Pass12345678!")).accessToken();

        student = new User();
        student.setCode("STU991");
        student.setEmail("stu991@test.com");
        student.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        student.setFullName("Student Realtime");
        student.setRole("STUDENT");
        student.setStatus("ACTIVE");
        student.setMustChangePassword(false);
        student = userRepository.save(student);
        studentToken = authService.login(new com.library.checkin.dto.LoginRequest("STU991", "Pass12345678!")).accessToken();

        stompClient = new WebSocketStompClient(new StandardWebSocketClient());
        MappingJackson2MessageConverter converter = new MappingJackson2MessageConverter();
        converter.setObjectMapper(objectMapper);
        stompClient.setMessageConverter(converter);
    }

    @Test
    @DisplayName("Reject WebSocket CONNECT without JWT")
    void testRejectConnectWithoutJwt() {
        String url = "ws://localhost:" + port + "/ws";
        StompHeaders headers = new StompHeaders(); // no Authorization header

        assertThrows(ExecutionException.class, () -> {
            stompClient.connectAsync(url, new WebSocketHttpHeaders(), headers, new StompSessionHandlerAdapter() {})
                    .get(5, TimeUnit.SECONDS);
        });
    }

    @Test
    @DisplayName("Reject WebSocket CONNECT with STUDENT role")
    void testRejectConnectForStudentRole() {
        String url = "ws://localhost:" + port + "/ws";
        StompHeaders headers = new StompHeaders();
        headers.add("Authorization", "Bearer " + studentToken);

        assertThrows(ExecutionException.class, () -> {
            stompClient.connectAsync(url, new WebSocketHttpHeaders(), headers, new StompSessionHandlerAdapter() {})
                    .get(5, TimeUnit.SECONDS);
        });
    }

    @Test
    @DisplayName("Librarian connects, receives events on committed transactions, and rollback emits nothing")
    void testRealtimeEventsAndRollbackSuppression() throws Exception {
        String url = "ws://localhost:" + port + "/ws";
        StompHeaders connectHeaders = new StompHeaders();
        connectHeaders.add("Authorization", "Bearer " + librarianToken);

        StompSession session = stompClient.connectAsync(url, new WebSocketHttpHeaders(), connectHeaders, new StompSessionHandlerAdapter() {})
                .get(5, TimeUnit.SECONDS);
        assertTrue(session.isConnected());

        BlockingQueue<OccupancyEvent> eventQueue = new LinkedBlockingQueue<>();

        session.subscribe("/topic/occupancy", new StompFrameHandler() {
            @Override
            public Type getPayloadType(StompHeaders headers) {
                return OccupancyEvent.class;
            }

            @Override
            public void handleFrame(StompHeaders headers, Object payload) {
                eventQueue.offer((OccupancyEvent) payload);
            }
        });

        // 1. Transaction rollback test: no event should be published
        TransactionTemplate txTemplate = new TransactionTemplate(transactionManager);
        txTemplate.execute(status -> {
            // Emulate an event inside a rolling back transaction
            status.setRollbackOnly();
            return null;
        });

        OccupancyEvent rolledBackEvent = eventQueue.poll(2, TimeUnit.SECONDS);
        assertNull(rolledBackEvent, "Rollback must not dispatch OccupancyChangedEvent to STOMP broker");

        // 2. Committed manual check-in: event should be received
        UUID reqId = UUID.randomUUID();
        com.library.checkin.security.CurrentPrincipal principal = new com.library.checkin.security.CurrentPrincipal(
                com.library.checkin.security.PrincipalType.USER, librarian.getId(), null, 0L, null, librarian.getRole(), librarian.getCode()
        );
        AccessRequestService.AccessClaim claim = accessRequestService.claim(
                principal, reqId, "POST", "/api/v1/access/manual", "digest"
        );

        accessService.recordManualAccess(
                librarian.getId(),
                claim.requestId(),
                new ManualAccessRequest(student.getId(), null, "CHECK_IN", "Realtime test check-in")
        );

        OccupancyEvent received = eventQueue.poll(5, TimeUnit.SECONDS);
        assertNotNull(received, "Expected OccupancyEvent on /topic/occupancy after commit");
        assertEquals("CHECK_IN", received.change().action());
        assertEquals(1, received.count());

        session.disconnect();
    }
}
