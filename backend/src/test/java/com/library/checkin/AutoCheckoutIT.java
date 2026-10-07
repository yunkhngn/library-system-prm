package com.library.checkin;

import com.library.checkin.dto.OpeningSlot;
import com.library.checkin.dto.PatchSystemConfigRequest;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.CheckinLog;
import com.library.checkin.entity.LibraryState;
import com.library.checkin.entity.User;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.LibraryStateRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.service.AutoCheckoutService;
import com.library.checkin.service.SystemConfigService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest
@ActiveProfiles("it")
@Testcontainers
class AutoCheckoutIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_autocheckout_it")
            .withUsername("auto_user")
            .withPassword("auto_pass");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private AutoCheckoutService autoCheckoutService;

    @Autowired
    private SystemConfigService systemConfigService;

    @Autowired
    private CheckinLogRepository checkinLogRepository;

    @Autowired
    private LibraryStateRepository libraryStateRepository;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private com.library.checkin.repository.KioskRepository kioskRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    private User admin;
    private User student;
    private com.library.checkin.entity.Kiosk kiosk;

    @BeforeEach
    void setUp() {
        jdbcTemplate.execute("""
            UPDATE system_config SET 
                value = '{"timezone":"Asia/Ho_Chi_Minh","openingHours":[{"dayOfWeek":1,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":2,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":3,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":4,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":5,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":6,"opensAt":"00:00","closesAt":"23:59"},{"dayOfWeek":7,"opensAt":"00:00","closesAt":"23:59"}],"maxCapacity":250,"nearCapacityRatio":0.9,"capacityEnforcement":false,"maxSessionDurationMinutes":null,"scanCooldownSeconds":10,"faceModelVersion":null,"faceThreshold":null,"livenessThreshold":null,"biometricRetentionMonths":12}'::jsonb,
                version = 1,
                updated_by = NULL
            WHERE key = 'operational'
        """);
        jdbcTemplate.execute("DELETE FROM access_requests");
        jdbcTemplate.execute("DELETE FROM checkin_logs");
        jdbcTemplate.execute("DELETE FROM visitors");
        jdbcTemplate.execute("DELETE FROM qr_grants");
        jdbcTemplate.execute("UPDATE auth_refresh_tokens SET replaced_by = NULL");
        jdbcTemplate.execute("DELETE FROM auth_refresh_tokens");
        jdbcTemplate.execute("DELETE FROM users");
        jdbcTemplate.execute("DELETE FROM kiosks");

        admin = new User();
        admin.setCode("AD001");
        admin.setEmail("ad@auto.test");
        admin.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        admin.setFullName("Admin User");
        admin.setRole("ADMIN");
        admin.setStatus("ACTIVE");
        admin.setMustChangePassword(false);
        admin = userRepository.save(admin);

        student = new User();
        student.setCode("STU001");
        student.setEmail("stu@auto.test");
        student.setPasswordHash(passwordEncoder.encode("Pass12345678!"));
        student.setFullName("Student Auto");
        student.setRole("STUDENT");
        student.setStatus("ACTIVE");
        student.setMustChangePassword(false);
        student = userRepository.save(student);

        kiosk = new com.library.checkin.entity.Kiosk();
        kiosk.setCode("K001");
        kiosk.setName("Auto Kiosk");
        kiosk.setMode("AUTO");
        kiosk.setStatus("ACTIVE");
        kiosk = kioskRepository.save(kiosk);

        LibraryState state = new LibraryState();
        state.setId((short) 1);
        state.setOccupancyRevision(1L);
        libraryStateRepository.saveAndFlush(state);
    }

    @Test
    @DisplayName("Auto checkout by max duration")
    void testAutoCheckout_MaxDuration() {
        OffsetDateTime now = OffsetDateTime.now();

        // Configure max duration = 60 minutes
        SystemConfig currentConfig = systemConfigService.getOperational();
        systemConfigService.updateOperational(new PatchSystemConfigRequest(
                currentConfig.version(),
                null, null, null, null, null,
                60, // maxSessionDurationMinutes
                null, null, null, null, null
        ), admin.getId());

        // Insert open session entered 90 minutes ago
        CheckinLog log = new CheckinLog();
        log.setUserId(student.getId());
        log.setCheckInTime(now.minusMinutes(90));
        log.setMethod("QR");
        log.setKioskId(kiosk.getId());
        checkinLogRepository.saveAndFlush(log);

        int checkedOut = autoCheckoutService.processAutoCheckouts();
        assertEquals(1, checkedOut);

        CheckinLog updated = checkinLogRepository.findById(log.getId()).orElseThrow();
        assertEquals("MAX_DURATION", updated.getCheckoutReason());
        assertNotNull(updated.getCheckOutTime());

        // Calling again does not check out already checked-out sessions
        int repeated = autoCheckoutService.processAutoCheckouts();
        assertEquals(0, repeated);
    }

    @Test
    @DisplayName("Auto checkout by closing time")
    void testAutoCheckout_ClosingTime() {
        OffsetDateTime now = OffsetDateTime.now();
        ZoneId zone = ZoneId.of("Asia/Ho_Chi_Minh");
        int todayDOW = now.atZoneSameInstant(zone).getDayOfWeek().getValue();

        // Configure opening hours for tomorrow only (so library is currently closed)
        int differentDOW = (todayDOW % 7) + 1;
        OpeningSlot slot = new OpeningSlot(differentDOW, "08:00", "20:00");

        SystemConfig currentConfig = systemConfigService.getOperational();
        systemConfigService.updateOperational(new PatchSystemConfigRequest(
                currentConfig.version(),
                null, List.of(slot), null, null, null, null, null, null, null, null, null
        ), admin.getId());

        // Insert open session
        CheckinLog log = new CheckinLog();
        log.setUserId(student.getId());
        log.setCheckInTime(now.minusMinutes(10));
        log.setMethod("MANUAL");
        log.setPerformedBy(admin.getId());
        log.setManualReason("Testing closing time auto checkout");
        checkinLogRepository.saveAndFlush(log);

        int checkedOut = autoCheckoutService.processAutoCheckouts();
        assertEquals(1, checkedOut);

        CheckinLog updated = checkinLogRepository.findById(log.getId()).orElseThrow();
        assertEquals("CLOSING_TIME", updated.getCheckoutReason());
        assertNotNull(updated.getCheckOutTime());
    }
}
