package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
import com.library.checkin.entity.User;
import com.library.checkin.repository.RefreshTokenRepository;
import com.library.checkin.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
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
class AuthIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_auth_it")
            .withUsername("auth_user")
            .withPassword("auth_pass");

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
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    @BeforeEach
    void cleanDatabase() {
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");
    }

    private User createTestUser(String code, String email, String role, String status, String rawPassword, boolean mustChangePassword) {
        User user = new User();
        user.setCode(code.toUpperCase());
        user.setEmail(email.toLowerCase());
        user.setFullName("Test User " + code);
        user.setRole(role);
        user.setStatus(status);
        user.setPasswordHash(passwordEncoder.encode(rawPassword));
        user.setMustChangePassword(mustChangePassword);
        user.setAuthVersion(0L);
        user.setBiometricVersion(0L);
        user.setCreatedAt(OffsetDateTime.now());
        user.setUpdatedAt(OffsetDateTime.now());
        return userRepository.save(user);
    }

    @Test
    @DisplayName("Login with invalid credentials does not leak account existence")
    void testLoginInvalidCredentialsDoesNotLeakExistence() throws Exception {
        createTestUser("USER01", "user01@example.test", "STUDENT", "ACTIVE", "ValidPassword123!", false);

        // Non-existent user
        LoginRequest nonExistent = new LoginRequest("DOESNOTEXIST", "SomePassword123!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(nonExistent)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"))
                .andExpect(jsonPath("$.traceId").exists())
                .andExpect(jsonPath("$.timestamp").exists());

        // Existing user with wrong password
        LoginRequest wrongPassword = new LoginRequest("USER01", "WrongPassword123!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongPassword)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    @DisplayName("Login normalization works for both lowercase code and uppercase email")
    void testLoginNormalization() throws Exception {
        createTestUser("STU100", "stu100@example.test", "STUDENT", "ACTIVE", "ValidPassword123!", false);

        // Login using lowercase code
        LoginRequest byCode = new LoginRequest("stu100", "ValidPassword123!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(byCode)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.user.code").value("STU100"))
                .andExpect(jsonPath("$.user.email").value("stu100@example.test"));

        // Login using uppercase email
        LoginRequest byEmail = new LoginRequest("STU100@EXAMPLE.TEST", "ValidPassword123!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(byEmail)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.user.code").value("STU100"));
    }

    @Test
    @DisplayName("LOCKED account receives 403 on valid password and 401 on invalid password")
    void testLockedAccountLogin() throws Exception {
        createTestUser("LOCKED01", "locked01@example.test", "STUDENT", "LOCKED", "ValidPassword123!", false);

        // Wrong password should return 401 without revealing status
        LoginRequest wrongPassword = new LoginRequest("LOCKED01", "WrongPassword123!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongPassword)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));

        // Correct password on locked account should return 403 ACCOUNT_LOCKED
        LoginRequest correctPassword = new LoginRequest("LOCKED01", "ValidPassword123!");
        mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(correctPassword)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));
    }

    @Test
    @DisplayName("Refresh token single-use rotation and replay detection family revocation")
    void testRefreshTokenRotationAndReplay() throws Exception {
        createTestUser("ROT01", "rot01@example.test", "STUDENT", "ACTIVE", "ValidPassword123!", false);

        // Login
        LoginRequest login = new LoginRequest("ROT01", "ValidPassword123!");
        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginNode = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String initialRefreshToken = loginNode.get("refreshToken").asText();

        // 1st Refresh: should succeed and return new pair
        RefreshTokenRequest refresh1 = new RefreshTokenRequest(initialRefreshToken);
        MvcResult refresh1Result = mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refresh1)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andReturn();

        JsonNode refresh1Node = objectMapper.readTree(refresh1Result.getResponse().getContentAsString());
        String secondRefreshToken = refresh1Node.get("refreshToken").asText();
        assertNotEquals(initialRefreshToken, secondRefreshToken);

        // Replay: Re-using the first refresh token should trigger replay detection and revoke family
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refresh1)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_REVOKED"));

        // The second refresh token should now ALSO be revoked because the entire family was invalidated!
        RefreshTokenRequest refresh2 = new RefreshTokenRequest(secondRefreshToken);
        mockMvc.perform(post("/api/v1/auth/refresh")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(refresh2)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_REVOKED"));
    }

    @Test
    @DisplayName("Logout revokes family, is idempotent, and invalidates session access token")
    void testLogoutFlow() throws Exception {
        createTestUser("LOGOUT01", "logout01@example.test", "STUDENT", "ACTIVE", "ValidPassword123!", false);

        LoginRequest login = new LoginRequest("LOGOUT01", "ValidPassword123!");
        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginNode = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String accessToken = loginNode.get("accessToken").asText();
        String refreshToken = loginNode.get("refreshToken").asText();

        // Verify access token works initially
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value("LOGOUT01"));

        // Logout
        RefreshTokenRequest logoutReq = new RefreshTokenRequest(refreshToken);
        mockMvc.perform(post("/api/v1/auth/logout")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(logoutReq)))
                .andExpect(status().isNoContent());

        // Repeated logout should return 204
        mockMvc.perform(post("/api/v1/auth/logout")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(logoutReq)))
                .andExpect(status().isNoContent());

        // Access token whose sid belongs to the logged-out family must now be rejected with 401 TOKEN_REVOKED
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_REVOKED"));
    }

    @Test
    @DisplayName("Forced password change restricts APIs until password changed via /me/password")
    void testForcedPasswordChange() throws Exception {
        createTestUser("FORCE01", "force01@example.test", "ADMIN", "ACTIVE", "OldPassword123!", true);

        // Login
        LoginRequest login = new LoginRequest("FORCE01", "OldPassword123!");
        MvcResult loginResult = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(login)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode loginNode = objectMapper.readTree(loginResult.getResponse().getContentAsString());
        String accessToken = loginNode.get("accessToken").asText();

        // Access to business APIs like /api/v1/users must be rejected with 403 PASSWORD_CHANGE_REQUIRED
        mockMvc.perform(get("/api/v1/users")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("PASSWORD_CHANGE_REQUIRED"));

        // Access to /api/v1/me is permitted
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mustChangePassword").value(true));

        // Wrong current password
        ChangePasswordRequest wrongCurrent = new ChangePasswordRequest("WrongPass123!", "NewPassword123!@#");
        mockMvc.perform(put("/api/v1/me/password")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(wrongCurrent)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("CURRENT_PASSWORD_INVALID"));

        // Same password unchanged
        ChangePasswordRequest samePass = new ChangePasswordRequest("OldPassword123!", "OldPassword123!");
        mockMvc.perform(put("/api/v1/me/password")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(samePass)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("PASSWORD_UNCHANGED"));

        // Successfully change password
        ChangePasswordRequest validChange = new ChangePasswordRequest("OldPassword123!", "NewSecretPass123!456");
        MvcResult changeResult = mockMvc.perform(put("/api/v1/me/password")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(validChange)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").exists())
                .andReturn();

        JsonNode changeNode = objectMapper.readTree(changeResult.getResponse().getContentAsString());
        String newAccessToken = changeNode.get("accessToken").asText();

        // Old access token is now invalid (authVersion incremented)
        mockMvc.perform(get("/api/v1/me")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("TOKEN_REVOKED"));

        // New access token works and can access business APIs
        mockMvc.perform(get("/api/v1/users")
                        .header("Authorization", "Bearer " + newAccessToken))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Admin user CRUD, duplicate checks, optimistic locking, and last admin protection")
    void testAdminUserCrudAndProtection() throws Exception {
        User admin = createTestUser("ADMIN01", "admin01@example.test", "ADMIN", "ACTIVE", "AdminPass123!", false);
        User student = createTestUser("STU200", "stu200@example.test", "STUDENT", "ACTIVE", "StuPass123!", false);

        // Get admin token
        LoginRequest adminLogin = new LoginRequest("ADMIN01", "AdminPass123!");
        String adminToken = objectMapper.readTree(mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(adminLogin)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .get("accessToken").asText();

        // Get student token
        LoginRequest studentLogin = new LoginRequest("STU200", "StuPass123!");
        String studentToken = objectMapper.readTree(mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(studentLogin)))
                .andExpect(status().isOk()).andReturn().getResponse().getContentAsString())
                .get("accessToken").asText();

        // Student accessing /users -> 403 FORBIDDEN
        mockMvc.perform(get("/api/v1/users")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("FORBIDDEN"));

        // Admin creating duplicate code -> 409 CODE_EXISTS
        CreateUserRequest dupCode = new CreateUserRequest("STU200", "another@example.test", "Another", "STUDENT", "Pass12345678!", false);
        mockMvc.perform(post("/api/v1/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dupCode)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CODE_EXISTS"));

        // Admin creating duplicate email -> 409 EMAIL_EXISTS
        CreateUserRequest dupEmail = new CreateUserRequest("STU999", "stu200@example.test", "Another", "STUDENT", "Pass12345678!", false);
        mockMvc.perform(post("/api/v1/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(dupEmail)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_EXISTS"));

        // Admin creating user with code containing @ -> 422 VALIDATION_ERROR
        CreateUserRequest atCode = new CreateUserRequest("BAD@CODE", "badcode@example.test", "Bad Code", "STUDENT", "Pass12345678!", false);
        mockMvc.perform(post("/api/v1/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(atCode)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        // Admin successfully creates user
        CreateUserRequest newUserReq = new CreateUserRequest("NEW001", "new001@example.test", "New User", "STUDENT", "Pass12345678!", true);
        MvcResult createResult = mockMvc.perform(post("/api/v1/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(newUserReq)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.code").value("NEW001"))
                .andReturn();

        JsonNode createdUser = objectMapper.readTree(createResult.getResponse().getContentAsString());
        UUID newUserId = UUID.fromString(createdUser.get("id").asText());
        long version = createdUser.get("version").asLong();

        // Optimistic locking conflict (wrong version)
        PatchUserRequest stalePatch = new PatchUserRequest(version + 5, null, null, "Updated Name", null, null);
        mockMvc.perform(patch("/api/v1/users/" + newUserId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(stalePatch)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

        // Admin attempts to lock the only active admin -> 409 LAST_ADMIN_PROTECTED
        PatchUserRequest lockAdmin = new PatchUserRequest(admin.getVersion(), null, null, null, null, "LOCKED");
        mockMvc.perform(patch("/api/v1/users/" + admin.getId())
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(lockAdmin)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("LAST_ADMIN_PROTECTED"));

        // Admin attempts to demote the only active admin -> 409 LAST_ADMIN_PROTECTED
        PatchUserRequest demoteAdmin = new PatchUserRequest(admin.getVersion(), null, null, null, "LIBRARIAN", null);
        mockMvc.perform(patch("/api/v1/users/" + admin.getId())
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(demoteAdmin)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("LAST_ADMIN_PROTECTED"));
    }
}
