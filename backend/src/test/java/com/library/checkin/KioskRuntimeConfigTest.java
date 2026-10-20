package com.library.checkin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.entity.Kiosk;
import com.library.checkin.repository.KioskRepository;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.KioskService;
import com.library.checkin.service.SystemConfigService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import java.util.Optional;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class KioskRuntimeConfigTest {
    @Mock KioskRepository kiosks;
    @Mock SystemConfigService configuration;
    @InjectMocks KioskService service;

    @Test
    void faceIsAvailableOnlyWithCompleteCalibration() throws Exception {
        var id = UUID.randomUUID();
        var principal = mock(CurrentPrincipal.class);
        when(principal.id()).thenReturn(id);
        var kiosk = new Kiosk();
        kiosk.setId(id);
        kiosk.setMode("ENTRY");
        kiosk.setStatus("ACTIVE");
        when(kiosks.findById(id)).thenReturn(Optional.of(kiosk));
        var mapper = new ObjectMapper();
        when(configuration.getOperational()).thenReturn(mapper.readValue("{}", SystemConfig.class));
        assertFalse(service.getRuntimeConfig(principal).faceEnabled());
        when(configuration.getOperational()).thenReturn(mapper.readValue("""
            {"faceModelVersion":"arcface-v1","faceMaxCosineDistance":0.65,
             "faceMinDistanceGap":0.1,"livenessMinScore":0.8}
            """, SystemConfig.class));
        assertTrue(service.getRuntimeConfig(principal).faceEnabled());
        when(configuration.getOperational()).thenReturn(mapper.readValue(
                "{\"faceModelVersion\":\"arcface-v1\"}", SystemConfig.class));
        assertFalse(service.getRuntimeConfig(principal).faceEnabled());
    }
}
