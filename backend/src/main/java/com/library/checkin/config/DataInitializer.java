package com.library.checkin.config;

import com.library.checkin.entity.User;
import com.library.checkin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Component
@Profile("dev")
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private static final List<SeedUser> CORE_ACCOUNTS = List.of(
            new SeedUser("AD001", "admin@example.test", "Hoàng Văn Nam", "ADMIN"),
            new SeedUser("LIB001", "librarian@example.test", "Lê Thu Trang", "LIBRARIAN"),
            new SeedUser("SV001", "student@example.test", "Nguyễn Thị Huyền", "STUDENT"),
            new SeedUser("SV002", "student2@example.test", "Trần Minh Quân", "STUDENT"),
            new SeedUser("SV003", "student3@example.test", "Lê Hoàng Long", "STUDENT")
    );

    // Contract tests pick the newest librarians for shift assignment, so these must stay disabled there.
    private static final List<SeedUser> SAMPLE_ACCOUNTS = List.of(
            new SeedUser("AD002", "duc.tm@staff.example.test", "Trịnh Minh Đức", "ADMIN"),

            new SeedUser("LIB002", "bao.pq@staff.example.test", "Phạm Quốc Bảo", "LIBRARIAN"),
            new SeedUser("LIB003", "mai.dt@staff.example.test", "Đỗ Thị Mai", "LIBRARIAN", "LOCKED", false),
            new SeedUser("LIB004", "yen.nh@staff.example.test", "Nguyễn Hải Yến", "LIBRARIAN"),

            new SeedUser("SV004", "han.pg@sv.example.test", "Phạm Gia Hân", "STUDENT"),
            new SeedUser("SV005", "linh.vk@sv.example.test", "Vũ Khánh Linh", "STUDENT"),
            new SeedUser("SV006", "huy.dq@sv.example.test", "Đặng Quốc Huy", "STUDENT"),
            new SeedUser("SV007", "tam.bt@sv.example.test", "Bùi Thanh Tâm", "STUDENT"),
            new SeedUser("SV008", "anh.hn@sv.example.test", "Hồ Ngọc Ánh", "STUDENT"),
            new SeedUser("SV009", "khoa.nm@sv.example.test", "Ngô Minh Khoa", "STUDENT"),
            new SeedUser("SV010", "dung.dt@sv.example.test", "Dương Thùy Dung", "STUDENT"),
            new SeedUser("SV011", "bao.lg@sv.example.test", "Lý Gia Bảo", "STUDENT"),
            new SeedUser("SV012", "anh.mp@sv.example.test", "Mai Phương Anh", "STUDENT"),
            new SeedUser("SV013", "danh.tc@sv.example.test", "Trương Công Danh", "STUDENT"),
            new SeedUser("SV014", "ha.dtn@sv.example.test", "Đinh Thị Ngọc Hà", "STUDENT"),
            new SeedUser("SV015", "minh.pn@sv.example.test", "Phan Nhật Minh", "STUDENT"),
            new SeedUser("SV016", "nhi.lt@sv.example.test", "Lâm Tuệ Nhi", "STUDENT"),
            new SeedUser("SV017", "phuc.ch@sv.example.test", "Châu Hoàng Phúc", "STUDENT"),
            new SeedUser("SV018", "vinh.tq@sv.example.test", "Tạ Quang Vinh", "STUDENT"),
            new SeedUser("SV019", "lan.kt@sv.example.test", "Kiều Thị Lan", "STUDENT"),
            new SeedUser("SV020", "phat.ht@sv.example.test", "Huỳnh Tấn Phát", "STUDENT", "LOCKED", false),
            new SeedUser("SV021", "duyen.ctm@sv.example.test", "Cao Thị Mỹ Duyên", "STUDENT", "ACTIVE", true),
            new SeedUser("SV047", "thao.tntp@sv.example.test", "Tôn Nữ Thị Phương Thảo", "STUDENT")
    );

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JdbcTemplate jdbcTemplate;

    @Value("${app.dev.seed-password:${DEV_SEED_PASSWORD:dev_secret_password_123}}")
    private String devSeedPassword;

    @Value("${app.dev.sample-users:true}")
    private boolean sampleUsersEnabled;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        CORE_ACCOUNTS.forEach(this::seedAccount);
        if (sampleUsersEnabled) {
            SAMPLE_ACCOUNTS.forEach(this::seedAccount);
        }
        ensureDevOpeningHours();
        log.info("Dev data initialization finished: {} users in database", userRepository.count());
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

    private void seedAccount(SeedUser seed) {
        if (userRepository.existsByCode(seed.code()) || userRepository.existsByEmail(seed.email())) {
            log.info("Dev account {} ({}) already exists, skipping seed", seed.code(), seed.email());
            return;
        }

        User user = new User();
        user.setCode(seed.code());
        user.setEmail(seed.email());
        user.setFullName(seed.fullName());
        user.setRole(seed.role());
        user.setStatus(seed.status());
        user.setMustChangePassword(seed.mustChangePassword());
        user.setPasswordHash(passwordEncoder.encode(devSeedPassword));
        user.setAuthVersion(0L);
        user.setBiometricVersion(0L);

        userRepository.save(user);
        log.info("Seeded dev account: {} ({}) with role {}", seed.code(), seed.email(), seed.role());
    }

    private record SeedUser(String code, String email, String fullName, String role,
                            String status, boolean mustChangePassword) {
        SeedUser(String code, String email, String fullName, String role) {
            this(code, email, fullName, role, "ACTIVE", false);
        }
    }
}
