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

    public boolean isReady() {
        String endpoint = aiServiceUrl + "/api/v1/ready";
        HttpHeaders headers = new HttpHeaders();
        headers.set("X-Service-Key", serviceKey);
        HttpEntity<Void> requestEntity = new HttpEntity<>(headers);

        try {
            ResponseEntity<JsonNode> response = restTemplate.exchange(
                    endpoint,
                    HttpMethod.GET,
                    requestEntity,
                    JsonNode.class
            );
            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                return "READY".equalsIgnoreCase(response.getBody().path("status").asText());
            }
            return false;
        } catch (Exception ex) {
            log.warn("AI readiness probe failed at {}: {}", endpoint, ex.getMessage());
            return false;
        }
    }

    public com.library.checkin.dto.InternalRecognitionResult recognizeFace(
            byte[] clipBytes,
            java.util.UUID challengeId,
            List<com.library.checkin.dto.ChallengeInstruction> instructions,
            String modelVersion,
            double maxCosineDistance,
            double minDistanceGap,
            double livenessMinScore
    ) {
        String endpoint = aiServiceUrl + "/api/v1/recognize";

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);
        headers.set("X-Service-Key", serviceKey);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        // Name the part after what the bytes really are so the AI service picks the right decoder.
        String clipFilename = VideoContainer.detect(clipBytes).orElse(VideoContainer.MP4).filename();
        ByteArrayResource clipResource = new ByteArrayResource(clipBytes) {
            @Override
            public String getFilename() {
                return clipFilename;
            }
        };
        body.add("clip", clipResource);
        body.add("challengeId", challengeId.toString());

        try {
            String instructionsJson = objectMapper.writeValueAsString(instructions);
            body.add("challengeInstructions", instructionsJson);
        } catch (Exception e) {
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "INTERNAL_ERROR", "Failed serializing challenge instructions");
        }

        body.add("modelVersion", modelVersion != null ? modelVersion : "arcface-512-v1");
        body.add("maxCosineDistance", String.valueOf(maxCosineDistance));
        body.add("minDistanceGap", String.valueOf(minDistanceGap));
        body.add("livenessMinScore", String.valueOf(livenessMinScore));

        HttpEntity<MultiValueMap<String, Object>> requestEntity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<com.library.checkin.dto.InternalRecognitionResult> response = restTemplate.postForEntity(
                    endpoint,
                    requestEntity,
                    com.library.checkin.dto.InternalRecognitionResult.class
            );
            return response.getBody();
        } catch (HttpStatusCodeException ex) {
            handleHttpError(ex);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE", "Failed communicating with AI service");
        } catch (ResourceAccessException ex) {
            log.warn("AI service unreachable at {}: {}", endpoint, ex.getMessage());
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE", "AI service is currently unreachable");
        } catch (ApiException ex) {
            throw ex;
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
