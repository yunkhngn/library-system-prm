package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.LoginRequest;
import com.library.checkin.dto.OpeningSlot;
import com.library.checkin.dto.PatchSystemConfigRequest;
import com.library.checkin.entity.User;
import com.library.checkin.repository.UserRepository;
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
import java.time.ZoneOffset;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class ConfigIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_config_it")
            .withUsername("cfg_user")
            .withPassword("cfg_pass");

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
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private String adminToken;
    private String libToken;
    private String stuToken;

    @BeforeEach
    void setUp() throws Exception {
        jdbcTemplate.execute("""
            UPDATE system_config SET 
                value = '{"timezone":"Asia/Ho_Chi_Minh","openingHours":[{"dayOfWeek":1,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":2,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":3,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":4,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":5,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":6,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":7,"opensAt":"00:00","closesAt":"23:59"}],"maxCapacity":250,"nearCapacityRatio":0.9,"capacityEnforcement":false,"maxSessionDurationMinutes":null,"scanCooldownSeconds":10,"faceModelVersion":null,"faceThreshold":null,"livenessThreshold":null,"biometricRetentionMonths":12}'::jsonb,
                version = 1,
                updated_by = NULL
            WHERE key = 'operational'
        """);
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");

        createUser("AD001", "admin@cfg.test", "Admin User", "ADMIN", "ACTIVE");
        createUser("LIB001", "lib@cfg.test", "Librarian User", "LIBRARIAN", "ACTIVE");
        createUser("STU001", "stu@cfg.test", "Student User", "STUDENT", "ACTIVE");

        adminToken = loginUser("AD001");
        libToken = loginUser("LIB001");
        stuToken = loginUser("STU001");
    }

    private void createUser(String code, String email, String fullName, String role, String status) {
        User u = new User();
        u.setCode(code);
        u.setEmail(email);
        u.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        u.setFullName(fullName);
        u.setRole(role);
        u.setStatus(status);
        u.setMustChangePassword(false);
        userRepository.save(u);
    }

    private String loginUser(String identifier) throws Exception {
        LoginRequest req = new LoginRequest(identifier, "Pass12345678!");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        return json.get("accessToken").asText();
    }

    @Test
    @DisplayName("Get system config: admin and librarian can read; student cannot")
    void testGetSystemConfig() throws Exception {
        mockMvc.perform(get("/api/v1/system-config")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.timezone").value("Asia/Ho_Chi_Minh"))
                .andExpect(jsonPath("$.maxCapacity").value(250))
                .andExpect(jsonPath("$.nearCapacityRatio").value(0.9))
                .andExpect(jsonPath("$.scanCooldownSeconds").value(10));

        mockMvc.perform(get("/api/v1/system-config")
                        .header("Authorization", "Bearer " + libToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxCapacity").value(250));

        mockMvc.perform(get("/api/v1/system-config")
                        .header("Authorization", "Bearer " + stuToken))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Patch system config: atomic update, optimistic locking, range validation")
    void testPatchSystemConfig() throws Exception {
        MvcResult getRes = mockMvc.perform(get("/api/v1/system-config")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andReturn();
        long currentVersion = objectMapper.readTree(getRes.getResponse().getContentAsString()).get("version").asLong();

        // 1. Success patch
        PatchSystemConfigRequest patchReq = new PatchSystemConfigRequest(
                currentVersion,
                null,
                null,
                300,
                0.85,
                true,
                null,
                15,
                null, null, null, null
        );

        mockMvc.perform(patch("/api/v1/system-config")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(patchReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.maxCapacity").value(300))
                .andExpect(jsonPath("$.nearCapacityRatio").value(0.85))
                .andExpect(jsonPath("$.capacityEnforcement").value(true))
                .andExpect(jsonPath("$.scanCooldownSeconds").value(15))
                .andExpect(jsonPath("$.version").value(currentVersion + 1))
                .andExpect(jsonPath("$.updatedBy.code").value("AD001"));

        // 2. Stale version -> 409 VERSION_CONFLICT
        mockMvc.perform(patch("/api/v1/system-config")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(patchReq)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

        // 3. Validation: out-of-range capacity
        PatchSystemConfigRequest badCap = new PatchSystemConfigRequest(
                currentVersion + 1,
                null, null, -5, null, null, null, null, null, null, null, null
        );
        mockMvc.perform(patch("/api/v1/system-config")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(badCap)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));

        // 4. Validation: opensAt == closesAt invalid
        OpeningSlot badSlot = new OpeningSlot(1, "08:00", "08:00");
        PatchSystemConfigRequest badHours = new PatchSystemConfigRequest(
                currentVersion + 1,
                null, List.of(badSlot), null, null, null, null, null, null, null, null, null
        );
        mockMvc.perform(patch("/api/v1/system-config")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(badHours)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }

    @Test
    @DisplayName("Analytics: access and recognition endpoints contract")
    void testAnalyticsEndpoints() throws Exception {
        ZoneOffset vnOffset = ZoneOffset.ofHours(7);
        OffsetDateTime from = OffsetDateTime.of(2026, 10, 1, 0, 0, 0, 0, vnOffset);
        OffsetDateTime to = OffsetDateTime.of(2026, 10, 8, 0, 0, 0, 0, vnOffset);

        // Access analytics DAY
        mockMvc.perform(get("/api/v1/analytics/access")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("from", from.toString())
                        .param("to", to.toString())
                        .param("bucket", "DAY"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.timezone").value("Asia/Ho_Chi_Minh"))
                .andExpect(jsonPath("$.bucket").value("DAY"))
                .andExpect(jsonPath("$.buckets.length()").value(7));

        // Invalid time range (to <= from)
        mockMvc.perform(get("/api/v1/analytics/access")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("from", to.toString())
                        .param("to", from.toString()))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("INVALID_TIME_RANGE"));

        // Recognition analytics
        mockMvc.perform(get("/api/v1/analytics/recognition")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("from", from.toString())
                        .param("to", to.toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalAttempts").value(0))
                .andExpect(jsonPath("$.matched").value(0))
                .andExpect(jsonPath("$.failed").value(0));
    }
}
