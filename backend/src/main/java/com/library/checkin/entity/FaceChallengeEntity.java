package com.library.checkin.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "face_challenges")
@Getter
@Setter
@NoArgsConstructor
public class FaceChallengeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "kiosk_id", nullable = false)
    private UUID kioskId;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "instructions", nullable = false, columnDefinition = "jsonb")
    private String instructions;

    @Column(name = "model_version", length = 50, nullable = false)
    private String modelVersion;

    @Column(name = "config_version", nullable = false)
    private Long configVersion;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;

    @Column(name = "consumed_at")
    private OffsetDateTime consumedAt;
}
