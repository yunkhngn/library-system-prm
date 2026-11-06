package com.library.checkin;

import com.library.checkin.service.VideoContainer;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class VideoContainerTest {

    private static byte[] mp4() {
        return new byte[]{0, 0, 0, 0x20, 'f', 't', 'y', 'p', 'i', 's', 'o', 'm'};
    }

    private static byte[] webm() {
        return new byte[]{0x1A, 0x45, (byte) 0xDF, (byte) 0xA3, (byte) 0x9F, 0x42, (byte) 0x86, (byte) 0x81};
    }

    @Test
    void detectsMp4() {
        assertThat(VideoContainer.detect(mp4())).contains(VideoContainer.MP4);
    }

    @Test
    void detectsWebm() {
        assertThat(VideoContainer.detect(webm())).contains(VideoContainer.WEBM);
    }

    @Test
    void rejectsEverythingElse() {
        assertThat(VideoContainer.detect(null)).isEmpty();
        assertThat(VideoContainer.detect(new byte[0])).isEmpty();
        assertThat(VideoContainer.detect(new byte[]{0x1A, 0x45, (byte) 0xDF})).isEmpty();
        assertThat(VideoContainer.detect("not a video at all".getBytes())).isEmpty();
        assertThat(VideoContainer.detect(new byte[]{'R', 'I', 'F', 'F', 0, 0, 0, 0, 'A', 'V', 'I', ' '})).isEmpty();
    }

    @Test
    void exposesFilenameAndMimeType() {
        assertThat(VideoContainer.MP4.filename()).isEqualTo("clip.mp4");
        assertThat(VideoContainer.MP4.mimeType()).isEqualTo("video/mp4");
        assertThat(VideoContainer.WEBM.filename()).isEqualTo("clip.webm");
        assertThat(VideoContainer.WEBM.mimeType()).isEqualTo("video/webm");
    }
}
