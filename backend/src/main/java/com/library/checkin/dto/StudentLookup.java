package com.library.checkin.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * Minimal student card for staff manual access (LIB-03). Deliberately omits
 * email and biometric data.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record StudentLookup(
        UUID id,
        String code,
        String fullName,
        String status, // ACTIVE, LOCKED
        @JsonProperty("isInside") boolean isInside,
        UUID currentSessionId,
        OffsetDateTime checkInTime
) {}
