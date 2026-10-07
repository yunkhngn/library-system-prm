package com.library.checkin.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "kiosks")
@Getter
@Setter
@NoArgsConstructor
public class Kiosk {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "code", length = 50, nullable = false, unique = true)
    private String code;

    @Column(name = "name", length = 100, nullable = false)
    private String name;

    @Column(name = "mode", length = 20, nullable = false)
    private String mode = "AUTO"; // ENTRY, EXIT, AUTO

    @Column(name = "status", length = 20, nullable = false)
    private String status = "ACTIVE"; // ACTIVE, REVOKED

    @Column(name = "credential_hash", length = 255)
    private String credentialHash;

    @Column(name = "credential_version", nullable = false)
    private Long credentialVersion = 0L;

    @Column(name = "last_seen_at")
    private OffsetDateTime lastSeenAt;

    @Column(name = "app_version", length = 50)
    private String appVersion;

    @Column(name = "camera_status", length = 50)
    private String cameraStatus;

    @Version
    @Column(name = "version", nullable = false)
    private Long version = 0L;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "updated_at", nullable = false)
    private OffsetDateTime updatedAt = OffsetDateTime.now();

    public boolean isOnline() {
        if (!"ACTIVE".equalsIgnoreCase(status) || lastSeenAt == null) {
            return false;
        }
        return lastSeenAt.isAfter(OffsetDateTime.now().minusSeconds(90));
    }

    @PrePersist
    @PreUpdate
    public void normalize() {
        if (code != null) {
            code = code.trim().toUpperCase();
        }
        if (name != null) {
            name = name.trim();
        }
        updatedAt = OffsetDateTime.now();
    }
}
