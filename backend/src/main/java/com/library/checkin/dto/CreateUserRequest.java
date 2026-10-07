package com.library.checkin.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public record CreateUserRequest(
        @NotBlank(message = "Code is required")
        @Size(max = 50)
        @Pattern(regexp = "^[^@]+$", message = "Code must not contain @ symbol")
        String code,

        @NotBlank(message = "Email is required")
        @Email(message = "Valid email is required")
        @Size(max = 254)
        String email,

        @NotBlank(message = "Full name is required")
        @Size(max = 255)
        String fullName,

        @NotBlank(message = "Role is required")
        @Pattern(regexp = "^(STUDENT|LIBRARIAN|ADMIN)$", message = "Role must be STUDENT, LIBRARIAN, or ADMIN")
        String role,

        @NotBlank(message = "Password is required")
        @Size(min = 8, max = 64)
        String password,

        Boolean mustChangePassword
) {}
