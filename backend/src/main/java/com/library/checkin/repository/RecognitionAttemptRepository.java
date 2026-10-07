package com.library.checkin.repository;

import com.library.checkin.entity.RecognitionAttempt;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface RecognitionAttemptRepository extends JpaRepository<RecognitionAttempt, UUID> {

    @Query(value = "SELECT outcome, COUNT(*) FROM recognition_attempts " +
            "WHERE occurred_at >= :from AND occurred_at < :to " +
            "AND (:kioskId IS NULL OR kiosk_id = :kioskId) " +
            "GROUP BY outcome", nativeQuery = true)
    List<Object[]> countOutcomes(
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("kioskId") UUID kioskId
    );

    @Query(value = "SELECT COUNT(*), " +
            "COUNT(CASE WHEN outcome = 'MATCHED' OR outcome LIKE 'MATCH%' THEN 1 END), " +
            "PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY latency_ms), " +
            "PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY latency_ms) " +
            "FROM recognition_attempts " +
            "WHERE occurred_at >= :from AND occurred_at < :to " +
            "AND (:kioskId IS NULL OR kiosk_id = :kioskId)", nativeQuery = true)
    List<Object[]> getAggregatedMetrics(
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("kioskId") UUID kioskId
    );
}
