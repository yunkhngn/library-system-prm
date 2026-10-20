package com.library.checkin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.SystemConfig;
import com.library.checkin.dto.PatchSystemConfigRequest;
import com.library.checkin.exception.ApiException;
import com.library.checkin.entity.SystemConfigEntity;
import com.library.checkin.repository.SystemConfigRepository;
import com.library.checkin.service.SystemConfigService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.Spy;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.OffsetDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

@ExtendWith(MockitoExtension.class)
class SystemConfigServiceTest {

    @Mock
    private SystemConfigRepository repository;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private SystemConfigService service;

    private SystemConfigEntity calibratedEntity() {
        var entity = new SystemConfigEntity();
        entity.setKey("operational");
        entity.setVersion(4L);
        entity.setValue("""
            {"maxCapacity":300,"faceModelVersion":"arcface-v1",
             "faceMaxCosineDistance":0.65,"faceMinDistanceGap":0.1,"livenessMinScore":0.8}
            """);
        when(repository.findById("operational")).thenReturn(Optional.of(entity));
        return entity;
    }

    @Test
    void explicitResetClearsAllCalibrationAndPreservesOperationalSettings() throws Exception {
        calibratedEntity();
        when(repository.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));
        var request = objectMapper.readValue(
                "{\"version\":4,\"resetFaceConfiguration\":true}", PatchSystemConfigRequest.class);
        var result = service.updateOperational(request, null);
        assertNull(result.faceModelVersion());
        assertNull(result.faceMaxCosineDistance());
        assertNull(result.faceMinDistanceGap());
        assertNull(result.livenessMinScore());
        assertEquals(300, result.maxCapacity());
        assertEquals(5L, result.version());
    }

    @Test
    void omittedCalibrationPreservesExistingValues() throws Exception {
        calibratedEntity();
        when(repository.saveAndFlush(any())).thenAnswer(invocation -> invocation.getArgument(0));
        var request = objectMapper.readValue(
                "{\"version\":4,\"scanCooldownSeconds\":15}", PatchSystemConfigRequest.class);
        var result = service.updateOperational(request, null);
        assertEquals("arcface-v1", result.faceModelVersion());
        assertEquals(0.65, result.faceMaxCosineDistance());
        assertEquals(15, result.scanCooldownSeconds());
    }

    @Test
    void resetRejectsConflictingValuesAndStaleVersion() throws Exception {
        calibratedEntity();
        var conflicting = objectMapper.readValue(
                "{\"version\":4,\"resetFaceConfiguration\":true,\"faceModelVersion\":\"v2\"}",
                PatchSystemConfigRequest.class);
        assertThrows(ApiException.class, () -> service.updateOperational(conflicting, null));
        var stale = objectMapper.readValue(
                "{\"version\":3,\"resetFaceConfiguration\":true}", PatchSystemConfigRequest.class);
        assertThrows(ApiException.class, () -> service.updateOperational(stale, null));
        verify(repository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("getOperational should read and parse operational JSON configuration correctly")
    void testGetOperational() {
        String json = """
        {
            "timezone": "Asia/Ho_Chi_Minh",
            "openingHours": [
                {"dayOfWeek": 1, "opensAt": "08:00", "closesAt": "22:00"},
                {"dayOfWeek": 2, "opensAt": "08:00", "closesAt": "22:00"}
            ],
            "maxCapacity": 250,
            "nearCapacityRatio": 0.9,
            "capacityEnforcement": false,
            "maxSessionDurationMinutes": 120,
            "scanCooldownSeconds": 10,
            "faceModelVersion": null,
            "faceMaxCosineDistance": null,
            "faceMinDistanceGap": null,
            "livenessMinScore": null
        }
        """;

        SystemConfigEntity entity = new SystemConfigEntity();
        entity.setKey("operational");
        entity.setValue(json);
        entity.setVersion(1L);
        entity.setUpdatedAt(OffsetDateTime.now());

        when(repository.findById("operational")).thenReturn(Optional.of(entity));

        SystemConfig config = service.getOperational();

        assertNotNull(config);
        assertEquals("Asia/Ho_Chi_Minh", config.timezone());
        assertEquals(2, config.openingHours().size());
        assertEquals(1, config.openingHours().get(0).dayOfWeek());
        assertEquals("08:00", config.openingHours().get(0).opensAt());
        assertEquals("22:00", config.openingHours().get(0).closesAt());
        assertEquals(250, config.maxCapacity());
        assertEquals(0.9, config.nearCapacityRatio());
        assertFalse(config.capacityEnforcement());
        assertEquals(120, config.maxSessionDurationMinutes());
        assertEquals(10, config.scanCooldownSeconds());
        assertEquals(1L, config.version());
    }
}
