package com.library.checkin.repository;

import com.library.checkin.entity.User;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID>, JpaSpecificationExecutor<User> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT u FROM User u WHERE u.id = :id")
    Optional<User> findByIdForUpdate(@Param("id") UUID id);

    Optional<User> findByCode(String code);

    Optional<User> findByEmail(String email);

    @Query("SELECT u FROM User u WHERE u.code = :identifier OR u.email = :identifier")
    Optional<User> findByIdentifier(@Param("identifier") String identifier);

    boolean existsByCode(String code);

    boolean existsByEmail(String email);

    long countByRoleAndStatus(String role, String status);

    @Query("SELECT u FROM User u WHERE " +
           "(:role IS NULL OR u.role = :role) AND " +
           "(:status IS NULL OR u.status = :status) AND " +
           "(:query IS NULL OR LOWER(u.code) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           " LOWER(u.email) LIKE LOWER(CONCAT('%', :query, '%')) OR " +
           " LOWER(u.fullName) LIKE LOWER(CONCAT('%', :query, '%')))")
    Page<User> searchUsers(
            @Param("role") String role,
            @Param("status") String status,
            @Param("query") String query,
            Pageable pageable
    );

    @Query(value = "SELECT EXISTS (SELECT 1 FROM checkin_logs WHERE user_id = :userId AND check_out_time IS NULL)", nativeQuery = true)
    boolean hasOpenSession(@Param("userId") UUID userId);

    @Query(value = "SELECT EXISTS (SELECT 1 FROM biometric_consents c JOIN face_embeddings f ON f.consent_id = c.id WHERE c.user_id = :userId AND c.revoked_at IS NULL)", nativeQuery = true)
    boolean hasEnrolledFace(@Param("userId") UUID userId);
}
