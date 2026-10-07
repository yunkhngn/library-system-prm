package com.library.checkin.repository;

import com.library.checkin.entity.CheckinLog;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface CheckinLogRepository extends JpaRepository<CheckinLog, UUID> {

    Optional<CheckinLog> findByUserIdAndCheckOutTimeIsNull(UUID userId);

    Optional<CheckinLog> findByVisitorIdAndCheckOutTimeIsNull(UUID visitorId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT cl FROM CheckinLog cl WHERE cl.userId = :userId AND cl.checkOutTime IS NULL")
    Optional<CheckinLog> findOpenSessionByUserIdForUpdate(@Param("userId") UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT cl FROM CheckinLog cl WHERE cl.visitorId = :visitorId AND cl.checkOutTime IS NULL")
    Optional<CheckinLog> findOpenSessionByVisitorIdForUpdate(@Param("visitorId") UUID visitorId);

    long countByCheckOutTimeIsNull();

    @Query("SELECT cl FROM CheckinLog cl WHERE cl.userId = :userId ORDER BY cl.checkInTime DESC LIMIT 1")
    Optional<CheckinLog> findLatestByUserId(@Param("userId") UUID userId);

    Optional<CheckinLog> findByIdAndUserId(UUID id, UUID userId);

    @Query("""
        SELECT cl FROM CheckinLog cl
        WHERE cl.userId = :userId
          AND cl.checkInTime >= :from
          AND cl.checkInTime < :to
        """)
    Page<CheckinLog> findMyHistory(
            @Param("userId") UUID userId,
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            Pageable pageable
    );

    @Query(value = """
        SELECT cl.*
        FROM checkin_logs cl
        LEFT JOIN users u ON cl.user_id = u.id
        LEFT JOIN visitors v ON cl.visitor_id = v.id
        WHERE cl.check_in_time >= :from
          AND cl.check_in_time < :to
          AND (:userId IS NULL OR cl.user_id = :userId)
          AND (:visitorId IS NULL OR cl.visitor_id = :visitorId)
          AND (:isOpen IS NULL OR (:isOpen = true AND cl.check_out_time IS NULL) OR (:isOpen = false AND cl.check_out_time IS NOT NULL))
          AND (:method IS NULL OR cl.method = :method)
          AND (:q IS NULL OR :q = '' OR
               LOWER(u.code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(u.full_name) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.reference_code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.full_name) LIKE LOWER(CONCAT('%', :q, '%')))
        """,
        countQuery = """
        SELECT count(cl.id)
        FROM checkin_logs cl
        LEFT JOIN users u ON cl.user_id = u.id
        LEFT JOIN visitors v ON cl.visitor_id = v.id
        WHERE cl.check_in_time >= :from
          AND cl.check_in_time < :to
          AND (:userId IS NULL OR cl.user_id = :userId)
          AND (:visitorId IS NULL OR cl.visitor_id = :visitorId)
          AND (:isOpen IS NULL OR (:isOpen = true AND cl.check_out_time IS NULL) OR (:isOpen = false AND cl.check_out_time IS NOT NULL))
          AND (:method IS NULL OR cl.method = :method)
          AND (:q IS NULL OR :q = '' OR
               LOWER(u.code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(u.full_name) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.reference_code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.full_name) LIKE LOWER(CONCAT('%', :q, '%')))
        """,
        nativeQuery = true)
    Page<CheckinLog> searchAccessHistory(
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("userId") UUID userId,
            @Param("visitorId") UUID visitorId,
            @Param("isOpen") Boolean isOpen,
            @Param("method") String method,
            @Param("q") String q,
            Pageable pageable
    );

    @Query(value = """
        SELECT cl.id, cl.check_in_time, cl.method,
               u.id AS user_id, u.code AS user_code, u.full_name AS user_name,
               v.id AS visitor_id, v.reference_code AS visitor_ref, v.full_name AS visitor_name
        FROM checkin_logs cl
        LEFT JOIN users u ON cl.user_id = u.id
        LEFT JOIN visitors v ON cl.visitor_id = v.id
        WHERE cl.check_out_time IS NULL
          AND (:kind IS NULL OR (:kind = 'USER' AND cl.user_id IS NOT NULL) OR (:kind = 'VISITOR' AND cl.visitor_id IS NOT NULL))
          AND (:q IS NULL OR :q = '' OR
               LOWER(u.code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(u.full_name) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.reference_code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.full_name) LIKE LOWER(CONCAT('%', :q, '%')))
        ORDER BY cl.check_in_time DESC
        """,
        countQuery = """
        SELECT count(cl.id)
        FROM checkin_logs cl
        LEFT JOIN users u ON cl.user_id = u.id
        LEFT JOIN visitors v ON cl.visitor_id = v.id
        WHERE cl.check_out_time IS NULL
          AND (:kind IS NULL OR (:kind = 'USER' AND cl.user_id IS NOT NULL) OR (:kind = 'VISITOR' AND cl.visitor_id IS NOT NULL))
          AND (:q IS NULL OR :q = '' OR
               LOWER(u.code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(u.full_name) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.reference_code) LIKE LOWER(CONCAT('%', :q, '%')) OR
               LOWER(v.full_name) LIKE LOWER(CONCAT('%', :q, '%')))
        """,
        nativeQuery = true)
    Page<Object[]> findOpenOccupants(
            @Param("kind") String kind,
            @Param("q") String q,
            Pageable pageable
    );
}
