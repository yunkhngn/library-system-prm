package com.library.checkin.repository;

import com.library.checkin.entity.AccessRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface AccessRequestRepository extends JpaRepository<AccessRequest, UUID> {

    Optional<AccessRequest> findByPrincipalTypeAndPrincipalIdAndIdempotencyKey(
            String principalType, UUID principalId, UUID idempotencyKey
    );

    Optional<AccessRequest> findByIdempotencyKey(UUID idempotencyKey);
}
