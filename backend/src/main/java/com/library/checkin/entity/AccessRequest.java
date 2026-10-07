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
@Table(name = "access_requests")
@Getter
@Setter
@NoArgsConstructor
public class AccessRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "principal_type", length = 20, nullable = false)
    private String principalType; // USER, KIOSK

    @Column(name = "principal_id", nullable = false)
    private UUID principalId;

    @Column(name = "idempotency_key", nullable = false)
    private UUID idempotencyKey;

    @Column(name = "request_method", length = 10, nullable = false)
    private String requestMethod;

    @Column(name = "request_path", length = 255, nullable = false)
    private String requestPath;

    @Column(name = "request_digest", length = 64, nullable = false)
    private String requestDigest;

    @Column(name = "status", length = 20, nullable = false)
    private String status = "IN_PROGRESS"; // IN_PROGRESS, COMPLETED

    @Column(name = "response_status")
    private Integer responseStatus;

    @Column(name = "response_body", columnDefinition = "jsonb")
    @JdbcTypeCode(SqlTypes.JSON)
    private String responseBody;

    @Column(name = "created_at", nullable = false)
    private OffsetDateTime createdAt = OffsetDateTime.now();

    @Column(name = "processing_deadline", nullable = false)
    private OffsetDateTime processingDeadline;

    @Column(name = "expires_at", nullable = false)
    private OffsetDateTime expiresAt;
}
