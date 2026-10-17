package com.library.checkin.controller;

import com.library.checkin.dto.StudentLookup;
import com.library.checkin.service.AccessService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/students")
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Access")
public class StudentLookupController {

    private final AccessService accessService;

    public StudentLookupController(AccessService accessService) {
        this.accessService = accessService;
    }

    @GetMapping("/lookup")
    @PreAuthorize("hasAnyRole('LIBRARIAN', 'ADMIN')")
    @Operation(
            operationId = "lookupStudent",
            summary = "Look up a student by account code",
            description = "Resolves a student code (e.g. SV002) to the id required by POST /access/manual, "
                    + "with account status and current presence. Non-student accounts return 404."
    )
    public ResponseEntity<StudentLookup> lookupStudent(@RequestParam("code") String code) {
        return ResponseEntity.ok(accessService.lookupStudent(code));
    }
}
