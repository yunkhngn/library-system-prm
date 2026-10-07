package com.library.checkin.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Entity
@Table(name = "library_state")
@Getter
@Setter
@NoArgsConstructor
public class LibraryState {

    @Id
    @Column(name = "id")
    private Short id = 1;

    @Column(name = "occupancy_revision", nullable = false)
    private Long occupancyRevision = 0L;
}
