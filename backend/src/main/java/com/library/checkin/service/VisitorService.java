package com.library.checkin.service;

import com.library.checkin.dto.Actor;
import com.library.checkin.dto.CreateVisitorRequest;
import com.library.checkin.dto.VisitorDto;
import com.library.checkin.dto.VisitorPage;
import com.library.checkin.entity.User;
import com.library.checkin.entity.Visitor;
import com.library.checkin.exception.ApiException;
import com.library.checkin.repository.UserRepository;
import com.library.checkin.repository.VisitorRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class VisitorService {

    private final VisitorRepository visitorRepository;
    private final UserRepository userRepository;

    public VisitorService(VisitorRepository visitorRepository, UserRepository userRepository) {
        this.visitorRepository = visitorRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public VisitorDto createVisitor(CreateVisitorRequest request, UUID staffId) {
        String trimmedName = request.fullName() != null ? request.fullName().trim() : "";
        if (trimmedName.isEmpty()) {
            throw new ApiException(HttpStatus.UNPROCESSABLE_ENTITY, "VALIDATION_ERROR", "fullName must not be blank");
        }

        Long seq;
        try {
            seq = visitorRepository.getNextSequenceVal();
        } catch (Exception e) {
            seq = visitorRepository.count() + 1;
        }
        if (seq == null) {
            seq = 1L;
        }

        String referenceCode = String.format("GUEST-%06d", seq);

        Visitor visitor = new Visitor();
        visitor.setFullName(trimmedName);
        visitor.setReferenceCode(referenceCode);
        visitor.setCreatedBy(staffId);
        visitor.setCreatedAt(OffsetDateTime.now());

        Visitor saved = visitorRepository.save(visitor);
        return toDto(saved);
    }

    @Transactional(readOnly = true)
    public VisitorDto getVisitor(UUID visitorId) {
        Visitor visitor = visitorRepository.findById(visitorId)
                .orElseThrow(() -> new ApiException(HttpStatus.NOT_FOUND, "RESOURCE_NOT_FOUND", "Visitor not found: " + visitorId));
        return toDto(visitor);
    }

    @Transactional(readOnly = true)
    public VisitorPage listVisitors(int page, int size, String q, String sort) {
        Sort sortObj;
        if (sort == null || sort.isBlank() || "createdAt,desc".equals(sort)) {
            sortObj = Sort.by(Sort.Direction.DESC, "createdAt");
        } else if ("referenceCode,asc".equals(sort)) {
            sortObj = Sort.by(Sort.Direction.ASC, "referenceCode");
        } else {
            throw new ApiException(HttpStatus.BAD_REQUEST, "INVALID_QUERY", "Invalid sort choice: " + sort);
        }

        if (size < 1) size = 20;
        if (size > 100) size = 100;
        if (page < 0) page = 0;

        String queryTrimmed = (q != null && !q.trim().isEmpty()) ? q.trim() : null;

        PageRequest pageRequest = PageRequest.of(page, size, sortObj);
        Page<Visitor> visitorPage = visitorRepository.searchVisitors(queryTrimmed, pageRequest);

        Set<UUID> creatorIds = visitorPage.getContent().stream()
                .map(Visitor::getCreatedBy)
                .collect(Collectors.toSet());
        Map<UUID, User> userMap = userRepository.findAllById(creatorIds).stream()
                .collect(Collectors.toMap(User::getId, u -> u));

        List<VisitorDto> items = visitorPage.getContent().stream()
                .map(v -> {
                    User creator = userMap.get(v.getCreatedBy());
                    Actor actor = creator != null
                            ? new Actor(creator.getId(), creator.getCode(), creator.getFullName())
                            : new Actor(v.getCreatedBy(), "UNKNOWN", "Unknown");
                    return new VisitorDto(v.getId(), v.getReferenceCode(), v.getFullName(), actor, v.getCreatedAt());
                })
                .toList();

        return new VisitorPage(items, visitorPage.getNumber(), visitorPage.getSize(), visitorPage.getTotalElements(), visitorPage.getTotalPages());
    }

    private VisitorDto toDto(Visitor v) {
        User creator = userRepository.findById(v.getCreatedBy()).orElse(null);
        Actor actor = creator != null
                ? new Actor(creator.getId(), creator.getCode(), creator.getFullName())
                : new Actor(v.getCreatedBy(), "UNKNOWN", "Unknown");
        return new VisitorDto(v.getId(), v.getReferenceCode(), v.getFullName(), actor, v.getCreatedAt());
    }
}
