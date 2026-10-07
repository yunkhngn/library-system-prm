package com.library.checkin.controller;

import com.library.checkin.dto.*;
import com.library.checkin.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.security.SecurityRequirement;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.net.URI;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@PreAuthorize("hasRole('ADMIN')")
@SecurityRequirement(name = "bearerAuth")
@Tag(name = "Users")
public class UserController {

    private final UserService userService;

    @Operation(summary = "listUsers", operationId = "listUsers")
    @GetMapping
    public ResponseEntity<UserPage> listUsers(
            @RequestParam(required = false) String q,
            @RequestParam(required = false) String role,
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt,desc") String sort
    ) {
        return ResponseEntity.ok(userService.listUsers(q, role, status, page, size, sort));
    }

    @Operation(summary = "createUser", operationId = "createUser")
    @PostMapping
    public ResponseEntity<UserDto> createUser(@Valid @RequestBody CreateUserRequest req) {
        UserDto created = userService.createUser(req);
        return ResponseEntity.created(URI.create("/api/v1/users/" + created.id())).body(created);
    }

    @Operation(summary = "getUser", operationId = "getUser")
    @GetMapping("/{userId}")
    public ResponseEntity<UserDto> getUser(@PathVariable UUID userId) {
        return ResponseEntity.ok(userService.getUser(userId));
    }

    @Operation(summary = "updateUser", operationId = "updateUser")
    @PatchMapping("/{userId}")
    public ResponseEntity<UserDto> updateUser(
            @PathVariable UUID userId,
            @Valid @RequestBody PatchUserRequest req
    ) {
        return ResponseEntity.ok(userService.updateUser(userId, req));
    }

    @Operation(summary = "resetUserPassword", operationId = "resetUserPassword")
    @PutMapping("/{userId}/password")
    public ResponseEntity<UserDto> resetUserPassword(
            @PathVariable UUID userId,
            @Valid @RequestBody ResetPasswordRequest req
    ) {
        return ResponseEntity.ok(userService.resetPassword(userId, req));
    }
}
