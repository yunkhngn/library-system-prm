package com.library.checkin.controller;

import com.library.checkin.dto.*;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.KioskService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/kiosks")
@RequiredArgsConstructor
@Tag(name = "Kiosks")
public class KioskController {

    private final KioskService kioskService;

    @Operation(summary = "listKiosks", operationId = "listKiosks")
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping
    public ResponseEntity<KioskPage> listKiosks(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) Boolean isOnline,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt,desc") String sort
    ) {
        return ResponseEntity.ok(kioskService.listKiosks(q, status, isOnline, page, size, sort));
    }

    @Operation(summary = "createKiosk", operationId = "createKiosk")
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public ResponseEntity<KioskCredential> createKiosk(@Valid @RequestBody CreateKioskRequest req) {
        KioskCredential credential = kioskService.createKiosk(req);
        return ResponseEntity.created(URI.create("/api/v1/kiosks/" + credential.kiosk().id()))
                .body(credential);
    }

    @Operation(summary = "getKiosk", operationId = "getKiosk")
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @GetMapping("/{kioskId}")
    public ResponseEntity<KioskDto> getKiosk(@PathVariable UUID kioskId) {
        return ResponseEntity.ok(kioskService.getKiosk(kioskId));
    }

    @Operation(summary = "updateKiosk", operationId = "updateKiosk")
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @PatchMapping("/{kioskId}")
    public ResponseEntity<KioskDto> updateKiosk(
            @PathVariable UUID kioskId,
            @Valid @RequestBody PatchKioskRequest req
    ) {
        return ResponseEntity.ok(kioskService.updateKiosk(kioskId, req));
    }

    @Operation(summary = "rotateKioskCredential", operationId = "rotateKioskCredential")
    @SecurityRequirement(name = "bearerAuth")
    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping("/{kioskId}/rotate-credential")
    public ResponseEntity<KioskCredential> rotateCredential(
            @PathVariable UUID kioskId,
            @Valid @RequestBody VersionRequest req
    ) {
        return ResponseEntity.ok(kioskService.rotateCredential(kioskId, req));
    }

    @Operation(summary = "loginKiosk", operationId = "loginKiosk")
    @PostMapping("/token")
    public ResponseEntity<KioskToken> loginKiosk(@Valid @RequestBody KioskLoginRequest req) {
        return ResponseEntity.ok(kioskService.loginKiosk(req));
    }

    @Operation(summary = "heartbeatKiosk", operationId = "heartbeatKiosk")
    @SecurityRequirement(name = "kioskAuth")
    @PreAuthorize("hasRole('KIOSK')")
    @PostMapping("/heartbeat")
    public ResponseEntity<HeartbeatResult> heartbeat(
            @AuthenticationPrincipal CurrentPrincipal principal,
            @Valid @RequestBody HeartbeatRequest req
    ) {
        return ResponseEntity.ok(kioskService.heartbeat(principal, req));
    }

    @Operation(summary = "getKioskRuntimeConfig", operationId = "getKioskRuntimeConfig")
    @SecurityRequirement(name = "kioskAuth")
    @PreAuthorize("hasRole('KIOSK')")
    @GetMapping("/me/config")
    public ResponseEntity<KioskRuntimeConfig> getRuntimeConfig(@AuthenticationPrincipal CurrentPrincipal principal) {
        return ResponseEntity.ok(kioskService.getRuntimeConfig(principal));
    }
}
