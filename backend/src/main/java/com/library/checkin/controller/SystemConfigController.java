package com.library.checkin.controller;

import com.library.checkin.dto.PatchSystemConfigRequest;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.SystemConfigService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/system-config")
@Tag(name = "Configuration")
public class SystemConfigController {

    private final SystemConfigService systemConfigService;

    public SystemConfigController(SystemConfigService systemConfigService) {
        this.systemConfigService = systemConfigService;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN', 'LIBRARIAN')")
    @Operation(operationId = "getSystemConfig", summary = "getSystemConfig")
    public ResponseEntity<SystemConfig> getSystemConfig() {
        SystemConfig config = systemConfigService.getOperational();
        return ResponseEntity.ok(config);
    }

    @PatchMapping
    @PreAuthorize("hasRole('ADMIN')")
    @Operation(operationId = "updateSystemConfig", summary = "updateSystemConfig")
    public ResponseEntity<SystemConfig> updateSystemConfig(
            @Valid @RequestBody PatchSystemConfigRequest request,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        SystemConfig updated = systemConfigService.updateOperational(request, principal.getUserId());
        return ResponseEntity.ok(updated);
    }
}
