package com.library.checkin.repository;

import com.library.checkin.entity.LibraryState;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface LibraryStateRepository extends JpaRepository<LibraryState, Short> {

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("SELECT ls FROM LibraryState ls WHERE ls.id = :id")
    Optional<LibraryState> findByIdForUpdate(@Param("id") Short id);
}
