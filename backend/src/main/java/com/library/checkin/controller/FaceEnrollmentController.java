package com.library.checkin.controller;

import com.library.checkin.dto.*;
import com.library.checkin.security.CurrentPrincipal;
import com.library.checkin.service.FaceEnrollmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.net.URI;
import java.util.List;

@RestController
@RequestMapping("/api/v1/me")
@RequiredArgsConstructor
@Tag(name = "Biometrics", description = "Student biometric consent and enrollment")
public class FaceEnrollmentController {

    private final FaceEnrollmentService faceEnrollmentService;

    @PostMapping("/face-consent")
    @PreAuthorize("hasRole('STUDENT')")
    @Operation(summary = "grantFaceConsent", description = "Grant biometric face consent for student")
    public ResponseEntity<FaceConsent> grantConsent(
            @AuthenticationPrincipal CurrentPrincipal principal,
            @Valid @RequestBody ConsentRequest request
    ) {
        FaceEnrollmentService.ConsentResult result = faceEnrollmentService.grantConsent(principal.getUserId(), request);
        if (result.isNew()) {
            return ResponseEntity.created(URI.create("/api/v1/me/face-enrollment")).body(result.consent());
        }
        return ResponseEntity.ok(result.consent());
    }

    @GetMapping("/face-enrollment")
    @PreAuthorize("hasRole('STUDENT')")
    @Operation(summary = "getMyFaceEnrollment", description = "Get current student face enrollment status")
    public ResponseEntity<FaceEnrollment> getMyEnrollment(
            @AuthenticationPrincipal CurrentPrincipal principal
    ) {
        return ResponseEntity.ok(faceEnrollmentService.getMyEnrollment(principal.getUserId()));
    }

    @PostMapping(value = "/face-enrollment", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @PreAuthorize("hasRole('STUDENT')")
    @Operation(summary = "enrollMyFace", description = "Upload 3-5 images to enroll face biometric")
    public ResponseEntity<FaceEnrollment> enrollMyFace(
            @AuthenticationPrincipal CurrentPrincipal principal,
            @RequestParam("images") List<MultipartFile> images,
            @RequestParam("version") Long version
    ) {
        FaceEnrollment enrollment = faceEnrollmentService.enrollMyFace(principal.getUserId(), images, version);
        return ResponseEntity.ok(enrollment);
    }

    @DeleteMapping("/face-enrollment")
    @PreAuthorize("hasRole('STUDENT')")
    @Operation(summary = "deleteMyFaceEnrollment", description = "Revoke consent and delete enrolled face biometrics")
    public ResponseEntity<FaceDeletion> deleteMyEnrollment(
            @AuthenticationPrincipal CurrentPrincipal principal,
            @RequestParam("version") Long version
    ) {
        FaceDeletion deletion = faceEnrollmentService.deleteMyEnrollment(principal.getUserId(), version);
        return ResponseEntity.ok(deletion);
    }
}
