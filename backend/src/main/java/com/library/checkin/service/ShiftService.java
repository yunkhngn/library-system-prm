package com.library.checkin.service;

import com.library.checkin.dto.*;
import com.library.checkin.entity.Shift;
import com.library.checkin.entity.ShiftAssignment;
import com.library.checkin.entity.User;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.ShiftAssignmentRepository;
import com.library.checkin.repository.ShiftRepository;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.security.CurrentPrincipal;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Duration;
import java.time.OffsetDateTime;
import java.util.*;
import java.util.stream.Collectors;

@Service
public class ShiftService {

    private final ShiftRepository shiftRepository;
    private final ShiftAssignmentRepository shiftAssignmentRepository;
    private final UserRepository userRepository;

    public ShiftService(ShiftRepository shiftRepository,
                        ShiftAssignmentRepository shiftAssignmentRepository,
                        UserRepository userRepository) {
        this.shiftRepository = shiftRepository;
        this.shiftAssignmentRepository = shiftAssignmentRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public ShiftDto createShift(CreateShiftRequest request, UUID adminUserId) {
        String name = request.name() != null ? request.name().trim() : "";
        if (name.isBlank() || name.length() > 150) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Invalid shift name");
        }

        validateTimeRange(request.startsAt(), request.endsAt());

        User admin = userRepository.findById(adminUserId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Admin user not found"));

        Shift shift = new Shift();
        shift.setName(name);
        shift.setStartsAt(request.startsAt());
        shift.setEndsAt(request.endsAt());
        shift.setStatus("ACTIVE");
        shift.setCreatedBy(admin);
        shift.setVersion(0L);
        shift.setCreatedAt(OffsetDateTime.now());
        shift.setUpdatedAt(OffsetDateTime.now());

        shift = shiftRepository.save(shift);
        return toDto(shift, 0L);
    }

    @Transactional(readOnly = true)
    public ShiftPage listShifts(int page, int size, OffsetDateTime from, OffsetDateTime to,
                                String status, UUID staffId, String q, String sortStr) {
        OffsetDateTime effectiveFrom = from != null ? from : OffsetDateTime.now().minusDays(7);
        OffsetDateTime effectiveTo = to != null ? to : OffsetDateTime.now().plusDays(30);

        validateDateBoundaries(effectiveFrom, effectiveTo);

        if (status != null && !status.isBlank() && !"ACTIVE".equalsIgnoreCase(status) && !"CANCELLED".equalsIgnoreCase(status)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid status parameter");
        }
        String effectiveStatus = (status != null && !status.isBlank()) ? status.toUpperCase() : null;

        Sort sort = parseShiftSort(sortStr);
        String trimmedQ = (q != null && !q.trim().isBlank()) ? q.trim() : null;

        Page<Shift> shiftPage = shiftRepository.findShifts(
                effectiveFrom, effectiveTo, effectiveStatus, trimmedQ, staffId,
                PageRequest.of(page, size, sort)
        );

        List<UUID> shiftIds = shiftPage.getContent().stream().map(Shift::getId).toList();
        Map<UUID, Long> countMap = getActiveAssignmentCounts(shiftIds);

        List<ShiftDto> items = shiftPage.getContent().stream()
                .map(s -> toDto(s, countMap.getOrDefault(s.getId(), 0L)))
                .toList();

        return new ShiftPage(
                items,
                (long) page,
                (long) size,
                shiftPage.getTotalElements(),
                (long) shiftPage.getTotalPages()
        );
    }

    @Transactional(readOnly = true)
    public ShiftDto getShift(UUID shiftId, CurrentPrincipal principal) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        if (principal.isLibrarian()) {
            boolean isAssigned = shiftAssignmentRepository.existsByShiftIdAndStaffId(shiftId, principal.getUserId());
            if (!isAssigned) {
                throw new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found");
            }
        } else if (!principal.isAdmin()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Access denied");
        }

        long activeCount = shiftAssignmentRepository.countByShiftIdAndStatus(shiftId, "ACTIVE");
        return toDto(shift, activeCount);
    }

    @Transactional
    public ShiftDto patchShift(UUID shiftId, PatchShiftRequest request) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        if ("CANCELLED".equalsIgnoreCase(shift.getStatus())) {
            throw new ApiException(HttpStatus.CONFLICT, "SHIFT_CANCELLED", "CANCELLED shifts cannot be edited");
        }

        if (!Objects.equals(request.version(), shift.getVersion())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Shift version conflict");
        }

        String newName = request.name() != null ? request.name().trim() : shift.getName();
        if (request.name() != null && (newName.isBlank() || newName.length() > 150)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Invalid shift name");
        }

        OffsetDateTime newStartsAt = request.startsAt() != null ? request.startsAt() : shift.getStartsAt();
        OffsetDateTime newEndsAt = request.endsAt() != null ? request.endsAt() : shift.getEndsAt();

        validateTimeRange(newStartsAt, newEndsAt);

        boolean timesChanged = !newStartsAt.isEqual(shift.getStartsAt()) || !newEndsAt.isEqual(shift.getEndsAt());

        OffsetDateTime now = OffsetDateTime.now();

        if (timesChanged) {
            List<ShiftAssignment> activeAssignments = shiftAssignmentRepository.findByShiftIdAndStatus(shiftId, "ACTIVE");
            // Check overlap for every active staff member
            for (ShiftAssignment sa : activeAssignments) {
                if (shiftAssignmentRepository.existsOverlap(sa.getStaff().getId(), newStartsAt, newEndsAt, sa.getId())) {
                    throw new ApiException(HttpStatus.CONFLICT, "SHIFT_OVERLAP", "Staff member has an overlapping shift assignment");
                }
                sa.setStartsAt(newStartsAt);
                sa.setEndsAt(newEndsAt);
                sa.setVersion(sa.getVersion() + 1);
                sa.setUpdatedAt(now);
            }
            shift.setStartsAt(newStartsAt);
            shift.setEndsAt(newEndsAt);
        }

        shift.setName(newName);
        shift.setVersion(shift.getVersion() + 1);
        shift.setUpdatedAt(now);

        shift = shiftRepository.saveAndFlush(shift);
        long activeCount = shiftAssignmentRepository.countByShiftIdAndStatus(shiftId, "ACTIVE");
        return toDto(shift, activeCount);
    }

    @Transactional
    public ShiftDto cancelShift(UUID shiftId, CancelShiftRequest request) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        if ("CANCELLED".equalsIgnoreCase(shift.getStatus())) {
            if (Objects.equals(shift.getVersion(), request.version())) {
                return toDto(shift, 0L);
            }
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Shift version conflict");
        }

        if (!Objects.equals(shift.getVersion(), request.version())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Shift version conflict");
        }

        String reason = request.reason() != null ? request.reason().trim() : "";
        if (reason.isBlank() || reason.length() > 1000) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "Cancellation reason required");
        }

        OffsetDateTime now = OffsetDateTime.now();
        shift.setStatus("CANCELLED");
        shift.setCancellationReason(reason);
        shift.setVersion(shift.getVersion() + 1);
        shift.setUpdatedAt(now);

        List<ShiftAssignment> activeAssignments = shiftAssignmentRepository.findByShiftIdAndStatus(shiftId, "ACTIVE");
        for (ShiftAssignment sa : activeAssignments) {
            sa.setStatus("CANCELLED");
            sa.setVersion(sa.getVersion() + 1);
            sa.setUpdatedAt(now);
        }

        shift = shiftRepository.saveAndFlush(shift);
        return toDto(shift, 0L);
    }

    @Transactional(readOnly = true)
    public AssignmentPage listShiftAssignments(UUID shiftId, int page, int size, String status, String sortStr, CurrentPrincipal principal) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        if (principal.isLibrarian()) {
            boolean isAssigned = shiftAssignmentRepository.existsByShiftIdAndStaffId(shiftId, principal.getUserId());
            if (!isAssigned) {
                throw new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found");
            }
        } else if (!principal.isAdmin()) {
            throw new ApiException(HttpStatus.FORBIDDEN, "FORBIDDEN", "Access denied");
        }

        Sort sort = parseAssignmentSort(sortStr);

        Page<ShiftAssignment> assignmentPage;
        if (status != null && !status.isBlank()) {
            if (!"ACTIVE".equalsIgnoreCase(status) && !"CANCELLED".equalsIgnoreCase(status)) {
                throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid status parameter");
            }
            assignmentPage = shiftAssignmentRepository.findByShiftIdAndStatus(shiftId, status.toUpperCase(), PageRequest.of(page, size, sort));
        } else {
            assignmentPage = shiftAssignmentRepository.findByShiftId(shiftId, PageRequest.of(page, size, sort));
        }

        List<AssignmentDto> items = assignmentPage.getContent().stream()
                .map(this::toDto)
                .toList();

        return new AssignmentPage(
                items,
                (long) page,
                (long) size,
                assignmentPage.getTotalElements(),
                (long) assignmentPage.getTotalPages()
        );
    }

    @Transactional
    public AssignmentBatch assignStaff(UUID shiftId, AssignStaffRequest request, UUID adminUserId) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        if ("CANCELLED".equalsIgnoreCase(shift.getStatus())) {
            throw new ApiException(HttpStatus.CONFLICT, "SHIFT_CANCELLED", "Cannot assign staff to a CANCELLED shift");
        }

        if (!Objects.equals(request.version(), shift.getVersion())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Shift version conflict");
        }

        User admin = userRepository.findById(adminUserId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Admin user not found"));

        List<UUID> staffIds = request.staffIds().stream().distinct().sorted().toList();
        if (staffIds.isEmpty() || staffIds.size() > 100) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_REQUEST", "staffIds must have between 1 and 100 unique items");
        }

        OffsetDateTime now = OffsetDateTime.now();
        List<ShiftAssignment> toSave = new ArrayList<>();

        for (UUID staffId : staffIds) {
            User staff = userRepository.findById(staffId)
                    .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "STAFF_NOT_ELIGIBLE", "Staff user not found"));

            if (!"LIBRARIAN".equalsIgnoreCase(staff.getRole()) || !"ACTIVE".equalsIgnoreCase(staff.getStatus())) {
                throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "STAFF_NOT_ELIGIBLE", "Staff member must be an ACTIVE LIBRARIAN");
            }

            if (shiftAssignmentRepository.existsByShiftIdAndStaffIdAndStatus(shiftId, staffId, "ACTIVE")) {
                throw new ApiException(HttpStatus.CONFLICT, "ASSIGNMENT_EXISTS", "Staff member is already assigned to this shift");
            }

            if (shiftAssignmentRepository.existsOverlap(staffId, shift.getStartsAt(), shift.getEndsAt(), null)) {
                throw new ApiException(HttpStatus.CONFLICT, "SHIFT_OVERLAP", "Staff member has an overlapping shift assignment");
            }

            ShiftAssignment sa = new ShiftAssignment();
            sa.setShift(shift);
            sa.setStaff(staff);
            sa.setStartsAt(shift.getStartsAt());
            sa.setEndsAt(shift.getEndsAt());
            sa.setStatus("ACTIVE");
            sa.setAssignedBy(admin);
            sa.setVersion(0L);
            sa.setCreatedAt(now);
            sa.setUpdatedAt(now);
            toSave.add(sa);
        }

        shift.setVersion(shift.getVersion() + 1);
        shift.setUpdatedAt(now);

        List<ShiftAssignment> saved = shiftAssignmentRepository.saveAllAndFlush(toSave);
        shift = shiftRepository.saveAndFlush(shift);

        long activeCount = shiftAssignmentRepository.countByShiftIdAndStatus(shiftId, "ACTIVE");
        List<AssignmentDto> assignmentDtos = saved.stream().map(this::toDto).toList();

        return new AssignmentBatch(toDto(shift, activeCount), assignmentDtos);
    }

    @Transactional
    public AssignmentBatch replaceAssignedStaff(UUID shiftId, UUID assignmentId, PatchAssignmentRequest request, UUID adminUserId) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        ShiftAssignment assignment = shiftAssignmentRepository.findByIdAndShiftId(assignmentId, shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Assignment not found"));

        if ("CANCELLED".equalsIgnoreCase(shift.getStatus())) {
            throw new ApiException(HttpStatus.CONFLICT, "SHIFT_CANCELLED", "Shift is CANCELLED");
        }

        if ("CANCELLED".equalsIgnoreCase(assignment.getStatus())) {
            throw new ApiException(HttpStatus.CONFLICT, "SHIFT_CANCELLED", "Assignment is CANCELLED");
        }

        if (!Objects.equals(request.version(), assignment.getVersion())) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Assignment version conflict");
        }

        User newStaff = userRepository.findById(request.staffId())
                .orElseThrow(() -> new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "STAFF_NOT_ELIGIBLE", "Staff user not found"));

        if (!"LIBRARIAN".equalsIgnoreCase(newStaff.getRole()) || !"ACTIVE".equalsIgnoreCase(newStaff.getStatus())) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "STAFF_NOT_ELIGIBLE", "Staff member must be an ACTIVE LIBRARIAN");
        }

        User admin = userRepository.findById(adminUserId)
                .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "UNAUTHENTICATED", "Admin user not found"));

        if (!newStaff.getId().equals(assignment.getStaff().getId())) {
            if (shiftAssignmentRepository.existsByShiftIdAndStaffIdAndStatus(shiftId, newStaff.getId(), "ACTIVE")) {
                throw new ApiException(HttpStatus.CONFLICT, "ASSIGNMENT_EXISTS", "Staff member is already assigned to this shift");
            }

            if (shiftAssignmentRepository.existsOverlap(newStaff.getId(), assignment.getStartsAt(), assignment.getEndsAt(), assignment.getId())) {
                throw new ApiException(HttpStatus.CONFLICT, "SHIFT_OVERLAP", "Staff member has an overlapping shift assignment");
            }
        }

        OffsetDateTime now = OffsetDateTime.now();
        assignment.setStaff(newStaff);
        assignment.setVersion(assignment.getVersion() + 1);
        assignment.setAssignedBy(admin);
        assignment.setUpdatedAt(now);

        shift.setVersion(shift.getVersion() + 1);
        shift.setUpdatedAt(now);

        assignment = shiftAssignmentRepository.saveAndFlush(assignment);
        shift = shiftRepository.saveAndFlush(shift);

        long activeCount = shiftAssignmentRepository.countByShiftIdAndStatus(shiftId, "ACTIVE");
        return new AssignmentBatch(toDto(shift, activeCount), List.of(toDto(assignment)));
    }

    @Transactional
    public void cancelAssignment(UUID shiftId, UUID assignmentId, Long version) {
        Shift shift = shiftRepository.findById(shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Shift not found"));

        ShiftAssignment assignment = shiftAssignmentRepository.findByIdAndShiftId(assignmentId, shiftId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Assignment not found"));

        if ("CANCELLED".equalsIgnoreCase(assignment.getStatus())) {
            if (Objects.equals(assignment.getVersion(), version)) {
                return; // 204 No Content idempotent
            }
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Assignment version conflict");
        }

        if (!Objects.equals(assignment.getVersion(), version)) {
            throw new ApiException(HttpStatus.CONFLICT, "VERSION_CONFLICT", "Assignment version conflict");
        }

        OffsetDateTime now = OffsetDateTime.now();
        assignment.setStatus("CANCELLED");
        assignment.setVersion(assignment.getVersion() + 1);
        assignment.setUpdatedAt(now);

        shift.setVersion(shift.getVersion() + 1);
        shift.setUpdatedAt(now);

        shiftAssignmentRepository.saveAndFlush(assignment);
        shiftRepository.saveAndFlush(shift);
    }

    @Transactional(readOnly = true)
    public MyShiftPage listMyShifts(UUID librarianId, int page, int size, OffsetDateTime from, OffsetDateTime to,
                                    String status, String sortStr) {
        OffsetDateTime effectiveFrom = from != null ? from : OffsetDateTime.now().minusDays(7);
        OffsetDateTime effectiveTo = to != null ? to : OffsetDateTime.now().plusDays(30);

        validateDateBoundaries(effectiveFrom, effectiveTo);

        if (status != null && !status.isBlank() && !"ACTIVE".equalsIgnoreCase(status) && !"CANCELLED".equalsIgnoreCase(status)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid status parameter");
        }
        String effectiveStatus = (status != null && !status.isBlank()) ? status.toUpperCase() : null;

        Sort sort = parseShiftSort(sortStr);

        Page<ShiftAssignment> assignmentPage = shiftAssignmentRepository.findMyShifts(
                librarianId, effectiveFrom, effectiveTo, effectiveStatus, PageRequest.of(page, size, sort)
        );

        List<UUID> shiftIds = assignmentPage.getContent().stream()
                .map(sa -> sa.getShift().getId())
                .distinct()
                .toList();
        Map<UUID, Long> countMap = getActiveAssignmentCounts(shiftIds);

        List<MyShift> items = assignmentPage.getContent().stream()
                .map(sa -> {
                    Shift s = sa.getShift();
                    ShiftDto shiftDto = toDto(s, countMap.getOrDefault(s.getId(), 0L));
                    AssignmentDto assignmentDto = toDto(sa);
                    return new MyShift(shiftDto, assignmentDto);
                })
                .toList();

        return new MyShiftPage(
                items,
                (long) page,
                (long) size,
                assignmentPage.getTotalElements(),
                (long) assignmentPage.getTotalPages()
        );
    }

    // -------------------------------------------------------------------------
    // Helper & Validation Methods
    // -------------------------------------------------------------------------

    private void validateTimeRange(OffsetDateTime startsAt, OffsetDateTime endsAt) {
        if (startsAt == null || endsAt == null) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "startsAt and endsAt are required");
        }
        if (!endsAt.isAfter(startsAt)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "endsAt must be after startsAt");
        }
        Duration duration = Duration.between(startsAt, endsAt);
        if (duration.compareTo(Duration.ofHours(24)) > 0) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "Shift duration cannot exceed 24 hours");
        }
    }

    private void validateDateBoundaries(OffsetDateTime from, OffsetDateTime to) {
        if (!to.isAfter(from)) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "to boundary must be after from boundary");
        }
        if (Duration.between(from, to).toDays() > 366) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "INVALID_TIME_RANGE", "Date range cannot exceed 366 days");
        }
    }

    private Sort parseShiftSort(String sortStr) {
        if (sortStr == null || sortStr.isBlank() || "startsAt,asc".equalsIgnoreCase(sortStr)) {
            return Sort.by(Sort.Direction.ASC, "startsAt");
        } else if ("startsAt,desc".equalsIgnoreCase(sortStr)) {
            return Sort.by(Sort.Direction.DESC, "startsAt");
        }
        throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid sort choice");
    }

    private Sort parseAssignmentSort(String sortStr) {
        if (sortStr == null || sortStr.isBlank() || "createdAt,asc".equalsIgnoreCase(sortStr)) {
            return Sort.by(Sort.Direction.ASC, "createdAt");
        } else if ("createdAt,desc".equalsIgnoreCase(sortStr)) {
            return Sort.by(Sort.Direction.DESC, "createdAt");
        }
        throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid sort choice");
    }

    private Map<UUID, Long> getActiveAssignmentCounts(List<UUID> shiftIds) {
        if (shiftIds.isEmpty()) {
            return Collections.emptyMap();
        }
        List<Object[]> results = shiftAssignmentRepository.countActiveByShiftIds(shiftIds);
        Map<UUID, Long> map = new HashMap<>();
        for (Object[] row : results) {
            map.put((UUID) row[0], ((Number) row[1]).longValue());
        }
        return map;
    }

    public ShiftDto toDto(Shift shift, long activeCount) {
        User createdBy = shift.getCreatedBy();
        Actor createdByActor = createdBy != null
                ? new Actor(createdBy.getId(), createdBy.getCode(), createdBy.getFullName())
                : null;
        return new ShiftDto(
                shift.getId(),
                shift.getName(),
                shift.getStartsAt(),
                shift.getEndsAt(),
                shift.getStatus(),
                shift.getVersion(),
                activeCount,
                createdByActor,
                shift.getCreatedAt(),
                shift.getUpdatedAt(),
                shift.getCancellationReason()
        );
    }

    public AssignmentDto toDto(ShiftAssignment sa) {
        User staff = sa.getStaff();
        Actor staffActor = staff != null
                ? new Actor(staff.getId(), staff.getCode(), staff.getFullName())
                : null;
        User assignedBy = sa.getAssignedBy();
        Actor assignedByActor = assignedBy != null
                ? new Actor(assignedBy.getId(), assignedBy.getCode(), assignedBy.getFullName())
                : null;
        return new AssignmentDto(
                sa.getId(),
                sa.getShift().getId(),
                staffActor,
                sa.getStartsAt(),
                sa.getEndsAt(),
                sa.getStatus(),
                sa.getVersion(),
                assignedByActor,
                sa.getCreatedAt(),
                sa.getUpdatedAt()
        );
    }
}
