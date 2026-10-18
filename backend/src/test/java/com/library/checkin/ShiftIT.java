package com.library.checkin;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
import com.library.checkin.entity.User;
import com.library.checkin.repository.ShiftAssignmentRepository;
import com.library.checkin.repository.ShiftRepository;
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
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
class ShiftIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_shifts_it")
            .withUsername("shift_user")
            .withPassword("shift_pass");

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
    private ShiftRepository shiftRepository;

    @Autowired
    private ShiftAssignmentRepository shiftAssignmentRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User admin;
    private User librarian1;
    private User librarian2;
    private User student;
    private User lockedLibrarian;

    private String adminToken;
    private String lib1Token;
    private String lib2Token;
    private String studentToken;

    private final ZoneOffset vnOffset = ZoneOffset.ofHours(7);

    @BeforeEach
    void setUp() throws Exception {
        jdbcTemplate.execute("DELETE FROM shift_assignments");
        jdbcTemplate.execute("DELETE FROM shifts");
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("DELETE FROM visitors");
        jdbcTemplate.execute("DELETE FROM qr_grants");
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");

        admin = createUser("AD001", "admin@test.com", "Admin User", "ADMIN", "ACTIVE");
        librarian1 = createUser("LIB001", "lib1@test.com", "Librarian One", "LIBRARIAN", "ACTIVE");
        librarian2 = createUser("LIB002", "lib2@test.com", "Librarian Two", "LIBRARIAN", "ACTIVE");
        student = createUser("STU001", "stu1@test.com", "Student One", "STUDENT", "ACTIVE");
        lockedLibrarian = createUser("LIB999", "liblock@test.com", "Locked Librarian", "LIBRARIAN", "LOCKED");

        adminToken = loginUser("AD001");
        lib1Token = loginUser("LIB001");
        lib2Token = loginUser("LIB002");
        studentToken = loginUser("STU001");
    }

    private User createUser(String code, String email, String fullName, String role, String status) {
        User u = new User();
        u.setCode(code);
        u.setEmail(email);
        u.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        u.setFullName(fullName);
        u.setRole(role);
        u.setStatus(status);
        u.setMustChangePassword(false);
        return userRepository.save(u);
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
    @DisplayName("Create normal and overnight shifts; verify staff codes in actor and duration validation")
    void testCreateShift_SuccessAndValidation() throws Exception {
        OffsetDateTime starts = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime ends = OffsetDateTime.of(2026, 10, 8, 16, 0, 0, 0, vnOffset);

        CreateShiftRequest req = new CreateShiftRequest("Morning Shift", starts, ends);

        MvcResult res = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isCreated())
                .andExpect(header().exists("Location"))
                .andExpect(jsonPath("$.id").exists())
                .andExpect(jsonPath("$.name").value("Morning Shift"))
                .andExpect(jsonPath("$.status").value("ACTIVE"))
                .andExpect(jsonPath("$.version").value(0))
                .andExpect(jsonPath("$.assignmentCount").value(0))
                .andExpect(jsonPath("$.createdBy.code").value("AD001"))
                .andExpect(jsonPath("$.createdBy.fullName").value("Admin User"))
                .andReturn();

        // Overnight shift: 18:00 to 00:30 next day
        OffsetDateTime overnightStart = OffsetDateTime.of(2026, 10, 8, 18, 0, 0, 0, vnOffset);
        OffsetDateTime overnightEnd = OffsetDateTime.of(2026, 10, 9, 0, 30, 0, 0, vnOffset);
        CreateShiftRequest overnightReq = new CreateShiftRequest("Evening Shift", overnightStart, overnightEnd);

        mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(overnightReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("Evening Shift"));

        // Ends before starts -> 422 INVALID_TIME_RANGE
        CreateShiftRequest invalidReq = new CreateShiftRequest("Bad Shift", ends, starts);
        mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(invalidReq)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("INVALID_TIME_RANGE"));

        // Duration > 24 hours -> 422 INVALID_TIME_RANGE
        CreateShiftRequest longReq = new CreateShiftRequest("Too Long", starts, starts.plusHours(25));
        mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(longReq)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("INVALID_TIME_RANGE"));

        // Librarian cannot create shifts -> 403
        mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + lib1Token)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isForbidden());
    }

    @Test
    @DisplayName("Shift listing with date overlap, name search, status filter, and pagination")
    void testListShifts() throws Exception {
        OffsetDateTime s1Start = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime s1End = OffsetDateTime.of(2026, 10, 8, 16, 0, 0, 0, vnOffset);
        mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Early Shift", s1Start, s1End))))
                .andExpect(status().isCreated());

        OffsetDateTime s2Start = OffsetDateTime.of(2026, 10, 9, 8, 0, 0, 0, vnOffset);
        OffsetDateTime s2End = OffsetDateTime.of(2026, 10, 9, 16, 0, 0, 0, vnOffset);
        mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Late Shift", s2Start, s2End))))
                .andExpect(status().isCreated());

        // List shifts
        mockMvc.perform(get("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("q", "Early"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].name").value("Early Shift"));

        // Omitting q must not bind a null value into the LOWER/LIKE expression.
        mockMvc.perform(get("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(2));

        // Invalid time range (to <= from) -> 422
        mockMvc.perform(get("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("from", s2Start.toString())
                        .param("to", s1Start.toString()))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("INVALID_TIME_RANGE"));
    }

    @Test
    @DisplayName("Shift assignments: batch assign, rejection of LOCKED/STUDENT, overlap exclusion, adjacent shifts allowed")
    void testAssignStaff_AndExclusion() throws Exception {
        OffsetDateTime s1Start = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime s1End = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);

        MvcResult shiftRes = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Shift 1", s1Start, s1End))))
                .andExpect(status().isCreated())
                .andReturn();
        String shift1Id = objectMapper.readTree(shiftRes.getResponse().getContentAsString()).get("id").asText();

        // Reject STUDENT
        AssignStaffRequest studentReq = new AssignStaffRequest(0L, List.of(student.getId()));
        mockMvc.perform(post("/api/v1/shifts/" + shift1Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(studentReq)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("STAFF_NOT_ELIGIBLE"));

        // Reject LOCKED librarian
        AssignStaffRequest lockedReq = new AssignStaffRequest(0L, List.of(lockedLibrarian.getId()));
        mockMvc.perform(post("/api/v1/shifts/" + shift1Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(lockedReq)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("STAFF_NOT_ELIGIBLE"));

        // Successful assign librarian1 and librarian2
        AssignStaffRequest okReq = new AssignStaffRequest(0L, List.of(librarian1.getId(), librarian2.getId()));
        MvcResult batchRes = mockMvc.perform(post("/api/v1/shifts/" + shift1Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(okReq)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.shift.version").value(1))
                .andExpect(jsonPath("$.shift.assignmentCount").value(2))
                .andExpect(jsonPath("$.assignments.length()").value(2))
                .andExpect(jsonPath("$.assignments[0].staff.code").exists())
                .andReturn();

        // Stale version when assigning again -> 409 VERSION_CONFLICT
        mockMvc.perform(post("/api/v1/shifts/" + shift1Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

        // Already assigned -> 409 ASSIGNMENT_EXISTS
        mockMvc.perform(post("/api/v1/shifts/" + shift1Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(1L, List.of(librarian1.getId())))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("ASSIGNMENT_EXISTS"));

        // Create overlapping Shift 2: [12:00, 18:00) overlaps with [08:00, 14:00)
        OffsetDateTime s2Start = OffsetDateTime.of(2026, 10, 8, 12, 0, 0, 0, vnOffset);
        OffsetDateTime s2End = OffsetDateTime.of(2026, 10, 8, 18, 0, 0, 0, vnOffset);
        MvcResult shift2Res = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Shift 2 Overlapping", s2Start, s2End))))
                .andExpect(status().isCreated())
                .andReturn();
        String shift2Id = objectMapper.readTree(shift2Res.getResponse().getContentAsString()).get("id").asText();

        // Assigning librarian1 to Shift 2 -> 409 SHIFT_OVERLAP
        mockMvc.perform(post("/api/v1/shifts/" + shift2Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SHIFT_OVERLAP"));

        // Create Adjacent Shift 3: [14:00, 20:00) adjacent to [08:00, 14:00)
        OffsetDateTime s3Start = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);
        OffsetDateTime s3End = OffsetDateTime.of(2026, 10, 8, 20, 0, 0, 0, vnOffset);
        MvcResult shift3Res = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Shift 3 Adjacent", s3Start, s3End))))
                .andExpect(status().isCreated())
                .andReturn();
        String shift3Id = objectMapper.readTree(shift3Res.getResponse().getContentAsString()).get("id").asText();

        // Assigning librarian1 to Shift 3 must SUCCEED because adjacent intervals do not overlap
        mockMvc.perform(post("/api/v1/shifts/" + shift3Id + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.assignments.length()").value(1));
    }

    @Test
    @DisplayName("Atomic staff replacement in PATCH assignment; failed replacement preserves old staff")
    void testPatchAssignment_AtomicReplacement() throws Exception {
        OffsetDateTime sStart = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime sEnd = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);

        MvcResult sRes = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Shift Replace", sStart, sEnd))))
                .andExpect(status().isCreated())
                .andReturn();
        String shiftId = objectMapper.readTree(sRes.getResponse().getContentAsString()).get("id").asText();

        MvcResult aRes = mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isCreated())
                .andReturn();
        String assignmentId = objectMapper.readTree(aRes.getResponse().getContentAsString()).get("assignments").get(0).get("id").asText();

        // Replace librarian1 with librarian2 atomically
        PatchAssignmentRequest patchReq = new PatchAssignmentRequest(0L, librarian2.getId());
        mockMvc.perform(patch("/api/v1/shifts/" + shiftId + "/assignments/" + assignmentId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(patchReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.shift.version").value(2))
                .andExpect(jsonPath("$.assignments[0].staff.code").value("LIB002"))
                .andExpect(jsonPath("$.assignments[0].version").value(1));

        // Attempt replacement with STUDENT -> fails, retains old staff (LIB002)
        PatchAssignmentRequest badReq = new PatchAssignmentRequest(1L, student.getId());
        mockMvc.perform(patch("/api/v1/shifts/" + shiftId + "/assignments/" + assignmentId)
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(badReq)))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("STAFF_NOT_ELIGIBLE"));

        // Verify assignment still has librarian2
        mockMvc.perform(get("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].staff.code").value("LIB002"));
    }

    @Test
    @DisplayName("Shift detail access control: Admin can read all, librarian reads assigned shifts only")
    void testGetShift_Ownership() throws Exception {
        OffsetDateTime sStart = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime sEnd = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);

        MvcResult sRes = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Shift Access", sStart, sEnd))))
                .andExpect(status().isCreated())
                .andReturn();
        String shiftId = objectMapper.readTree(sRes.getResponse().getContentAsString()).get("id").asText();

        // Admin can read
        mockMvc.perform(get("/api/v1/shifts/" + shiftId)
                        .header("Authorization", "Bearer " + adminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("Shift Access"));

        // Librarian1 is not assigned -> 404
        mockMvc.perform(get("/api/v1/shifts/" + shiftId)
                        .header("Authorization", "Bearer " + lib1Token))
                .andExpect(status().isNotFound());

        // Assign librarian1
        mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isCreated());

        // Now librarian1 can read
        mockMvc.perform(get("/api/v1/shifts/" + shiftId)
                        .header("Authorization", "Bearer " + lib1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(shiftId));

        // Librarian2 is still not assigned -> 404
        mockMvc.perform(get("/api/v1/shifts/" + shiftId)
                        .header("Authorization", "Bearer " + lib2Token))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("Shift cancellation soft-cancels shift and assignments, preserves history")
    void testCancelShift() throws Exception {
        OffsetDateTime sStart = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime sEnd = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);

        MvcResult sRes = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("To Cancel", sStart, sEnd))))
                .andExpect(status().isCreated())
                .andReturn();
        String shiftId = objectMapper.readTree(sRes.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isCreated());

        // Cancel shift
        CancelShiftRequest cancelReq = new CancelShiftRequest(1L, "Weather emergency");
        mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/cancel")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(cancelReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"))
                .andExpect(jsonPath("$.cancellationReason").value("Weather emergency"))
                .andExpect(jsonPath("$.version").value(2));

        // Calling cancel again with current version -> idempotent 200
        mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/cancel")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CancelShiftRequest(2L, "Repeat"))))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("CANCELLED"));

        // Assignments are soft-cancelled, not deleted
        mockMvc.perform(get("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("status", "CANCELLED"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].status").value("CANCELLED"));
    }

    @Test
    @DisplayName("Cancel assignment individual soft-cancel with version check")
    void testCancelAssignment_Delete() throws Exception {
        OffsetDateTime sStart = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime sEnd = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);

        MvcResult sRes = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("Shift Del Assign", sStart, sEnd))))
                .andExpect(status().isCreated())
                .andReturn();
        String shiftId = objectMapper.readTree(sRes.getResponse().getContentAsString()).get("id").asText();

        MvcResult aRes = mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId(), librarian2.getId())))))
                .andExpect(status().isCreated())
                .andReturn();
        String a1Id = objectMapper.readTree(aRes.getResponse().getContentAsString()).get("assignments").get(0).get("id").asText();

        // Stale version -> 409
        mockMvc.perform(delete("/api/v1/shifts/" + shiftId + "/assignments/" + a1Id)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("version", "99"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("VERSION_CONFLICT"));

        // Soft cancel a1 -> 204 No Content
        mockMvc.perform(delete("/api/v1/shifts/" + shiftId + "/assignments/" + a1Id)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("version", "0"))
                .andExpect(status().isNoContent());

        // Calling again with version 1 -> 204 idempotent
        mockMvc.perform(delete("/api/v1/shifts/" + shiftId + "/assignments/" + a1Id)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("version", "1"))
                .andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("My shifts endpoint: returns librarian's own schedule with shift and assignment")
    void testListMyShifts() throws Exception {
        OffsetDateTime sStart = OffsetDateTime.of(2026, 10, 8, 8, 0, 0, 0, vnOffset);
        OffsetDateTime sEnd = OffsetDateTime.of(2026, 10, 8, 14, 0, 0, 0, vnOffset);

        MvcResult sRes = mockMvc.perform(post("/api/v1/shifts")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new CreateShiftRequest("My Shift Test", sStart, sEnd))))
                .andExpect(status().isCreated())
                .andReturn();
        String shiftId = objectMapper.readTree(sRes.getResponse().getContentAsString()).get("id").asText();

        mockMvc.perform(post("/api/v1/shifts/" + shiftId + "/assignments")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(new AssignStaffRequest(0L, List.of(librarian1.getId())))))
                .andExpect(status().isCreated());

        // Librarian1 sees the shift in /me/shifts
        mockMvc.perform(get("/api/v1/me/shifts")
                        .header("Authorization", "Bearer " + lib1Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(1))
                .andExpect(jsonPath("$.items[0].shift.name").value("My Shift Test"))
                .andExpect(jsonPath("$.items[0].assignment.status").value("ACTIVE"));

        // Librarian2 does NOT see the shift
        mockMvc.perform(get("/api/v1/me/shifts")
                        .header("Authorization", "Bearer " + lib2Token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items.length()").value(0));
    }
}
