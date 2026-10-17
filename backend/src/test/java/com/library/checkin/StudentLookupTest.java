package com.library.checkin;

import com.library.checkin.dto.StudentLookup;
import com.library.checkin.entity.CheckinLog;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.CheckinLogRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.service.AccessService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class StudentLookupTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private CheckinLogRepository checkinLogRepository;

    @InjectMocks
    private AccessService accessService;

    @Test
    void blankCodeIsRejected() {
        ApiException ex = assertThrows(ApiException.class, () -> accessService.lookupStudent("   "));
        assertEquals(HttpStatus.BAD_REQUEST, ex.getStatus());
        assertEquals("INVALID_QUERY", ex.getCode());
    }

    @Test
    void staffAccountsAreHiddenAsNotFound() {
        User librarian = student("LIB001", "LIBRARIAN", "ACTIVE");
        when(userRepository.findByCode("LIB001")).thenReturn(Optional.of(librarian));

        ApiException ex = assertThrows(ApiException.class, () -> accessService.lookupStudent("lib001"));
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatus());
        assertEquals("RESOURCE_NOT_FOUND", ex.getCode());
    }

    @Test
    void unknownCodeIsNotFound() {
        when(userRepository.findByCode("NOPE999")).thenReturn(Optional.empty());

        ApiException ex = assertThrows(ApiException.class, () -> accessService.lookupStudent("nope999"));
        assertEquals("RESOURCE_NOT_FOUND", ex.getCode());
    }

    @Test
    void returnsStudentOutsideTheLibrary() {
        User student = student("SV002", "STUDENT", "ACTIVE");
        when(userRepository.findByCode("SV002")).thenReturn(Optional.of(student));
        when(checkinLogRepository.findByUserIdAndCheckOutTimeIsNull(student.getId())).thenReturn(Optional.empty());

        StudentLookup lookup = accessService.lookupStudent("  sv002 ");

        assertEquals(student.getId(), lookup.id());
        assertEquals("SV002", lookup.code());
        assertEquals("Trần Minh Quân", lookup.fullName());
        assertEquals("ACTIVE", lookup.status());
        assertFalse(lookup.isInside());
        assertNull(lookup.currentSessionId());
        assertNull(lookup.checkInTime());
    }

    @Test
    void includesOpenSessionWhenInside() {
        User student = student("SV002", "STUDENT", "LOCKED");
        CheckinLog session = new CheckinLog();
        session.setId(UUID.randomUUID());
        session.setCheckInTime(OffsetDateTime.parse("2026-10-13T07:25:00Z"));

        when(userRepository.findByCode("SV002")).thenReturn(Optional.of(student));
        when(checkinLogRepository.findByUserIdAndCheckOutTimeIsNull(student.getId())).thenReturn(Optional.of(session));

        StudentLookup lookup = accessService.lookupStudent("SV002");

        assertTrue(lookup.isInside());
        assertEquals("LOCKED", lookup.status());
        assertEquals(session.getId(), lookup.currentSessionId());
        assertEquals(session.getCheckInTime(), lookup.checkInTime());
    }

    private static User student(String code, String role, String status) {
        User user = new User();
        user.setId(UUID.randomUUID());
        user.setCode(code);
        user.setFullName("Trần Minh Quân");
        user.setRole(role);
        user.setStatus(status);
        return user;
    }
}
