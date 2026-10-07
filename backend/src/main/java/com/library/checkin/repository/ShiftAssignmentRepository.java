package com.library.checkin.repository;

import com.library.checkin.entity.ShiftAssignment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ShiftAssignmentRepository extends JpaRepository<ShiftAssignment, UUID> {

    long countByShiftIdAndStatus(UUID shiftId, String status);

    List<ShiftAssignment> findByShiftIdAndStatus(UUID shiftId, String status);

    List<ShiftAssignment> findByShiftId(UUID shiftId);

    Page<ShiftAssignment> findByShiftId(UUID shiftId, Pageable pageable);

    Page<ShiftAssignment> findByShiftIdAndStatus(UUID shiftId, String status, Pageable pageable);

    Optional<ShiftAssignment> findByIdAndShiftId(UUID id, UUID shiftId);

    boolean existsByShiftIdAndStaffId(UUID shiftId, UUID staffId);

    boolean existsByShiftIdAndStaffIdAndStatus(UUID shiftId, UUID staffId, String status);

    @Query("SELECT COUNT(sa) > 0 FROM ShiftAssignment sa WHERE sa.staff.id = :staffId AND sa.status = 'ACTIVE' " +
            "AND (:excludeAssignmentId IS NULL OR sa.id != :excludeAssignmentId) " +
            "AND sa.startsAt < :endsAt AND sa.endsAt > :startsAt")
    boolean existsOverlap(
            @Param("staffId") UUID staffId,
            @Param("startsAt") OffsetDateTime startsAt,
            @Param("endsAt") OffsetDateTime endsAt,
            @Param("excludeAssignmentId") UUID excludeAssignmentId
    );

    @Query(value = "SELECT sa FROM ShiftAssignment sa JOIN FETCH sa.shift s WHERE sa.staff.id = :staffId " +
            "AND sa.startsAt < :to AND sa.endsAt > :from " +
            "AND (:status IS NULL OR sa.status = :status)",
            countQuery = "SELECT COUNT(sa) FROM ShiftAssignment sa WHERE sa.staff.id = :staffId " +
            "AND sa.startsAt < :to AND sa.endsAt > :from " +
            "AND (:status IS NULL OR sa.status = :status)")
    Page<ShiftAssignment> findMyShifts(
            @Param("staffId") UUID staffId,
            @Param("from") OffsetDateTime from,
            @Param("to") OffsetDateTime to,
            @Param("status") String status,
            Pageable pageable
    );

    @Query("SELECT sa.shift.id, COUNT(sa) FROM ShiftAssignment sa WHERE sa.shift.id IN :shiftIds AND sa.status = 'ACTIVE' GROUP BY sa.shift.id")
    List<Object[]> countActiveByShiftIds(@Param("shiftIds") List<UUID> shiftIds);
}
