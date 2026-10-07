package com.library.checkin.dto;

public record TokenPair(
        String accessToken,
        String refreshToken,
        String tokenType,
        long expiresIn,
        UserDto user
) {}
