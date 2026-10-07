package com.library.checkin.controller;

import com.library.checkin.dto.Occupancy;
import com.library.checkin.dto.OccupantPage;
import com.library.checkin.exception.ApiException;
import com.library.checkin.service.OccupancyStateService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/occupancy")
@Tag(name = "Occupancy")
public class OccupancyController {

    private final OccupancyStateService occupancyStateService;

    public OccupancyController(OccupancyStateService occupancyStateService) {
        this.occupancyStateService = occupancyStateService;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @Operation(operationId = "getOccupancy")
    public ResponseEntity<Occupancy> getOccupancy() {
        return ResponseEntity.ok(occupancyStateService.snapshot());
    }

    @GetMapping("/people")
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @Operation(operationId = "listOccupants")
    public ResponseEntity<OccupantPage> listOccupants(
            @RequestParam(name = "page", defaultValue = "0") int page,
            @RequestParam(name = "size", defaultValue = "20") int size,
            @RequestParam(name = "q", required = false) String q,
            @RequestParam(name = "kind", required = false) String kind
    ) {
        if (kind != null && !kind.isBlank()) {
            String upper = kind.trim().toUpperCase();
            if (!upper.equals("USER") && !upper.equals("VISITOR")) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid kind parameter: " + kind);
            }
            kind = upper;
        } else {
            kind = null;
        }

        OccupantPage pageResult = occupancyStateService.listOccupants(page, size, q, kind);
        return ResponseEntity.ok(pageResult);
    }
}
