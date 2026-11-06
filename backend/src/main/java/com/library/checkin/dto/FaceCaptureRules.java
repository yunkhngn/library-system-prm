package com.library.checkin.dto;

import java.util.List;

public record FaceCaptureRules(
        List<String> imageMimeTypes,
        int minImages,
        int maxImages,
        long maxImageBytes,
        long maxTotalImageBytes,
        long maxImagePixels,
        List<String> clipMimeTypes,
        long maxClipBytes,
        double minClipDurationSeconds,
        double maxClipDurationSeconds,
        int maxClipFps,
        int maxClipWidth,
        int maxClipHeight
) {
    public static FaceCaptureRules defaultRules() {
        return new FaceCaptureRules(
                List.of("image/jpeg", "image/png"),
                3,
                5,
                5242880L,
                26214400L,
                16000000L,
                List.of("video/mp4", "video/webm"),
                10485760L,
                1.0,
                3.0,
                30,
                1280,
                720
        );
    }
}
