package com.library.checkin.repository;

import com.library.checkin.entity.Kiosk;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface KioskRepository extends JpaRepository<Kiosk, UUID>, JpaSpecificationExecutor<Kiosk> {

    Optional<Kiosk> findByCode(String code);

    boolean existsByCode(String code);
}
