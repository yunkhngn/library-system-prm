package com.library.checkin.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import io.swagger.v3.oas.models.servers.Server;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.List;

@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI customOpenAPI() {
        return new OpenAPI()
                .info(new Info()
                        .title("Library Backend — MVP API contract")
                        .version("1.0.0")
                        .description("Library Entry/Exit and Occupancy Management System API. " +
                                "Supports QR and Face recognition workflows, role-based access, and STOMP realtime updates at /ws (/topic/occupancy)."))
                .servers(List.of(
                        new Server().url("/").description("Current Server")
                ))
                .components(new Components()
                        .addSecuritySchemes("bearerAuth", new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("User JWT purpose ACCESS; roles are checked by the backend."))
                        .addSecuritySchemes("kioskAuth", new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")
                                .description("JWT purpose KIOSK; cannot be replaced by a user token.")))
                .addSecurityItem(new SecurityRequirement().addList("bearerAuth"));
    }
}
