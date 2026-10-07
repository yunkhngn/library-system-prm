package com.library.checkin.service;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.library.checkin.dto.InternalEmbeddingResult;
import com.library.checkin.exception.ApiException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

@Service
@Slf4j
public class AiClient {

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;
    private final String aiServiceUrl;
    private final String serviceKey;

    public AiClient(
            RestTemplate restTemplate,
            ObjectMapper objectMapper,
            @Value("${app.ai-service.url:http://localhost:8001}") String aiServiceUrl,
            @Value("${app.ai-service.service-key:${AI_SERVICE_KEY:dev-internal-service-key-change-in-prod}}") String serviceKey
    ) {
        this.restTemplate = restTemplate;
        this.objectMapper = objectMapper;
        this.aiServiceUrl = aiServiceUrl.endsWith("/") ? aiServiceUrl.substring(0, aiServiceUrl.length() - 1) : aiServiceUrl;
        this.serviceKey = serviceKey;
    }

    public InternalEmbeddingResult extractEmbeddings(List<MultipartFile> images) {
        String endpoint = aiServiceUrl + "/api/v1/embeddings";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-Service-Key", serviceKey);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        for (MultipartFile file : images) {
            try {
                ByteArrayResource resource = new ByteArrayResource(file.getBytes()) {
                    @Override
                    public String getFilename() {
                        return file.getOriginalFilename() != null ? file.getOriginalFilename() : "image.jpg";
                    }
                };
                body.add("images", resource);
            } catch (IOException e) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "IMAGE_INVALID", "Failed to read image upload bytes");
            }
        }

        HttpEntity<MultiValueMap<String, Object>> requestEntity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<InternalEmbeddingResult> response = restTemplate.postForEntity(
                    endpoint,
                    requestEntity,
                    InternalEmbeddingResult.class
            );
            return response.getBody();
        } catch (HttpStatusCodeException ex) {
            handleHttpError(ex);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE", "Failed communicating with AI service");
        } catch (ResourceAccessException ex) {
            log.warn("AI service unreachable at {}: {}", endpoint, ex.getMessage());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE", "AI service is currently unreachable");
        } catch (Exception ex) {
            log.error("Unexpected error calling AI service: {}", ex.getMessage(), ex);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE", "AI service unexpected error: " + ex.getMessage());
        }
    }

    private void handleHttpError(HttpStatusCodeException ex) {
        HttpStatus status = HttpStatus.valueOf(ex.getStatusCode().value());
        String responseBody = ex.getResponseBodyAsString();
        log.warn("AI service returned error {}: {}", status, responseBody);

        try {
            JsonNode errorNode = objectMapper.readTree(responseBody);
            String code = errorNode.path("code").asText("AI_UNAVAILABLE");
            String message = errorNode.path("message").asText(ex.getMessage());
            throw new ApiException(status, code, message);
        } catch (ApiException e) {
            throw e;
        } catch (Exception parseException) {
            throw new ApiException(status, "AI_UNAVAILABLE", ex.getMessage());
        }
    }
}
