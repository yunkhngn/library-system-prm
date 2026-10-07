package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
import com.library.checkin.entity.Kiosk;
import com.library.checkin.entity.User;
import com.library.checkin.repository.KioskRepository;
import com.library.checkin.repository.QrGrantRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.OffsetDateTime;
import java.util.UUID;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class AccessConcurrencyIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_access_it")
            .withUsername("access_user")
            .withPassword("access_pass");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private KioskRepository kioskRepository;

    @Autowired
    private QrGrantRepository qrGrantRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM qr_grants");
        jdbcTemplate.execute("DELETE FROM kiosks");
        jdbcTemplate.execute("DELETE FROM users");
        jdbcTemplate.execute("UPDATE library_state SET occupancy_revision = 0 WHERE id = 1");
    }

    private User createStudent(String code, String email) {
        User u = new User();
        u.setCode(code);
        u.setEmail(email);
        u.setFullName("Student " + code);
        u.setRole("STUDENT");
        u.setStatus("ACTIVE");
        u.setPasswordHash(passwordEncoder.encode("password123"));
        u.setMustChangePassword(false);
        u.setAuthVersion(1L);
        return userRepository.save(u);
    }

    private Kiosk createKiosk(String code, String mode) {
        Kiosk k = new Kiosk();
        k.setCode(code);
        k.setName("Kiosk " + code);
        k.setMode(mode);
        k.setStatus("ACTIVE");
        k.setCredentialHash(passwordEncoder.encode("secret-kiosk"));
        k.setCredentialVersion(1L);
        k.setLastSeenAt(OffsetDateTime.now());
        return kioskRepository.save(k);
    }

    private String loginUser(String identifier) throws Exception {
        LoginRequest req = new LoginRequest(identifier, "password123");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();
    }

    private String issueQr(User student) throws Exception {
        String studentToken = loginUser(student.getCode());
        MvcResult res = mockMvc.perform(post("/api/v1/me/qr")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode json = objectMapper.readTree(res.getResponse().getContentAsString());
        return json.get("token").asText();
    }

    @Test
    @DisplayName("AUTO kiosk: Entry then Exit flow with session toggle")
    void entryAndExitFlow() throws Exception {
        User student = createStudent("STU001", "stu1@library.local");
        Kiosk kiosk = createKiosk("KIOSK-01", "AUTO");
        String kioskToken = jwtService.generateKioskToken(kiosk);

        String qr1 = issueQr(student);
        UUID key1 = UUID.randomUUID();

        // 1. Check in
        MvcResult checkinRes = mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", key1.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr1))))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode checkinJson = objectMapper.readTree(checkinRes.getResponse().getContentAsString());
        assertEquals("CHECK_IN", checkinJson.get("action").asText());
        assertEquals("STU001", checkinJson.get("subject").get("code").asText());
        assertEquals(1, checkinJson.get("occupancy").get("count").asLong());
        assertEquals(1, checkinJson.get("occupancy").get("revision").asLong());

        // Fast forward check_in_time to bypass scan cooldown
        jdbcTemplate.execute("UPDATE checkin_logs SET check_in_time = check_in_time - INTERVAL '15 seconds'");

        // 2. Check out
        String qr2 = issueQr(student);
        UUID key2 = UUID.randomUUID();

        MvcResult checkoutRes = mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", key2.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr2))))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode checkoutJson = objectMapper.readTree(checkoutRes.getResponse().getContentAsString());
        assertEquals("CHECK_OUT", checkoutJson.get("action").asText());
        assertEquals(0, checkoutJson.get("occupancy").get("count").asLong());
        assertEquals(2, checkoutJson.get("occupancy").get("revision").asLong());
    }

    @Test
    @DisplayName("Idempotency: Retry with same key returns stored response and does not toggle")
    void retryDoesNotToggle() throws Exception {
        User student = createStudent("STU002", "stu2@library.local");
        Kiosk kiosk = createKiosk("KIOSK-02", "AUTO");
        String kioskToken = jwtService.generateKioskToken(kiosk);

        String qr = issueQr(student);
        UUID key = UUID.randomUUID();

        MvcResult first = mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", key.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr))))
                .andExpect(status().isOk())
                .andReturn();

        MvcResult second = mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", key.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr))))
                .andExpect(status().isOk())
                .andReturn();

        assertEquals(objectMapper.readTree(first.getResponse().getContentAsString()),
                     objectMapper.readTree(second.getResponse().getContentAsString()));
        JsonNode json = objectMapper.readTree(second.getResponse().getContentAsString());
        assertEquals("CHECK_IN", json.get("action").asText());
        assertEquals(1, json.get("occupancy").get("count").asLong());
    }

    @Test
    @DisplayName("Idempotency: Same key with different payload returns 409 IDEMPOTENCY_CONFLICT")
    void differentPayloadSameKeyConflict() throws Exception {
        User student1 = createStudent("STU003", "stu3@library.local");
        User student2 = createStudent("STU004", "stu4@library.local");
        Kiosk kiosk = createKiosk("KIOSK-03", "AUTO");
        String kioskToken = jwtService.generateKioskToken(kiosk);

        String qr1 = issueQr(student1);
        String qr2 = issueQr(student2);
        UUID key = UUID.randomUUID();

        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", key.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr1))))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", key.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr2))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("IDEMPOTENCY_CONFLICT"));
    }

    @Test
    @DisplayName("Cooldown: Different key within scanCooldownSeconds returns 409 SCAN_TOO_SOON")
    void scanTooSoonCooldown() throws Exception {
        User student = createStudent("STU005", "stu5@library.local");
        Kiosk kiosk = createKiosk("KIOSK-04", "AUTO");
        String kioskToken = jwtService.generateKioskToken(kiosk);

        String qr1 = issueQr(student);
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr1))))
                .andExpect(status().isOk());

        String qr2 = issueQr(student);
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr2))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SCAN_TOO_SOON"));
    }

    @Test
    @DisplayName("Replay protection: Consumed QR token returns 409 QR_ALREADY_USED")
    void qrAlreadyUsed() throws Exception {
        User student = createStudent("STU006", "stu6@library.local");
        Kiosk kiosk = createKiosk("KIOSK-05", "AUTO");
        String kioskToken = jwtService.generateKioskToken(kiosk);

        String qr = issueQr(student);
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr))))
                .andExpect(status().isOk());

        // Fast forward check_in_time to bypass cooldown
        jdbcTemplate.execute("UPDATE checkin_logs SET check_in_time = check_in_time - INTERVAL '20 seconds'");

        // Try reusing the same QR with a different idempotency key
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + kioskToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("QR_ALREADY_USED"));
    }

    @Test
    @DisplayName("Kiosk direction: ENTRY mode returns 409 ALREADY_INSIDE if active session exists")
    void entryModeWhenAlreadyInside() throws Exception {
        User student = createStudent("STU007", "stu7@library.local");
        Kiosk autoKiosk = createKiosk("KIOSK-AUTO", "AUTO");
        Kiosk entryKiosk = createKiosk("KIOSK-ENTRY", "ENTRY");
        String autoToken = jwtService.generateKioskToken(autoKiosk);
        String entryToken = jwtService.generateKioskToken(entryKiosk);

        // Check in via auto kiosk
        String qr1 = issueQr(student);
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + autoToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr1))))
                .andExpect(status().isOk());

        jdbcTemplate.execute("UPDATE checkin_logs SET check_in_time = check_in_time - INTERVAL '20 seconds'");

        // Try to enter again via ENTRY kiosk
        String qr2 = issueQr(student);
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + entryToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr2))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_INSIDE"));
    }

    @Test
    @DisplayName("Kiosk direction: EXIT mode returns 409 NOT_INSIDE if no active session exists")
    void exitModeWhenNotInside() throws Exception {
        User student = createStudent("STU008", "stu8@library.local");
        Kiosk exitKiosk = createKiosk("KIOSK-EXIT", "EXIT");
        String exitToken = jwtService.generateKioskToken(exitKiosk);

        String qr = issueQr(student);
        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + exitToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NOT_INSIDE"));
    }

    @Test
    @DisplayName("Request status recovery: GET /access/requests/{key} returns result and respects principal isolation")
    void requestStatusAndIsolation() throws Exception {
        User student = createStudent("STU009", "stu9@library.local");
        Kiosk kiosk1 = createKiosk("KIOSK-A", "AUTO");
        Kiosk kiosk2 = createKiosk("KIOSK-B", "AUTO");
        String token1 = jwtService.generateKioskToken(kiosk1);
        String token2 = jwtService.generateKioskToken(kiosk2);

        String qr = issueQr(student);
        UUID key = UUID.randomUUID();

        mockMvc.perform(post("/api/v1/access/qr")
                        .header("Authorization", "Bearer " + token1)
                        .header("Idempotency-Key", key.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new QrAccessRequest(qr))))
                .andExpect(status().isOk());

        // Kiosk1 retrieves status
        mockMvc.perform(get("/api/v1/access/requests/" + key)
                        .header("Authorization", "Bearer " + token1))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("COMPLETED"))
                .andExpect(jsonPath("$.httpStatus").value(200))
                .andExpect(jsonPath("$.result.action").value("CHECK_IN"));

        // Kiosk2 tries to retrieve Kiosk1's request -> 404 RESOURCE_NOT_FOUND
        mockMvc.perform(get("/api/v1/access/requests/" + key)
                        .header("Authorization", "Bearer " + token2))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));
    }

    @Test
    @DisplayName("Concurrency: Concurrent check-in requests produce only one effect")
    void concurrentKiosksProduceOnlyOneEffect() throws Exception {
        User student = createStudent("STU010", "stu10@library.local");
        Kiosk kiosk1 = createKiosk("KIOSK-C1", "AUTO");
        Kiosk kiosk2 = createKiosk("KIOSK-C2", "AUTO");
        String token1 = jwtService.generateKioskToken(kiosk1);
        String token2 = jwtService.generateKioskToken(kiosk2);

        String qr1 = issueQr(student);
        String qr2 = issueQr(student);

        ExecutorService executor = Executors.newFixedThreadPool(2);
        CyclicBarrier barrier = new CyclicBarrier(2);
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger conflictCount = new AtomicInteger(0);

        Callable<Void> task1 = () -> {
            barrier.await();
            try {
                MvcResult r = mockMvc.perform(post("/api/v1/access/qr")
                                .header("Authorization", "Bearer " + token1)
                                .header("Idempotency-Key", UUID.randomUUID().toString())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(new QrAccessRequest(qr1))))
                        .andReturn();
                if (r.getResponse().getStatus() == 200) {
                    successCount.incrementAndGet();
                } else if (r.getResponse().getStatus() == 409) {
                    conflictCount.incrementAndGet();
                }
            } catch (Exception ignored) {}
            return null;
        };

        Callable<Void> task2 = () -> {
            barrier.await();
            try {
                MvcResult r = mockMvc.perform(post("/api/v1/access/qr")
                                .header("Authorization", "Bearer " + token2)
                                .header("Idempotency-Key", UUID.randomUUID().toString())
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(new QrAccessRequest(qr2))))
                        .andReturn();
                if (r.getResponse().getStatus() == 200) {
                    successCount.incrementAndGet();
                } else if (r.getResponse().getStatus() == 409) {
                    conflictCount.incrementAndGet();
                }
            } catch (Exception ignored) {}
            return null;
        };

        Future<Void> f1 = executor.submit(task1);
        Future<Void> f2 = executor.submit(task2);
        f1.get();
        f2.get();
        executor.shutdown();

        assertEquals(1, successCount.get(), "Exactly one request should succeed");
        assertEquals(1, conflictCount.get(), "The other request should get 409 Conflict");

        // Verify database state: exactly 1 open session
        Integer count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM checkin_logs WHERE check_out_time IS NULL", Integer.class
        );
        assertEquals(1, count);
    }
}
