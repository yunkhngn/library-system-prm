package com.library.checkin.controller;

import com.library.checkin.dto.CreateVisitorRequest;
import com.library.checkin.dto.VisitorDto;
import com.library.checkin.dto.VisitorPage;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.VisitorService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/visitors")
@Tag(name = "Visitors")
public class VisitorController {

    private final VisitorService visitorService;

    public VisitorController(VisitorService visitorService) {
        this.visitorService = visitorService;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @Operation(operationId = "listVisitors")
    public ResponseEntity<VisitorPage> listVisitors(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "q", required = false) String q,
            @RequestParam(name = "sort", defaultValue = "createdAt,desc") String sort
    ) {
        VisitorPage result = visitorService.listVisitors(page, size, q, sort);
        return ResponseEntity.ok(result);
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @Operation(operationId = "createVisitor")
    public ResponseEntity<VisitorDto> createVisitor(
            @Valid @RequestBody CreateVisitorRequest request,
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        VisitorDto created = visitorService.createVisitor(request, principal.getUserId());
        return ResponseEntity
                .created(URI.create("/api/v1/visitors/" + created.id()))
                .body(created);
    }

    @GetMapping("/{visitorId}")
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @Operation(operationId = "getVisitor")
    public ResponseEntity<VisitorDto> getVisitor(@PathVariable("visitorId") UUID visitorId) {
        VisitorDto visitor = visitorService.getVisitor(visitorId);
        return ResponseEntity.ok(visitor);
    }
}
