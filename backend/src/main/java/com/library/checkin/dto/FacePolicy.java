package com.library.checkin.dto;

public record FacePolicy(
        String version,
        String title,
        String content,
        FaceCaptureRules captureRules
) {}
