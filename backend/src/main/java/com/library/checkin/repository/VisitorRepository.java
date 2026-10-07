package com.library.checkin.repository;

import com.library.checkin.entity.Visitor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface VisitorRepository extends JpaRepository<Visitor, UUID> {

    Optional<Visitor> findByReferenceCode(String referenceCode);

    @Query("SELECT v FROM Visitor v WHERE " +
           "(:q IS NULL OR :q = '' OR " +
           "LOWER(v.referenceCode) LIKE LOWER(CONCAT('%', :q, '%')) OR " +
           "LOWER(v.fullName) LIKE LOWER(CONCAT('%', :q, '%')))")
    Page<Visitor> searchVisitors(@Param("q") String q, Pageable pageable);

    @Query(value = "SELECT nextval('visitor_seq')", nativeQuery = true)
    Long getNextSequenceVal();
}
