package com.library.checkin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.SystemConfig;
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

@ExtendWith(MockitoExtension.class)
class SystemConfigServiceTest {

    @Mock
    private SystemConfigRepository repository;

    @Spy
    private ObjectMapper objectMapper = new ObjectMapper();

    @InjectMocks
    private SystemConfigService service;

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
