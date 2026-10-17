package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.LoginRequest;
import com.library.checkin.dto.ManualAccessRequest;
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

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class StudentLookupIT {

    private static final String PASSWORD = "Pass12345678!";

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_lookup_it")
            .withUsername("lookup_user")
            .withPassword("lookup_pass");

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

    private User student;
    private String librarianToken;
    private String adminToken;
    private String studentToken;

    @BeforeEach
    void setUp() throws Exception {
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("DELETE FROM visitors");
        jdbcTemplate.execute("DELETE FROM qr_grants");
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");

        saveUser("LIB801", "Thủ thư Tám", "LIBRARIAN", "ACTIVE");
        saveUser("ADM801", "Quản trị Tám", "ADMIN", "ACTIVE");
        student = saveUser("STU801", "Trần Minh Quân", "STUDENT", "ACTIVE");
        saveUser("STU802", "Sinh viên Bị Khóa", "STUDENT", "LOCKED");

        librarianToken = login("LIB801");
        adminToken = login("ADM801");
        studentToken = login("STU801");
    }

    private User saveUser(String code, String fullName, String role, String status) {
        User user = new User();
        user.setCode(code);
        user.setEmail(code.toLowerCase() + "@test.com");
        user.setPasswordHash(passwordEncoder.encode(PASSWORD));
        user.setFullName(fullName);
        user.setRole(role);
        user.setStatus(status);
        user.setMustChangePassword(false);
        return userRepository.save(user);
    }

    private String login(String code) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new LoginRequest(code, PASSWORD))))
                .andExpect(status().isOk())
                .andReturn();
        return objectMapper.readTree(result.getResponse().getContentAsString()).get("accessToken").asText();
    }

    @Test
    @DisplayName("Librarian resolves a student code to the id used by manual access, with presence")
    void lookupThenManualCheckIn() throws Exception {
        MvcResult outside = mockMvc.perform(get("/api/v1/students/lookup")
                        .header("Authorization", "Bearer " + librarianToken)
                        .param("code", "  stu801 "))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(student.getId().toString()))
                .andExpect(jsonPath("$.code").value("STU801"))
                .andExpect(jsonPath("$.fullName").value("Trần Minh Quân"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.isInside").value(false))
                .andExpect(jsonPath("$.currentSessionId").doesNotExist())
                .andReturn();

        String body = outside.getResponse().getContentAsString();
        assertFalse(body.contains("email"), "Lookup must not expose email");
        assertFalse(body.contains("@test.com"), "Lookup must not expose email");

        UUID studentId = UUID.fromString(objectMapper.readTree(body).get("id").asText());
        MvcResult checkIn = mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new ManualAccessRequest(studentId, null, "CHECK_IN", "Sinh viên quên điện thoại"))))
                .andExpect(status().isOk())
                .andReturn();
        String sessionId = objectMapper.readTree(checkIn.getResponse().getContentAsString()).get("sessionId").asText();

        mockMvc.perform(get("/api/v1/students/lookup")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("code", "STU801"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isInside").value(true))
                .andExpect(jsonPath("$.currentSessionId").value(sessionId))
                .andExpect(jsonPath("$.checkInTime").exists());
    }

    @Test
    @DisplayName("Locked students are returned with their status so the UI can explain why check-in is refused")
    void lockedStudentIsReported() throws Exception {
        mockMvc.perform(get("/api/v1/students/lookup")
                        .header("Authorization", "Bearer " + librarianToken)
                        .param("code", "STU802"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("LOCKED"))
                .andExpect(jsonPath("$.isInside").value(false));
    }

    @Test
    @DisplayName("Unknown codes and non-student accounts are both 404")
    void unknownAndStaffCodesAreNotFound() throws Exception {
        for (String code : new String[]{"NOPE999", "LIB801", "ADM801"}) {
            mockMvc.perform(get("/api/v1/students/lookup")
                            .header("Authorization", "Bearer " + librarianToken)
                            .param("code", code))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));
        }
    }

    @Test
    @DisplayName("Missing or blank code is rejected")
    void codeIsRequired() throws Exception {
        mockMvc.perform(get("/api/v1/students/lookup")
                        .header("Authorization", "Bearer " + librarianToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("MISSING_PARAMETER"));

        mockMvc.perform(get("/api/v1/students/lookup")
                        .header("Authorization", "Bearer " + librarianToken)
                        .param("code", "   "))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_QUERY"));
    }

    @Test
    @DisplayName("Only staff may look up students")
    void onlyStaffMayLookUp() throws Exception {
        mockMvc.perform(get("/api/v1/students/lookup")
                        .header("Authorization", "Bearer " + studentToken)
                        .param("code", "STU801"))
                .andExpect(status().isForbidden());

        mockMvc.perform(get("/api/v1/students/lookup").param("code", "STU801"))
                .andExpect(status().isUnauthorized());
    }
}
