package com.library.checkin.repository;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class FaceEmbeddingRepository {

    private final JdbcTemplate jdbcTemplate;

    public FaceEmbeddingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void insertEmbeddings(
            UUID userId,
            UUID consentId,
            List<List<Double>> embeddings,
            String modelId,
            String modelVersion
    ) {
        String sql = "INSERT INTO face_embeddings (user_id, consent_id, embedding, model_id, model_version) VALUES (?, ?, ?::vector, ?, ?)";
        for (List<Double> vector : embeddings) {
            String vectorStr = vectorToString(vector);
            jdbcTemplate.update(sql, userId, consentId, vectorStr, modelId, modelVersion);
        }
    }

    public void deleteByUserId(UUID userId) {
        jdbcTemplate.update("DELETE FROM face_embeddings WHERE user_id = ?", userId);
    }

    public long countByUserId(UUID userId) {
        Long count = jdbcTemplate.queryForObject(
                "SELECT COUNT(*) FROM face_embeddings WHERE user_id = ?",
                Long.class,
                userId
        );
        return count != null ? count : 0L;
    }

    public record EmbeddingMetadata(String modelId, String modelVersion, OffsetDateTime createdAt) {}

    public Optional<EmbeddingMetadata> findLatestMetadataByUserId(UUID userId) {
        List<EmbeddingMetadata> results = jdbcTemplate.query(
                "SELECT model_id, model_version, created_at FROM face_embeddings WHERE user_id = ? ORDER BY created_at DESC LIMIT 1",
                (rs, rowNum) -> new EmbeddingMetadata(
                        rs.getString("model_id"),
                        rs.getString("model_version"),
                        rs.getObject("created_at", OffsetDateTime.class)
                ),
                userId
        );
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
    }

    private String vectorToString(List<Double> vector) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < vector.size(); i++) {
            if (i > 0) sb.append(",");
            sb.append(vector.get(i));
        }
        sb.append("]");
        return sb.toString();
    }
}
