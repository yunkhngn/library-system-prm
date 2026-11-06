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
import io.jsonwebtoken.Claims;
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

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class QrIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_qr_it")
            .withUsername("qr_user")
            .withPassword("qr_pass");

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
        jdbcTemplate.execute("DELETE FROM qr_grants");
        jdbcTemplate.execute("DELETE FROM kiosks");
        jdbcTemplate.execute("DELETE FROM users");
    }

    private User createTestUser(String code, String email, String role, String status) {
        User user = new User();
        user.setCode(code.toUpperCase());
        user.setEmail(email.toLowerCase());
        user.setFullName("User " + code);
        user.setRole(role);
        user.setStatus(status);
        user.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        user.setMustChangePassword(false);
        user.setAuthVersion(0L);
        user.setBiometricVersion(0L);
        user.setCreatedAt(OffsetDateTime.now());
        user.setUpdatedAt(OffsetDateTime.now());
        return userRepository.save(user);
    }

    private String loginUser(String identifier) throws Exception {
        LoginRequest req = new LoginRequest(identifier, "Pass12345678!");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();
    }

    @Test
    @DisplayName("Active student can generate 30-second QR token with no email/images and correct claims")
    void testStudentIssueQr() throws Exception {
        User student = createTestUser("STU500", "stu500@example.test", "STUDENT", "ACTIVE");
        String studentToken = loginUser("STU500");

        MvcResult result = mockMvc.perform(post("/api/v1/me/qr")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").exists())
                .andExpect(jsonPath("$.expiresAt").exists())
                .andExpect(jsonPath("$.refreshAfterSeconds").value(25))
                .andReturn();

        JsonNode qrNode = objectMapper.readTree(result.getResponse().getContentAsString());
        String qrTokenString = qrNode.get("token").asText();

        // Validate token claims and ensure no sensitive data like email/images leaked
        Claims claims = jwtService.parseAndValidateToken(qrTokenString);
        assertEquals("QR_ACCESS", claims.get("purpose"));
        assertEquals("STU500", claims.get("code"));
        assertEquals(student.getId().toString(), claims.get("userId"));
        assertNotNull(claims.get("nonce"));
        assertNull(claims.get("email"), "QR token must not contain email");

        // Verify QrGrant was persisted in DB
        assertTrue(qrGrantRepository.existsByNonceHash(jwtService.hashToken(claims.get("nonce", String.class))));
    }

    @Test
    @DisplayName("Librarian or Admin cannot issue QR, and LOCKED student cannot issue QR")
    void testQrRoleAndStatusRestrictions() throws Exception {
        createTestUser("ADM01", "adm01@example.test", "ADMIN", "ACTIVE");
        String adminToken = loginUser("ADM01");

        // Admin attempting to issue QR -> 403 FORBIDDEN
        mockMvc.perform(post("/api/v1/me/qr")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        // Locked student cannot log in to issue QR
        createTestUser("LOCKED_STU", "locked_stu@example.test", "STUDENT", "LOCKED");
        LoginRequest lockedLogin = new LoginRequest("LOCKED_STU", "Pass12345678!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(lockedLogin)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));
    }

    @Test
    @DisplayName("Admin kiosk CRUD, optimistic locking, and credential rotation")
    void testAdminKioskManagement() throws Exception {
        createTestUser("ADM02", "adm02@example.test", "ADMIN", "ACTIVE");
        String adminToken = loginUser("ADM02");

        // Create Kiosk
        CreateKioskRequest createReq = new CreateKioskRequest("K-ENT-01", "Main Entrance Kiosk", "ENTRY");
        MvcResult createRes = mockMvc.perform(post("/api/v1/kiosks")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.credential").exists())
                .andExpect(jsonPath("$.kiosk.code").value("K-ENT-01"))
                .andExpect(jsonPath("$.kiosk.status").value("ACTIVE"))
                .andReturn();

        JsonNode credNode = objectMapper.readTree(createRes.getResponse().getContentAsString());
        UUID kioskId = UUID.fromString(credNode.get("kiosk").get("id").asText());
        String secret1 = credNode.get("credential").asText();
        long version = credNode.get("kiosk").get("version").asLong();

        // Duplicate code -> 409 CODE_EXISTS
        mockMvc.perform(post("/api/v1/kiosks")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createReq)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CODE_EXISTS"));

        // Get kiosk details (must NOT return credentials)
        mockMvc.perform(get("/api/v1/kiosks/" + kioskId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("K-ENT-01"))
                .andExpect(jsonPath("$.credential").doesNotExist())
                .andExpect(jsonPath("$.credentialHash").doesNotExist());

        // Rotate credential with stale version -> 409 VERSION_CONFLICT
        VersionRequest staleVersion = new VersionRequest(version + 5);
        mockMvc.perform(post("/api/v1/kiosks/" + kioskId + "/rotate-credential")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(staleVersion)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

        // Rotate credential successfully
        VersionRequest validVersion = new VersionRequest(version);
        MvcResult rotateRes = mockMvc.perform(post("/api/v1/kiosks/" + kioskId + "/rotate-credential")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validVersion)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.credential").exists())
                .andReturn();

        String secret2 = objectMapper.readTree(rotateRes.getResponse().getContentAsString()).get("credential").asText();
        assertNotEquals(secret1, secret2);
    }

    @Test
    @DisplayName("Kiosk login, heartbeat, runtime config, and invalidation upon credential rotation")
    void testKioskTokenHeartbeatAndRevocation() throws Exception {
        createTestUser("ADM03", "adm03@example.test", "ADMIN", "ACTIVE");
        String adminToken = loginUser("ADM03");

        // Admin creates Kiosk
        CreateKioskRequest createReq = new CreateKioskRequest("K-EXIT-01", "East Exit Kiosk", "EXIT");
        MvcResult createRes = mockMvc.perform(post("/api/v1/kiosks")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode credNode = objectMapper.readTree(createRes.getResponse().getContentAsString());
        UUID kioskId = UUID.fromString(credNode.get("kiosk").get("id").asText());
        String initialSecret = credNode.get("credential").asText();
        long version = credNode.get("kiosk").get("version").asLong();

        // Kiosk login with invalid credential -> 401 INVALID_CREDENTIALS
        KioskLoginRequest wrongLogin = new KioskLoginRequest(kioskId, null, "wrong-credential-secret-at-least-32-chars-long");
        mockMvc.perform(post("/api/v1/kiosks/token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongLogin)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));

        // Kiosk login with valid credential -> 200 KioskToken
        // Kiosk code works in place of the id, case-insensitively
        KioskLoginRequest codeLogin = new KioskLoginRequest(null, " k-exit-01 ", initialSecret);
        mockMvc.perform(post("/api/v1/kiosks/token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(codeLogin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.kiosk.id").value(kioskId.toString()));

        KioskLoginRequest validLogin = new KioskLoginRequest(kioskId, null, initialSecret);
        MvcResult tokenRes = mockMvc.perform(post("/api/v1/kiosks/token")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validLogin)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.expiresIn").value(3600))
                .andExpect(jsonPath("$.kiosk.code").value("K-EXIT-01"))
                .andReturn();

        String kioskJwt1 = objectMapper.readTree(tokenRes.getResponse().getContentAsString()).get("accessToken").asText();

        // Kiosk sends heartbeat
        HeartbeatRequest heartbeatReq = new HeartbeatRequest("v1.2.0", "OK");
        mockMvc.perform(post("/api/v1/kiosks/heartbeat")
                        .header("Authorization", "Bearer " + kioskJwt1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(heartbeatReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.serverTime").exists())
                .andExpect(jsonPath("$.kiosk.isOnline").value(true));

        // Kiosk fetches runtime config
        mockMvc.perform(get("/api/v1/kiosks/me/config")
                        .header("Authorization", "Bearer " + kioskJwt1))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.kioskId").value(kioskId.toString()))
                .andExpect(jsonPath("$.mode").value("EXIT"))
                .andExpect(jsonPath("$.qrTtlSeconds").value(30))
                .andExpect(jsonPath("$.faceEnabled").value(false));

        // User JWT cannot call kiosk heartbeat -> 403 FORBIDDEN
        mockMvc.perform(post("/api/v1/kiosks/heartbeat")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(heartbeatReq)))
                .andExpect(status().isForbidden());

        // Fetch current version (which was incremented on heartbeat) and rotate credential
        MvcResult latestKioskRes = mockMvc.perform(get("/api/v1/kiosks/" + kioskId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        long currentVersion = objectMapper.readTree(latestKioskRes.getResponse().getContentAsString()).get("version").asLong();

        mockMvc.perform(post("/api/v1/kiosks/" + kioskId + "/rotate-credential")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new VersionRequest(currentVersion))))
                .andExpect(status().isOk());

        // Using old token on heartbeat now returns 401 TOKEN_REVOKED
        mockMvc.perform(post("/api/v1/kiosks/heartbeat")
                        .header("Authorization", "Bearer " + kioskJwt1)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(heartbeatReq)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_REVOKED"));
    }
}
