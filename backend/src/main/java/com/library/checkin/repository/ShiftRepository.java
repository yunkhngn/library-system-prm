package com.library.checkin.repository;

import com.library.checkin.entity.Shift;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.UUID;

@Repository
public interface ShiftRepository extends JpaRepository<Shift, UUID> {

    @Query(value = "SELECT s FROM Shift s WHERE s.startsAt < :to AND s.endsAt > :from " +
            "AND (:status IS NULL OR s.status = :status) " +
            "AND LOWER(s.name) LIKE LOWER(CONCAT('%', :q, '%')) " +
            "AND (:staffId IS NULL OR EXISTS (SELECT 1 FROM ShiftAssignment sa WHERE sa.shift = s AND sa.staff.id = :staffId AND sa.status = 'ACTIVE'))",
            countQuery = "SELECT COUNT(s) FROM Shift s WHERE s.startsAt < :to AND s.endsAt > :from " +
            "AND (:status IS NULL OR s.status = :status) " +
            "AND LOWER(s.name) LIKE LOWER(CONCAT('%', :q, '%')) " +
            "AND (:staffId IS NULL OR EXISTS (SELECT 1 FROM ShiftAssignment sa WHERE sa.shift = s AND sa.staff.id = :staffId AND sa.status = 'ACTIVE'))")
    Page<Shift> findShifts(
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("status") String status,
            @Param("q") String q,
            @Param("staffId") UUID staffId,
            Pageable pageable
    );

    @Query(value = "SELECT s FROM Shift s WHERE s.startsAt < :to AND s.endsAt > :from " +
            "AND (:status IS NULL OR s.status = :status) " +
            "AND (:staffId IS NULL OR EXISTS (SELECT 1 FROM ShiftAssignment sa WHERE sa.shift = s AND sa.staff.id = :staffId AND sa.status = 'ACTIVE'))",
            countQuery = "SELECT COUNT(s) FROM Shift s WHERE s.startsAt < :to AND s.endsAt > :from " +
            "AND (:status IS NULL OR s.status = :status) " +
            "AND (:staffId IS NULL OR EXISTS (SELECT 1 FROM ShiftAssignment sa WHERE sa.shift = s AND sa.staff.id = :staffId AND sa.status = 'ACTIVE'))")
    Page<Shift> findShiftsWithoutNameFilter(
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("status") String status,
            @Param("staffId") UUID staffId,
            Pageable pageable
    );
}
