package com.library.checkin.repository;

import com.library.checkin.entity.QrGrant;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface QrGrantRepository extends JpaRepository<QrGrant, UUID> {

    Optional<QrGrant> findByNonceHash(String nonceHash);

    boolean existsByNonceHash(String nonceHash);
}
