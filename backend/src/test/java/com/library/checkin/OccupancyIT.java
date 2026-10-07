package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.CreateVisitorRequest;
import com.library.checkin.dto.ManualAccessRequest;
import com.library.checkin.entity.User;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.repository.VisitorRepository;
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

import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class OccupancyIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_occupancy_it")
            .withUsername("occ_user")
            .withPassword("occ_pass");

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
    private VisitorRepository visitorRepository;

    @Autowired
    private CheckinLogRepository checkinLogRepository;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User librarian;
    private User student1;
    private User student2;
    private String librarianToken;
    private String student1Token;
    private String student2Token;

    @BeforeEach
    void setUp() throws Exception {
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("DELETE FROM visitors");
        jdbcTemplate.execute("DELETE FROM qr_grants");
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");

        librarian = new User();
        librarian.setCode("LIB901");
        librarian.setEmail("lib901@test.com");
        librarian.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        librarian.setFullName("Librarian Nine");
        librarian.setRole("LIBRARIAN");
        librarian.setStatus("ACTIVE");
        librarian.setMustChangePassword(false);
        librarian = userRepository.save(librarian);
        librarianToken = loginUser("LIB901");

        student1 = new User();
        student1.setCode("STU901");
        student1.setEmail("stu901@test.com");
        student1.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        student1.setFullName("Student One");
        student1.setRole("STUDENT");
        student1.setStatus("ACTIVE");
        student1.setMustChangePassword(false);
        student1 = userRepository.save(student1);
        student1Token = loginUser("STU901");

        student2 = new User();
        student2.setCode("STU902");
        student2.setEmail("stu902@test.com");
        student2.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        student2.setFullName("Student Two");
        student2.setRole("STUDENT");
        student2.setStatus("ACTIVE");
        student2.setMustChangePassword(false);
        student2 = userRepository.save(student2);
        student2Token = loginUser("STU902");
    }

    private String loginUser(String identifier) throws Exception {
        com.library.checkin.dto.LoginRequest req = new com.library.checkin.dto.LoginRequest(identifier, "Pass12345678!");
        MvcResult result = mockMvc.perform(post("/api/v1/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isOk())
                .andReturn();
        JsonNode json = objectMapper.readTree(result.getResponse().getContentAsString());
        return json.get("accessToken").asText();
    }

    @Test
    @DisplayName("Occupancy snapshot permissions and count")
    void testOccupancySnapshot() throws Exception {
        // STUDENT should be forbidden
        mockMvc.perform(get("/api/v1/occupancy")
                        .header("Authorization", "Bearer " + student1Token))
                .andExpect(status().isForbidden());

        // LIBRARIAN should get 200 OK
        MvcResult result = mockMvc.perform(get("/api/v1/occupancy")
                        .header("Authorization", "Bearer " + librarianToken))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode root = objectMapper.readTree(result.getResponse().getContentAsString());
        assertEquals(0, root.get("count").asLong());
        assertTrue(root.get("maxCapacity").asLong() > 0);
        assertFalse(root.get("nearCapacity").asBoolean());
        assertNotNull(root.get("asOf").asText());
    }

    @Test
    @DisplayName("Visitor registration creates unique reference codes without merging identical names")
    void testVisitorRegistration() throws Exception {
        CreateVisitorRequest req1 = new CreateVisitorRequest("John Doe");
        MvcResult res1 = mockMvc.perform(post("/api/v1/visitors")
                        .header("Authorization", "Bearer " + librarianToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req1)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andReturn();

        JsonNode v1 = objectMapper.readTree(res1.getResponse().getContentAsString());
        String code1 = v1.get("referenceCode").asText();
        assertTrue(code1.startsWith("GUEST-"));
        assertEquals("John Doe", v1.get("fullName").asText());
        assertEquals(librarian.getCode(), v1.get("createdBy").get("code").asText());

        // Create second visitor with same name
        CreateVisitorRequest req2 = new CreateVisitorRequest("John Doe");
        MvcResult res2 = mockMvc.perform(post("/api/v1/visitors")
                        .header("Authorization", "Bearer " + librarianToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req2)))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode v2 = objectMapper.readTree(res2.getResponse().getContentAsString());
        String code2 = v2.get("referenceCode").asText();
        assertNotEquals(code1, code2, "Reference codes must be distinct for identical names");
        assertNotEquals(v1.get("id").asText(), v2.get("id").asText());

        // Search visitors
        MvcResult listRes = mockMvc.perform(get("/api/v1/visitors")
                        .header("Authorization", "Bearer " + librarianToken)
                        .param("q", "John"))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode listNode = objectMapper.readTree(listRes.getResponse().getContentAsString());
        assertEquals(2, listNode.get("totalElements").asLong());

        // Get single visitor
        mockMvc.perform(get("/api/v1/visitors/" + v1.get("id").asText())
                        .header("Authorization", "Bearer " + librarianToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.referenceCode").value(code1));
    }

    @Test
    @DisplayName("Manual access for visitor: check-in, idempotency, duplicate prevention, and check-out")
    void testManualAccessVisitorFlow() throws Exception {
        // Register visitor
        CreateVisitorRequest createReq = new CreateVisitorRequest("Guest Smith");
        MvcResult createRes = mockMvc.perform(post("/api/v1/visitors")
                        .header("Authorization", "Bearer " + librarianToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(createReq)))
                .andExpect(status().isCreated())
                .andReturn();

        JsonNode visitorNode = objectMapper.readTree(createRes.getResponse().getContentAsString());
        UUID visitorId = UUID.fromString(visitorNode.get("id").asText());

        // Check in visitor manually with Idempotency-Key
        UUID key1 = UUID.randomUUID();
        ManualAccessRequest checkInReq = new ManualAccessRequest(null, visitorId, "CHECK_IN", "Visitor entry pass");

        MvcResult checkInRes1 = mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", key1.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(checkInReq)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode checkInJson1 = objectMapper.readTree(checkInRes1.getResponse().getContentAsString());
        assertEquals("CHECK_IN", checkInJson1.get("action").asText());
        assertEquals("VISITOR", checkInJson1.get("subject").get("kind").asText());
        assertEquals(1, checkInJson1.get("occupancy").get("count").asLong());

        // Idempotent retry returns identical payload
        MvcResult checkInRes2 = mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", key1.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(checkInReq)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode checkInJson2 = objectMapper.readTree(checkInRes2.getResponse().getContentAsString());
        assertEquals(checkInJson1, checkInJson2);

        // Subsequent check-in with new key fails with ALREADY_INSIDE
        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(checkInReq)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ALREADY_INSIDE"));

        // Check out visitor
        UUID key2 = UUID.randomUUID();
        ManualAccessRequest checkOutReq = new ManualAccessRequest(null, visitorId, "CHECK_OUT", "Visitor finished");

        MvcResult checkOutRes = mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", key2.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(checkOutReq)))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode checkOutJson = objectMapper.readTree(checkOutRes.getResponse().getContentAsString());
        assertEquals("CHECK_OUT", checkOutJson.get("action").asText());
        assertEquals(0, checkOutJson.get("occupancy").get("count").asLong());

        // Check out again fails with NOT_INSIDE
        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(checkOutReq)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("NOT_INSIDE"));
    }

    @Test
    @DisplayName("Manual check-out is allowed for LOCKED users")
    void testManualCheckoutForLockedUser() throws Exception {
        // Check in student
        UUID inKey = UUID.randomUUID();
        ManualAccessRequest inReq = new ManualAccessRequest(student1.getId(), null, "CHECK_IN", "Manual student entry");

        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", inKey.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(inReq)))
                .andExpect(status().isOk());

        // Lock student account
        student1.setStatus("LOCKED");
        userRepository.save(student1);

        // Another check-in attempt fails with ACCOUNT_LOCKED
        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(inReq)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.code").value("ACCOUNT_LOCKED"));

        // Manual check-out for the LOCKED student must SUCCEED
        UUID outKey = UUID.randomUUID();
        ManualAccessRequest outReq = new ManualAccessRequest(student1.getId(), null, "CHECK_OUT", "Escorted checkout");

        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", outKey.toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(outReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.action").value("CHECK_OUT"))
                .andExpect(jsonPath("$.subject.code").value(student1.getCode()));
    }

    @Test
    @DisplayName("List occupants omits email and removes closed sessions")
    void testListOccupantsOmitsEmailAndReflectsCheckouts() throws Exception {
        // Check in student1
        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ManualAccessRequest(student1.getId(), null, "CHECK_IN", "Entry"))))
                .andExpect(status().isOk());

        // Check occupant list
        MvcResult res1 = mockMvc.perform(get("/api/v1/occupancy/people")
                        .header("Authorization", "Bearer " + librarianToken))
                .andExpect(status().isOk())
                .andReturn();

        String body1 = res1.getResponse().getContentAsString();
        JsonNode page1 = objectMapper.readTree(body1);
        assertEquals(1, page1.get("totalElements").asLong());
        assertFalse(body1.contains("email"), "Occupancy endpoints must omit email");

        // Check out student1
        mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ManualAccessRequest(student1.getId(), null, "CHECK_OUT", "Exit"))))
                .andExpect(status().isOk());

        // Closed session disappears from occupant list
        MvcResult res2 = mockMvc.perform(get("/api/v1/occupancy/people")
                        .header("Authorization", "Bearer " + librarianToken))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode page2 = objectMapper.readTree(res2.getResponse().getContentAsString());
        assertEquals(0, page2.get("totalElements").asLong());
    }

    @Test
    @DisplayName("Student personal access status, history ownership and 404 isolation")
    void testStudentPersonalAccessAndIsolation() throws Exception {
        // Outside status: isInside = false, currentSession = null
        mockMvc.perform(get("/api/v1/me/access-status")
                        .header("Authorization", "Bearer " + student1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isInside").value(false))
                .andExpect(jsonPath("$.currentSession").doesNotExist());

        // Check in student1
        MvcResult inRes = mockMvc.perform(post("/api/v1/access/manual")
                        .header("Authorization", "Bearer " + librarianToken)
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new ManualAccessRequest(student1.getId(), null, "CHECK_IN", "Entry"))))
                .andExpect(status().isOk())
                .andReturn();

        JsonNode inJson = objectMapper.readTree(inRes.getResponse().getContentAsString());
        String sessionId = inJson.get("sessionId").asText();

        // Inside status
        mockMvc.perform(get("/api/v1/me/access-status")
                        .header("Authorization", "Bearer " + student1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.isInside").value(true))
                .andExpect(jsonPath("$.currentSession.id").value(sessionId));

        // Read own session detail
        mockMvc.perform(get("/api/v1/me/access-history/" + sessionId)
                        .header("Authorization", "Bearer " + student1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(sessionId));

        // student2 reading student1's session must return 404
        mockMvc.perform(get("/api/v1/me/access-history/" + sessionId)
                        .header("Authorization", "Bearer " + student2Token))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("RESOURCE_NOT_FOUND"));

        // listAccessHistory validation: reject simultaneous userId and visitorId
        mockMvc.perform(get("/api/v1/access-history")
                        .header("Authorization", "Bearer " + librarianToken)
                        .param("userId", student1.getId().toString())
                        .param("visitorId", UUID.randomUUID().toString()))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("VALIDATION_ERROR"));
    }
}
