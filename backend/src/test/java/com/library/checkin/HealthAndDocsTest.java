package com.library.checkin;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class HealthAndDocsTest {

    @Autowired
    private MockMvc mockMvc;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.service.SystemConfigService systemConfigService;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.UserRepository userRepository;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.RefreshTokenRepository refreshTokenRepository;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.KioskRepository kioskRepository;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.QrGrantRepository qrGrantRepository;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.CheckinLogRepository checkinLogRepository;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.LibraryStateRepository libraryStateRepository;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.library.checkin.repository.AccessRequestRepository accessRequestRepository;

    @Test
    @DisplayName("Actuator health endpoint should be accessible without authentication")
    void actuatorHealthShouldBeAccessible() throws Exception {
        mockMvc.perform(get("/actuator/health"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Actuator readiness probe is UP and does not depend on AI availability")
    void readinessProbeShouldBeUpWithoutAi() throws Exception {
        mockMvc.perform(get("/actuator/health/readiness"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("OpenAPI v3 api-docs should be accessible in dev/test profile")
    void openApiDocsShouldBeAccessible() throws Exception {
        mockMvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Swagger UI html should be accessible")
    void swaggerUiShouldBeAccessible() throws Exception {
        mockMvc.perform(get("/swagger-ui/index.html"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("Protected business endpoints must require authentication and not be permitAll")
    void businessEndpointsMustRequireAuthentication() throws Exception {
        mockMvc.perform(get("/api/v1/users"))
                .andExpect(status().isUnauthorized());
    }
}
