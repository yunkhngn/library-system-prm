package com.library.checkin.service;

import com.library.checkin.entity.User;
import com.library.checkin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.annotation.Profile;
import org.springframework.context.event.EventListener;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Profile("dev")
@RequiredArgsConstructor
@Slf4j
public class DevSeedService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final org.springframework.jdbc.core.JdbcTemplate jdbcTemplate;

    @Value("${app.dev.seed-password:${DEV_SEED_PASSWORD:dev_secret_password_123}}")
    private String devSeedPassword;

    @EventListener(ApplicationReadyEvent.class)
    @Transactional
    public void seedDevAccounts() {
        seedAccount("AD001", "admin@example.test", "System Administrator", "ADMIN");
        seedAccount("LIB001", "librarian@example.test", "Alex Nguyen", "LIBRARIAN");
        seedAccount("SV001", "student@example.test", "Student Van A", "STUDENT");
        ensureDevOpeningHours();
    }

    private void ensureDevOpeningHours() {
        try {
            jdbcTemplate.execute("""
                UPDATE system_config 
                SET value = jsonb_set(
                    value, 
                    '{openingHours}', 
                    '[{"dayOfWeek": 1, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 2, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 3, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 4, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 5, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 6, "opensAt": "00:00", "closesAt": "23:59"}, {"dayOfWeek": 7, "opensAt": "00:00", "closesAt": "23:59"}]'::jsonb
                )
                WHERE key = 'operational'
            """);
            log.info("Ensured dev opening hours are set to 00:00-23:59");
        } catch (Exception e) {
            log.warn("Could not update dev opening hours: {}", e.getMessage());
        }
    }

    private void seedAccount(String code, String email, String fullName, String role) {
        if (userRepository.existsByCode(code) || userRepository.existsByEmail(email)) {
            log.info("Dev account {} ({}) already exists, skipping seed", code, email);
            return;
        }

        User user = new User();
        user.setCode(code);
        user.setEmail(email);
        user.setFullName(fullName);
        user.setRole(role);
        user.setStatus("ACTIVE");
        user.setMustChangePassword(false);
        user.setPasswordHash(passwordEncoder.encode(devSeedPassword));
        user.setAuthVersion(0L);
        user.setBiometricVersion(0L);

        userRepository.save(user);
        log.info("Seeded dev account: {} ({}) with role {}", code, email, role);
    }
}
