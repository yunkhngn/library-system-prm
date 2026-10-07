package com.library.checkin;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.testcontainers.containers.PostgreSQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import static org.junit.jupiter.api.Assertions.*;

@Testcontainers
class DatabaseMigrationIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("pgvector/pgvector:pg16")
            .withDatabaseName("library_test")
            .withUsername("test_user")
            .withPassword("test_pass");

    private static Flyway flyway;

    @BeforeAll
    static void setUp() {
        flyway = Flyway.configure()
                .dataSource(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())
                .locations("classpath:db/migration")
                .cleanDisabled(false)
                .load();
    }

    @Test
    @DisplayName("Migrations should apply cleanly and be idempotent on second run")
    void testMigrationsRunIdempotently() {
        flyway.clean();
        var result1 = flyway.migrate();
        assertTrue(result1.migrationsExecuted >= 3, "Expected at least V1, V2, V3 migrations");

        var result2 = flyway.migrate();
        assertEquals(0, result2.migrationsExecuted, "Second migration run should execute 0 new migrations");
    }

    @Test
    @DisplayName("Extensions vector and btree_gist must be enabled")
    void testExtensionsInstalled() throws SQLException {
        flyway.migrate();
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
             Statement stmt = conn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT extname FROM pg_extension WHERE extname IN ('vector', 'btree_gist')")) {
            int count = 0;
            while (rs.next()) {
                count++;
            }
            assertEquals(2, count, "Both vector and btree_gist extensions must exist");
        }
    }

    @Test
    @DisplayName("Database must reject two open sessions for the same user")
    void testPreventTwoOpenUserSessions() throws SQLException {
        flyway.migrate();
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
            conn.setAutoCommit(false);
            // Insert user and kiosk
            try (PreparedStatement psUser = conn.prepareStatement(
                    "INSERT INTO users (id, code, email, password_hash, full_name, role) " +
                    "VALUES ('00000000-0000-0000-0000-000000000001', 'STU001', 'stu@test.com', 'hash', 'Student 1', 'STUDENT')");
                 PreparedStatement psKiosk = conn.prepareStatement(
                    "INSERT INTO kiosks (id, code, name, mode, status) " +
                    "VALUES ('00000000-0000-0000-0000-000000000099', 'KSK01', 'Kiosk 1', 'AUTO', 'ACTIVE')")) {
                psUser.executeUpdate();
                psKiosk.executeUpdate();
            }

            // Insert first open session
            try (PreparedStatement psLog1 = conn.prepareStatement(
                    "INSERT INTO checkin_logs (id, user_id, method, kiosk_id, check_in_time) " +
                    "VALUES ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'QR', '00000000-0000-0000-0000-000000000099', NOW())")) {
                psLog1.executeUpdate();
            }

            // Attempt second open session for the same user
            try (PreparedStatement psLog2 = conn.prepareStatement(
                    "INSERT INTO checkin_logs (id, user_id, method, kiosk_id, check_in_time) " +
                    "VALUES ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'QR', '00000000-0000-0000-0000-000000000099', NOW())")) {
                assertThrows(SQLException.class, psLog2::executeUpdate, "Should reject second open session for same user");
            }
            conn.rollback();
        }
    }

    @Test
    @DisplayName("Database must reject overlapping active shift assignments for same staff")
    void testPreventOverlappingShiftAssignments() throws SQLException {
        flyway.migrate();
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword())) {
            conn.setAutoCommit(false);
            // Insert staff & admin
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO users (id, code, email, password_hash, full_name, role) VALUES " +
                    "('00000000-0000-0000-0000-000000000002', 'LIB001', 'lib@test.com', 'hash', 'Librarian 1', 'LIBRARIAN')," +
                    "('00000000-0000-0000-0000-000000000003', 'ADM001', 'adm@test.com', 'hash', 'Admin 1', 'ADMIN')")) {
                ps.executeUpdate();
            }

            // Insert two shifts
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO shifts (id, name, starts_at, ends_at, created_by) VALUES " +
                    "('20000000-0000-0000-0000-000000000001', 'Morning', '2026-10-08 08:00:00+00', '2026-10-08 12:00:00+00', '00000000-0000-0000-0000-000000000003')," +
                    "('20000000-0000-0000-0000-000000000002', 'Overlap', '2026-10-08 10:00:00+00', '2026-10-08 14:00:00+00', '00000000-0000-0000-0000-000000000003')," +
                    "('20000000-0000-0000-0000-000000000003', 'Adjacent', '2026-10-08 12:00:00+00', '2026-10-08 16:00:00+00', '00000000-0000-0000-0000-000000000003')")) {
                ps.executeUpdate();
            }

            // First assignment: 08:00 - 12:00
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO shift_assignments (id, shift_id, staff_id, starts_at, ends_at, assigned_by) VALUES " +
                    "('30000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', '2026-10-08 08:00:00+00', '2026-10-08 12:00:00+00', '00000000-0000-0000-0000-000000000003')")) {
                ps.executeUpdate();
            }

            // Adjacent assignment: 12:00 - 16:00 (MUST SUCCEED)
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO shift_assignments (id, shift_id, staff_id, starts_at, ends_at, assigned_by) VALUES " +
                    "('30000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', '2026-10-08 12:00:00+00', '2026-10-08 16:00:00+00', '00000000-0000-0000-0000-000000000003')")) {
                assertDoesNotThrow(() -> { ps.executeUpdate(); }, "Adjacent shifts must be permitted");
            }

            // Overlapping assignment: 10:00 - 14:00 (MUST FAIL)
            try (PreparedStatement ps = conn.prepareStatement(
                    "INSERT INTO shift_assignments (id, shift_id, staff_id, starts_at, ends_at, assigned_by) VALUES " +
                    "('30000000-0000-0000-0000-000000000003', '20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '2026-10-08 10:00:00+00', '2026-10-08 14:00:00+00', '00000000-0000-0000-0000-000000000003')")) {
                assertThrows(SQLException.class, ps::executeUpdate, "Overlapping shift assignment must be rejected");
            }

            conn.rollback();
        }
    }

    @Test
    @DisplayName("AI service role can SELECT from ai_face_candidates view but cannot read users table")
    void testAiRolePermissions() throws SQLException {
        flyway.migrate();
        try (Connection conn = DriverManager.getConnection(postgres.getJdbcUrl(), postgres.getUsername(), postgres.getPassword());
             Statement stmt = conn.createStatement()) {

            stmt.execute("DO $$\n" +
                    "BEGIN\n" +
                    "    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ai_service_user') THEN\n" +
                    "        CREATE ROLE ai_service_user WITH LOGIN PASSWORD 'ai_service_secure_password';\n" +
                    "    END IF;\n" +
                    "END\n" +
                    "$$;");
            stmt.execute("GRANT USAGE ON SCHEMA public TO ai_service_user;");
            stmt.execute("REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ai_service_user;");
            stmt.execute("GRANT SELECT ON ai_face_candidates TO ai_service_user;");
        }

        try (Connection aiConn = DriverManager.getConnection(postgres.getJdbcUrl(), "ai_service_user", "ai_service_secure_password");
             Statement aiStmt = aiConn.createStatement()) {

            assertDoesNotThrow(() -> {
                try (ResultSet rs = aiStmt.executeQuery("SELECT * FROM ai_face_candidates LIMIT 1")) {
                    // Success
                }
            }, "AI role should be allowed to SELECT from ai_face_candidates view");

            assertThrows(SQLException.class, () -> {
                aiStmt.executeQuery("SELECT password_hash FROM users LIMIT 1");
            }, "AI role must be denied direct SELECT on users table");
        }
    }
}
