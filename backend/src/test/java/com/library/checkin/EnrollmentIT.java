package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.ConsentRequest;
import com.library.checkin.dto.InternalEmbeddingResult;
import com.library.checkin.dto.LoginRequest;
import com.library.checkin.entity.User;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.service.AiClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.anyList;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class EnrollmentIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_enrollment_it")
            .withUsername("enr_user")
            .withPassword("enr_pass");

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

    @MockBean
    private AiClient aiClient;

    private String studentToken;
    private String adminToken;

    @BeforeEach
    void setUp() throws Exception {
        jdbcTemplate.execute("DELETE FROM face_embeddings");
        jdbcTemplate.execute("DELETE FROM biometric_consents");
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");

        createUser("SV001", "student@enr.test", "Student Enr", "STUDENT", "ACTIVE");
        createUser("AD001", "admin@enr.test", "Admin Enr", "ADMIN", "ACTIVE");

        studentToken = loginUser("SV001");
        adminToken = loginUser("AD001");
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
        u.setBiometricVersion(0L);
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
    @DisplayName("Get face policy contract")
    void testGetFacePolicy() throws Exception {
        mockMvc.perform(get("/api/v1/face-policy")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.version").value("1.0"))
                .andExpect(jsonPath("$.captureRules.minImages").value(3))
                .andExpect(jsonPath("$.captureRules.maxImages").value(5));
    }

    @Test
    @DisplayName("Biometric consent: role check, validation, and idempotent grant")
    void testConsentLifecycle() throws Exception {
        // 1. Admin cannot grant consent -> 403
        mockMvc.perform(post("/api/v1/me/face-consent")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ConsentRequest("1.0", true))))
                .andExpect(status().isForbidden());

        // 2. accepted=false rejected -> 422
        mockMvc.perform(post("/api/v1/me/face-consent")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ConsentRequest("1.0", false))))
                .andExpect(status().isUnprocessableEntity());

        // 3. Obsolete policy version -> 409
        mockMvc.perform(post("/api/v1/me/face-consent")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ConsentRequest("0.9", true))))
                .andExpect(status().isConflict());

        // 4. Initial consent -> 201 Created
        MvcResult res1 = mockMvc.perform(post("/api/v1/me/face-consent")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ConsentRequest("1.0", true))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.policyVersion").value("1.0"))
                .andExpect(jsonPath("$.revokedAt").doesNotExist())
                .andReturn();

        String consentId1 = objectMapper.readTree(res1.getResponse().getContentAsString()).get("id").asText();

        // 5. Repeated consent for same version -> 200 OK (idempotent, same ID)
        MvcResult res2 = mockMvc.perform(post("/api/v1/me/face-consent")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ConsentRequest("1.0", true))))
                .andExpect(status().isOk())
                .andReturn();

        String consentId2 = objectMapper.readTree(res2.getResponse().getContentAsString()).get("id").asText();
        assertEquals(consentId1, consentId2);

        // Verify only 1 record in DB
        Integer consentCount = jdbcTemplate.queryForObject("SELECT count(*) FROM biometric_consents", Integer.class);
        assertEquals(1, consentCount);
    }

    @Test
    @DisplayName("Face enrollment: consent required, image limits, atomic replacement, candidate view")
    void testFaceEnrollmentFlow() throws Exception {
        // 1. Initial status before enrollment -> isEnrolled=false, version=0
        mockMvc.perform(get("/api/v1/me/face-enrollment")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isEnrolled").value(false))
                .andExpect(jsonPath("$.imageCount").value(0))
                .andExpect(jsonPath("$.version").value(0));

        MockMultipartFile img1 = new MockMultipartFile("images", "face1.jpg", "image/jpeg", new byte[100]);
        MockMultipartFile img2 = new MockMultipartFile("images", "face2.jpg", "image/jpeg", new byte[100]);
        MockMultipartFile img3 = new MockMultipartFile("images", "face3.jpg", "image/jpeg", new byte[100]);

        // 2. Enroll without consent -> 409 CONSENT_REQUIRED
        mockMvc.perform(multipart("/api/v1/me/face-enrollment")
                        .file(img1).file(img2).file(img3)
                        .param("version", "0")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CONSENT_REQUIRED"));

        // 3. Grant consent
        mockMvc.perform(post("/api/v1/me/face-consent")
                        .header("Authorization", "Bearer " + studentToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ConsentRequest("1.0", true))))
                .andExpect(status().isCreated());

        // 4. Enroll with only 2 images (< 3) -> 422 IMAGE_INVALID
        mockMvc.perform(multipart("/api/v1/me/face-enrollment")
                        .file(img1).file(img2)
                        .param("version", "0")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("IMAGE_INVALID"));

        // 5. Enroll with stale version (expecting 0, given 5) -> 409 VERSION_CONFLICT
        mockMvc.perform(multipart("/api/v1/me/face-enrollment")
                        .file(img1).file(img2).file(img3)
                        .param("version", "5")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

        // 6. Setup mock AI client returning 3 512-d embeddings
        List<Double> mockVector = new ArrayList<>();
        for (int i = 0; i < 512; i++) mockVector.add(0.05);
        InternalEmbeddingResult mockAiRes = new InternalEmbeddingResult(
                List.of(mockVector, mockVector, mockVector),
                512,
                "arcface-512-mock",
                "arcface-512-v1",
                true
        );
        Mockito.when(aiClient.extractEmbeddings(anyList())).thenReturn(mockAiRes);

        // 7. Successful enrollment
        mockMvc.perform(multipart("/api/v1/me/face-enrollment")
                        .file(img1).file(img2).file(img3)
                        .param("version", "0")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isEnrolled").value(true))
                .andExpect(jsonPath("$.imageCount").value(3))
                .andExpect(jsonPath("$.modelId").value("arcface-512-mock"))
                .andExpect(jsonPath("$.modelVersion").value("arcface-512-v1"))
                .andExpect(jsonPath("$.version").value(1));

        // 8. Verify DB face_embeddings and ai_face_candidates view
        Integer embeddingCount = jdbcTemplate.queryForObject("SELECT count(*) FROM face_embeddings", Integer.class);
        assertEquals(3, embeddingCount);

        Integer candidateCount = jdbcTemplate.queryForObject("SELECT count(*) FROM ai_face_candidates", Integer.class);
        assertEquals(3, candidateCount);

        // 9. Delete enrollment with stale version -> 409
        mockMvc.perform(delete("/api/v1/me/face-enrollment")
                        .param("version", "0")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isConflict());

        // 10. Delete enrollment with current version (1) -> 200, version becomes 2
        mockMvc.perform(delete("/api/v1/me/face-enrollment")
                        .param("version", "1")
                        .header("Authorization", "Bearer " + studentToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isEnrolled").value(false))
                .andExpect(jsonPath("$.version").value(2));

        // Verify candidate view immediately excludes user
        Integer candidateCountAfter = jdbcTemplate.queryForObject("SELECT count(*) FROM ai_face_candidates", Integer.class);
        assertEquals(0, candidateCountAfter);

        // Verify embeddings deleted
        Integer embeddingCountAfter = jdbcTemplate.queryForObject("SELECT count(*) FROM face_embeddings", Integer.class);
        assertEquals(0, embeddingCountAfter);

        // Verify active consent revoked
        Integer activeConsentCount = jdbcTemplate.queryForObject("SELECT count(*) FROM biometric_consents WHERE revoked_at IS NULL", Integer.class);
        assertEquals(0, activeConsentCount);
    }
}
