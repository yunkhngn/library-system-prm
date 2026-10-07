package com.library.checkin.repository;

import com.library.checkin.entity.CheckinLog;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface CheckinLogRepository extends JpaRepository<CheckinLog, UUID> {

    Optional<CheckinLog> findByUserIdAndCheckOutTimeIsNull(UUID userId);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT cl FROM CheckinLog cl WHERE cl.userId = :userId AND cl.checkOutTime IS NULL")
    Optional<CheckinLog> findOpenSessionByUserIdForUpdate(@Param("userId") UUID userId);

    long countByCheckOutTimeIsNull();

    @Query("SELECT cl FROM CheckinLog cl WHERE cl.userId = :userId ORDER BY cl.checkInTime DESC LIMIT 1")
    Optional<CheckinLog> findLatestByUserId(@Param("userId") UUID userId);
}
