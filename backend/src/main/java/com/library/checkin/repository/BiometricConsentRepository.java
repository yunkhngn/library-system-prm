package com.library.checkin.repository;

import com.library.checkin.entity.BiometricConsent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface BiometricConsentRepository extends JpaRepository<BiometricConsent, UUID> {

    @Query("SELECT bc FROM BiometricConsent bc WHERE bc.userId = :userId AND bc.revokedAt IS NULL")
    Optional<BiometricConsent> findActiveConsentByUserId(@Param("userId") UUID userId);

    @Query("SELECT bc FROM BiometricConsent bc WHERE bc.userId = :userId ORDER BY bc.grantedAt DESC LIMIT 1")
    Optional<BiometricConsent> findLatestConsentByUserId(@Param("userId") UUID userId);
}
