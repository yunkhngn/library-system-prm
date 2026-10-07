package com.library.checkin.repository;

import com.library.checkin.entity.FaceChallengeEntity;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface FaceChallengeRepository extends JpaRepository<FaceChallengeEntity, UUID> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT fc FROM FaceChallengeEntity fc WHERE fc.id = :id")
    Optional<FaceChallengeEntity> findByIdForUpdate(@Param("id") UUID id);
}
