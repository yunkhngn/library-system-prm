package com.library.checkin.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "recognition_attempts")
@Getter
@Setter
@NoArgsConstructor
public class RecognitionAttempt {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(name = "access_request_id")
    private UUID accessRequestId;

    @Column(name = "kiosk_id", nullable = false)
    private UUID kioskId;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "outcome", length = 50, nullable = false)
    private String outcome;

    @Column(name = "model_version", length = 50, nullable = false)
    private String modelVersion;

    @Column(name = "cosine_distance")
    private Double cosineDistance;

    @Column(name = "liveness_score")
    private Double livenessScore;

    @Column(name = "latency_ms", nullable = false)
    private Integer latencyMs;

    @Column(name = "occurred_at", nullable = false)
    private OffsetDateTime occurredAt = OffsetDateTime.now();
}
