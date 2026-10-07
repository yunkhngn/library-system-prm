package com.library.checkin.entity;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.OffsetDateTime;
import java.util.UUID;

@Entity
@Table(name = "checkin_logs")
@Getter
@Setter
@NoArgsConstructor
public class CheckinLog {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "user_id")
    private UUID userId;

    @Column(name = "visitor_id")
    private UUID visitorId;

    @Column(name = "method", length = 20, nullable = false)
    private String method; // FACE, QR, MANUAL

    @Column(name = "kiosk_id")
    private UUID kioskId;

    @Column(name = "performed_by")
    private UUID performedBy;

    @Column(name = "manual_reason", columnDefinition = "text")
    private String manualReason;

    @Column(name = "check_in_time", nullable = false)
    private OffsetDateTime checkInTime = OffsetDateTime.now();

    @Column(name = "scheduled_checkout_at")
    private OffsetDateTime scheduledCheckoutAt;

    @Column(name = "entry_config_version")
    private Long entryConfigVersion;

    @Column(name = "check_out_time")
    private OffsetDateTime checkOutTime;

    @Column(name = "check_out_method", length = 20)
    private String checkOutMethod;

    @Column(name = "check_out_kiosk_id")
    private UUID checkOutKioskId;

    @Column(name = "checked_out_by")
    private UUID checkedOutBy;

    @Column(name = "checkout_reason", length = 30)
    private String checkoutReason; // USER_ACTION, MANUAL, CLOSING_TIME, MAX_DURATION

    @Column(name = "checkout_manual_reason", columnDefinition = "text")
    private String checkoutManualReason;
}
