package com.library.checkin.service;

import com.library.checkin.dto.*;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.RefreshTokenRepository;
import com.library.checkin.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final AuthService authService;

    @Transactional(readOnly = true)
    public UserPage listUsers(String query, String role, String status, int page, int size, String sortParam) {
        Sort sort = Sort.by(Sort.Direction.DESC, "createdAt");
        if ("code,asc".equalsIgnoreCase(sortParam)) {
            sort = Sort.by(Sort.Direction.ASC, "code");
        } else if ("fullName,asc".equalsIgnoreCase(sortParam)) {
            sort = Sort.by(Sort.Direction.ASC, "fullName");
        }

        int pageSize = Math.min(Math.max(size, 1), 100);
        int pageIndex = Math.max(page, 0);
        Pageable pageable = PageRequest.of(pageIndex, pageSize, sort);

        String trimmedQuery = (query != null && !query.trim().isEmpty()) ? query.trim() : null;
        String trimmedRole = (role != null && !role.trim().isEmpty()) ? role.trim() : null;
        String trimmedStatus = (status != null && !status.trim().isEmpty()) ? status.trim() : null;

        org.springframework.data.jpa.domain.Specification<User> spec = (root, q, cb) -> cb.conjunction();
        if (trimmedRole != null) {
            spec = spec.and((root, q, cb) -> cb.equal(root.get("role"), trimmedRole));
        }
        if (trimmedStatus != null) {
            spec = spec.and((root, q, cb) -> cb.equal(root.get("status"), trimmedStatus));
        }
        if (trimmedQuery != null) {
            String pattern = "%" + trimmedQuery.toLowerCase() + "%";
            spec = spec.and((root, q, cb) -> cb.or(
                    cb.like(cb.lower(root.get("code")), pattern),
                    cb.like(cb.lower(root.get("email")), pattern),
                    cb.like(cb.lower(root.get("fullName")), pattern)
            ));
        }

        Page<User> userPage = userRepository.findAll(spec, pageable);
        List<UserDto> dtos = userPage.getContent().stream()
                .map(authService::toUserDto)
                .toList();

        return new UserPage(dtos, userPage.getNumber(), userPage.getSize(), userPage.getTotalElements(), userPage.getTotalPages());
    }

    @Transactional
    public UserDto createUser(CreateUserRequest req) {
        String code = req.code().trim().toUpperCase();
        String email = req.email().trim().toLowerCase();

        if (code.contains("@")) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "User code must not contain @ symbol");
        }

        if (userRepository.existsByCode(code)) {
            throw new ApiException(HttpStatus.CONFLICT, "CODE_EXISTS", "User code already exists");
        }

        if (userRepository.existsByEmail(email)) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_EXISTS", "User email already exists");
        }

        if (req.password().getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Password exceeds 72 UTF-8 bytes");
        }

        User user = new User();
        user.setCode(code);
        user.setEmail(email);
        user.setFullName(req.fullName().trim());
        user.setRole(req.role());
        user.setStatus("ACTIVE");
        user.setMustChangePassword(req.mustChangePassword() != null ? req.mustChangePassword() : true);
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setAuthVersion(0L);
        user.setBiometricVersion(0L);

        user = userRepository.save(user);
        return authService.toUserDto(user);
    }

    @Transactional(readOnly = true)
    public UserDto getUser(UUID userId) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));
        return authService.toUserDto(user);
    }

    @Transactional
    public UserDto updateUser(UUID userId, PatchUserRequest req) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));

        if (!user.getVersion().equals(req.version())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Stale version: expected " + user.getVersion() + ", got " + req.version());
        }

        boolean authInvalidated = false;

        if (req.code() != null) {
            String newCode = req.code().trim().toUpperCase();
            if (newCode.contains("@")) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Code must not contain @");
            }
            if (!newCode.equalsIgnoreCase(user.getCode())) {
                if (userRepository.existsByCode(newCode)) {
                    throw new ApiException(HttpStatus.CONFLICT, "CODE_EXISTS", "Code already exists");
                }
                user.setCode(newCode);
            }
        }

        if (req.email() != null) {
            String newEmail = req.email().trim().toLowerCase();
            if (!newEmail.equalsIgnoreCase(user.getEmail())) {
                if (userRepository.existsByEmail(newEmail)) {
                    throw new ApiException(HttpStatus.CONFLICT, "EMAIL_EXISTS", "Email already exists");
                }
                user.setEmail(newEmail);
            }
        }

        if (req.fullName() != null && !req.fullName().trim().isEmpty()) {
            user.setFullName(req.fullName().trim());
        }

        // Check last active Admin protection
        if ("ADMIN".equalsIgnoreCase(user.getRole()) && "ACTIVE".equalsIgnoreCase(user.getStatus())) {
            boolean demoting = req.role() != null && !"ADMIN".equalsIgnoreCase(req.role());
            boolean locking = req.status() != null && !"ACTIVE".equalsIgnoreCase(req.status());
            if (demoting || locking) {
                long activeAdminCount = userRepository.countByRoleAndStatus("ADMIN", "ACTIVE");
                if (activeAdminCount <= 1) {
                    throw new ApiException(HttpStatus.CONFLICT, "LAST_ADMIN_PROTECTED", "Cannot demote or lock the last active Admin");
                }
            }
        }

        // Check student open session when role changes
        if (req.role() != null && !req.role().equalsIgnoreCase(user.getRole())) {
            if ("STUDENT".equalsIgnoreCase(user.getRole()) && userRepository.hasOpenSession(user.getId())) {
                throw new ApiException(HttpStatus.CONFLICT, "USER_HAS_OPEN_SESSION", "Cannot change role of a student with an open library session");
            }
            user.setRole(req.role());
            authInvalidated = true;
        }

        if (req.status() != null && !req.status().equalsIgnoreCase(user.getStatus())) {
            user.setStatus(req.status());
            authInvalidated = true;
        }

        if (authInvalidated) {
            user.setAuthVersion(user.getAuthVersion() + 1);
            refreshTokenRepository.revokeAllForUser(user.getId(), OffsetDateTime.now());
        }

        user = userRepository.save(user);
        return authService.toUserDto(user);
    }

    @Transactional
    public UserDto resetPassword(UUID userId, ResetPasswordRequest req) {
        User user = userRepository.findById(userId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "User not found"));

        if (!user.getVersion().equals(req.version())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Stale version: expected " + user.getVersion() + ", got " + req.version());
        }

        if (req.newPassword().getBytes(StandardCharsets.UTF_8).length > 72) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Password exceeds 72 UTF-8 bytes");
        }

        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        user.setMustChangePassword(true);
        user.setAuthVersion(user.getAuthVersion() + 1);
        refreshTokenRepository.revokeAllForUser(user.getId(), OffsetDateTime.now());

        user = userRepository.save(user);
        return authService.toUserDto(user);
    }
}
