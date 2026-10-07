package com.library.checkin.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "users")
@Getter
@Setter
@NoArgsConstructor
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "code", length = 50, nullable = false, unique = true)
    private String code;

    @Column(name = "email", length = 255, nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", length = 255, nullable = false)
    private String passwordHash;

    @Column(name = "full_name", length = 255, nullable = false)
    private String fullName;

    @Column(name = "role", length = 20, nullable = false)
    private String role; // STUDENT, LIBRARIAN, ADMIN

    @Column(name = "status", length = 20, nullable = false)
    private String status = "ACTIVE"; // ACTIVE, LOCKED

    @Column(name = "must_change_password", nullable = false)
    private boolean mustChangePassword = false;

    @Column(name = "auth_version", nullable = false)
    private Long authVersion = 0L;

    @Column(name = "biometric_version", nullable = false)
    private Long biometricVersion = 0L;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    @Version
    @Column(name = "version", nullable = false)
    private Long version = 0L;

    @PrePersist
    @PreUpdate
    public void normalize() {
        if (code != null) {
            code = code.trim().toUpperCase();
        }
        if (email != null) {
            email = email.trim().toLowerCase();
        }
        updatedAt = OffsetDateTime.now();
    }
}
