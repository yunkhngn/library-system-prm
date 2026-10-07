package com.library.checkin.controller;

import com.library.checkin.dto.*;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.ShiftService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.time.OffsetDateTime;
import java.util.UUID;

@RestController
@Tag(name = "Shifts")
public class ShiftController {

    private final ShiftService shiftService;

    public ShiftController(ShiftService shiftService) {
        this.shiftService = shiftService;
    }

    @GetMapping("/api/v1/shifts")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "listShifts", summary = "listShifts")
    public ResponseEntity<ShiftPage> listShifts(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(name = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "staffId", required = false) UUID staffId,
            @RequestParam(name = "q", required = false) String q,
            @RequestParam(name = "sort", defaultValue = "startsAt,asc") String sort
    ) {
        ShiftPage result = shiftService.listShifts(page, size, from, to, status, staffId, q, sort);
        return ResponseEntity.ok(result);
    }

    @PostMapping("/api/v1/shifts")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "createShift", summary = "createShift")
    public ResponseEntity<ShiftDto> createShift(
            @Valid @RequestBody CreateShiftRequest request,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        ShiftDto created = shiftService.createShift(request, principal.getUserId());
        URI location = URI.create("/api/v1/shifts/" + created.id());
        return ResponseEntity.created(location).body(created);
    }

    @GetMapping("/api/v1/shifts/{shiftId}")
    @PreAuthorize("hasAnyRole('ADMIN', 'LIBRARIAN')")
    @Operation(operationId = "getShift", summary = "getShift")
    public ResponseEntity<ShiftDto> getShift(
            @PathVariable("shiftId") UUID shiftId,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        ShiftDto shift = shiftService.getShift(shiftId, principal);
        return ResponseEntity.ok(shift);
    }

    @PatchMapping("/api/v1/shifts/{shiftId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "updateShift", summary = "updateShift")
    public ResponseEntity<ShiftDto> updateShift(
            @PathVariable("shiftId") UUID shiftId,
            @Valid @RequestBody PatchShiftRequest request
    ) {
        ShiftDto updated = shiftService.patchShift(shiftId, request);
        return ResponseEntity.ok(updated);
    }

    @PostMapping("/api/v1/shifts/{shiftId}/cancel")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "cancelShift", summary = "cancelShift")
    public ResponseEntity<ShiftDto> cancelShift(
            @PathVariable("shiftId") UUID shiftId,
            @Valid @RequestBody CancelShiftRequest request
    ) {
        ShiftDto cancelled = shiftService.cancelShift(shiftId, request);
        return ResponseEntity.ok(cancelled);
    }

    @GetMapping("/api/v1/shifts/{shiftId}/assignments")
    @PreAuthorize("hasAnyRole('ADMIN', 'LIBRARIAN')")
    @Operation(operationId = "listShiftAssignments", summary = "listShiftAssignments")
    public ResponseEntity<AssignmentPage> listShiftAssignments(
            @PathVariable("shiftId") UUID shiftId,
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "sort", defaultValue = "createdAt,asc") String sort,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        AssignmentPage assignments = shiftService.listShiftAssignments(shiftId, page, size, status, sort, principal);
        return ResponseEntity.ok(assignments);
    }

    @PostMapping("/api/v1/shifts/{shiftId}/assignments")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "assignStaff", summary = "assignStaff")
    public ResponseEntity<AssignmentBatch> assignStaff(
            @PathVariable("shiftId") UUID shiftId,
            @Valid @RequestBody AssignStaffRequest request,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        AssignmentBatch batch = shiftService.assignStaff(shiftId, request, principal.getUserId());
        URI location = URI.create("/api/v1/shifts/" + shiftId + "/assignments");
        return ResponseEntity.created(location).body(batch);
    }

    @PatchMapping("/api/v1/shifts/{shiftId}/assignments/{assignmentId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "replaceAssignedStaff", summary = "replaceAssignedStaff")
    public ResponseEntity<AssignmentBatch> replaceAssignedStaff(
            @PathVariable("shiftId") UUID shiftId,
            @PathVariable("assignmentId") UUID assignmentId,
            @Valid @RequestBody PatchAssignmentRequest request,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        AssignmentBatch batch = shiftService.replaceAssignedStaff(shiftId, assignmentId, request, principal.getUserId());
        return ResponseEntity.ok(batch);
    }

    @DeleteMapping("/api/v1/shifts/{shiftId}/assignments/{assignmentId}")
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "cancelAssignment", summary = "cancelAssignment")
    public ResponseEntity<Void> cancelAssignment(
            @PathVariable("shiftId") UUID shiftId,
            @PathVariable("assignmentId") UUID assignmentId,
            @RequestParam("version") Long version
    ) {
        shiftService.cancelAssignment(shiftId, assignmentId, version);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/api/v1/me/shifts")
    @PreAuthorize("hasRole('LIBRARIAN')")
    @Operation(operationId = "listMyShifts", summary = "listMyShifts")
    public ResponseEntity<MyShiftPage> listMyShifts(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "from", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime from,
            @RequestParam(name = "to", required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime to,
            @RequestParam(name = "status", required = false) String status,
            @RequestParam(name = "sort", defaultValue = "startsAt,asc") String sort,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        MyShiftPage result = shiftService.listMyShifts(principal.getUserId(), page, size, from, to, status, sort);
        return ResponseEntity.ok(result);
    }
}
