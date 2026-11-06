package com.library.checkin.service;

import java.util.Optional;

/**
 * Video containers accepted for a face clip. Detected from the leading bytes, never from the
 * client-supplied name or content type: MP4 comes from mobile cameras, WebM from browsers.
 */
public enum VideoContainer {
    MP4("clip.mp4", "video/mp4"),
    WEBM("clip.webm", "video/webm");

    private final String filename;
    private final String mimeType;

    VideoContainer(String filename, String mimeType) {
        this.filename = filename;
        this.mimeType = mimeType;
    }

    public String filename() {
        return filename;
    }

    public String mimeType() {
        return mimeType;
    }

    public static Optional<VideoContainer> detect(byte[] bytes) {
        if (bytes == null) {
            return Optional.empty();
        }
        // MP4: box size (4 bytes) then 'ftyp'.
        if (bytes.length >= 8 && bytes[4] == 'f' && bytes[5] == 't' && bytes[6] == 'y' && bytes[7] == 'p') {
            return Optional.of(MP4);
        }
        // WebM / Matroska: EBML magic 1A 45 DF A3.
        if (bytes.length >= 4 && bytes[0] == 0x1A && bytes[1] == 0x45
                && bytes[2] == (byte) 0xDF && bytes[3] == (byte) 0xA3) {
            return Optional.of(WEBM);
        }
        return Optional.empty();
    }
}
