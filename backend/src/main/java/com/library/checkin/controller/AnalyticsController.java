package com.library.checkin.controller;

import com.library.checkin.dto.AccessAnalytics;
import com.library.checkin.dto.RecognitionAnalytics;
import com.library.checkin.service.AnalyticsService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.OffsetDateTime;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/analytics")
@Tag(name = "Analytics")
public class AnalyticsController {

    private final AnalyticsService analyticsService;

    public AnalyticsController(AnalyticsService analyticsService) {
        this.analyticsService = analyticsService;
    }

    @GetMapping("/access")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "getAccessAnalytics", summary = "getAccessAnalytics")
    public ResponseEntity<AccessAnalytics> getAccessAnalytics(
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(name = "bucket", defaultValue = "DAY") String bucket
    ) {
        AccessAnalytics analytics = analyticsService.getAccessAnalytics(from, to, bucket);
        return ResponseEntity.ok(analytics);
    }

    @GetMapping("/recognition")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "getRecognitionAnalytics", summary = "getRecognitionAnalytics")
    public ResponseEntity<RecognitionAnalytics> getRecognitionAnalytics(
            @RequestParam("from") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam("to") @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(name = "kioskId", required = false) UUID kioskId
    ) {
        RecognitionAnalytics analytics = analyticsService.getRecognitionAnalytics(from, to, kioskId);
        return ResponseEntity.ok(analytics);
    }
}
