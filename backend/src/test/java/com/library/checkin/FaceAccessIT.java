package com.library.checkin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.*;
import com.library.checkin.entity.FaceChallengeEntity;
import com.library.checkin.entity.Kiosk;
import com.library.checkin.entity.User;
import com.library.checkin.repository.FaceChallengeRepository;
import com.library.checkin.repository.KioskRepository;
import com.library.checkin.repository.RecognitionAttemptRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.JwtService;
import com.library.checkin.service.AiClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.hamcrest.Matchers.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("it")
@Testcontainers
public class FaceAccessIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_face_access_it")
            .withUsername("face_user")
            .withPassword("face_pass");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JwtService jwtService;

    @Autowired
    private KioskRepository kioskRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private FaceChallengeRepository faceChallengeRepository;

    @Autowired
    private RecognitionAttemptRepository recognitionAttemptRepository;

    @Autowired
    private ObjectMapper objectMapper;

    @Autowired
    private org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    @MockBean
    private AiClient aiClient;

    private Kiosk kiosk;
    private String kioskToken;
    private User student;

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("DELETE FROM recognition_attempts");
        jdbcTemplate.execute("DELETE FROM face_challenges");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM kiosks");
        jdbcTemplate.execute("DELETE FROM users");

        // AI client default mocks
        when(aiClient.isReady()).thenReturn(true);

        kiosk = new Kiosk();
        kiosk.setCode("K_FACE_1");
        kiosk.setName("Test Gate Kiosk");
        kiosk.setStatus("ACTIVE");
        kiosk.setMode("AUTO");
        kiosk = kioskRepository.save(kiosk);
        kioskToken = jwtService.generateKioskToken(kiosk);

        student = new User();
        student.setCode("STU_FACE_1");
        student.setEmail("stu_face_1@test.com");
        student.setFullName("Face Student 1");
        student.setPasswordHash("hash");
        student.setRole("STUDENT");
        student.setStatus("ACTIVE");
        student.setBiometricVersion(1L);
        student = userRepository.save(student);
    }

    private byte[] createDummyMp4() {
        // Minimal valid MP4 header with 'ftyp' box
        byte[] bytes = new byte[32];
        bytes[0] = 0; bytes[1] = 0; bytes[2] = 0; bytes[3] = 20;
        bytes[4] = 'f'; bytes[5] = 't'; bytes[6] = 'y'; bytes[7] = 'p';
        bytes[8] = 'i'; bytes[9] = 's'; bytes[10] = 'o'; bytes[11] = 'm';
        return bytes;
    }

    @Test
    void testIssueFaceChallenge_Success() throws Exception {
        mockMvc.perform(post("/api/v1/access/face-challenge")
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.challengeId").isNotEmpty())
                .andExpect(jsonPath("$.expiresAt").isNotEmpty())
                .andExpect(jsonPath("$.instructions", hasSize(2)))
                .andExpect(jsonPath("$.instructions[0].action").value("BLINK"))
                .andExpect(jsonPath("$.instructions[0].order").value(1))
                .andExpect(jsonPath("$.instructions[1].action", anyOf(is("TURN_LEFT"), is("TURN_RIGHT"))))
                .andExpect(jsonPath("$.captureRules.minImages").value(3));
    }

    @Test
    void testIssueFaceChallenge_AiUnavailable() throws Exception {
        when(aiClient.isReady()).thenReturn(false);

        mockMvc.perform(post("/api/v1/access/face-challenge")
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("AI_UNAVAILABLE"))
                .andExpect(jsonPath("$.fallbackRecommended").value(true));
    }

    @Test
    void testRecordFaceAccess_MissingIdempotencyKey() throws Exception {
        MockMultipartFile clip = new MockMultipartFile("clip", "clip.mp4", "video/mp4", createDummyMp4());

        mockMvc.perform(multipart("/api/v1/access/face")
                        .file(clip)
                        .param("challengeId", UUID.randomUUID().toString())
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("IDEMPOTENCY_KEY_REQUIRED"));
    }

    @Test
    void testRecordFaceAccess_InvalidChallenge() throws Exception {
        MockMultipartFile clip = new MockMultipartFile("clip", "clip.mp4", "video/mp4", createDummyMp4());

        mockMvc.perform(multipart("/api/v1/access/face")
                        .file(clip)
                        .param("challengeId", UUID.randomUUID().toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isUnprocessableEntity())
                .andExpect(jsonPath("$.code").value("CHALLENGE_INVALID"));
    }

    @Test
    void testRecordFaceAccess_SimulatedRejected() throws Exception {
        // Issue challenge
        FaceChallengeEntity challenge = new FaceChallengeEntity();
        challenge.setKioskId(kiosk.getId());
        challenge.setInstructions("[{\"action\": \"BLINK\", \"order\": 1}, {\"action\": \"TURN_LEFT\", \"order\": 2}]");
        challenge.setModelVersion("arcface-512-v1");
        challenge.setConfigVersion(1L);
        challenge.setExpiresAt(OffsetDateTime.now().plusSeconds(60));
        challenge = faceChallengeRepository.save(challenge);

        when(aiClient.recognizeFace(any(), any(), any(), anyString(), anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(new InternalRecognitionResult(
                        true,
                        student.getId(),
                        1L,
                        UUID.randomUUID(),
                        0.15,
                        0.30,
                        true,
                        0.98,
                        "arcface-512-r100",
                        "arcface-512-v1",
                        "anti-spoof-v1",
                        true, // simulated!
                        "MATCHED"
                ));

        MockMultipartFile clip = new MockMultipartFile("clip", "clip.mp4", "video/mp4", createDummyMp4());

        mockMvc.perform(multipart("/api/v1/access/face")
                        .file(clip)
                        .param("challengeId", challenge.getId().toString())
                        .header("Idempotency-Key", UUID.randomUUID().toString())
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("SIMULATED_RESULT_REJECTED"))
                .andExpect(jsonPath("$.fallbackRecommended").value(true));
    }

    @Test
    void testRecordFaceAccess_Success() throws Exception {
        // Issue challenge
        FaceChallengeEntity challenge = new FaceChallengeEntity();
        challenge.setKioskId(kiosk.getId());
        challenge.setInstructions("[{\"action\": \"BLINK\", \"order\": 1}, {\"action\": \"TURN_LEFT\", \"order\": 2}]");
        challenge.setModelVersion("arcface-512-v1");
        challenge.setConfigVersion(1L);
        challenge.setExpiresAt(OffsetDateTime.now().plusSeconds(60));
        challenge = faceChallengeRepository.save(challenge);

        when(aiClient.recognizeFace(any(), any(), any(), anyString(), anyDouble(), anyDouble(), anyDouble()))
                .thenReturn(new InternalRecognitionResult(
                        true,
                        student.getId(),
                        1L,
                        UUID.randomUUID(),
                        0.15,
                        0.30,
                        true,
                        0.98,
                        "arcface-512-r100",
                        "arcface-512-v1",
                        "anti-spoof-v1",
                        false, // real!
                        "MATCHED"
                ));

        MockMultipartFile clip = new MockMultipartFile("clip", "clip.mp4", "video/mp4", createDummyMp4());
        UUID idemKey = UUID.randomUUID();

        mockMvc.perform(multipart("/api/v1/access/face")
                        .file(clip)
                        .param("challengeId", challenge.getId().toString())
                        .header("Idempotency-Key", idemKey.toString())
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.action").value("CHECK_IN"))
                .andExpect(jsonPath("$.method").value("FACE"))
                .andExpect(jsonPath("$.subject.code").value("STU_FACE_1"))
                .andExpect(jsonPath("$.occupancy.count").value(1));

        // Replay same request with Idempotency-Key returns cached response
        mockMvc.perform(multipart("/api/v1/access/face")
                        .file(clip)
                        .param("challengeId", challenge.getId().toString())
                        .header("Idempotency-Key", idemKey.toString())
                        .header("Authorization", "Bearer " + kioskToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.action").value("CHECK_IN"))
                .andExpect(jsonPath("$.method").value("FACE"));
    }
}
