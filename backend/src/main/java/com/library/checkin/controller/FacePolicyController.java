package com.library.checkin.controller;

import com.library.checkin.dto.FacePolicy;
import com.library.checkin.service.FaceEnrollmentService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/face-policy")
@RequiredArgsConstructor
@Tag(name = "Biometrics", description = "Biometric policies, consent, and face enrollment")
public class FacePolicyController {

    private final FaceEnrollmentService faceEnrollmentService;

    @GetMapping
    @Operation(summary = "getFacePolicy", description = "Current policy version and capture limits")
    public ResponseEntity<FacePolicy> getFacePolicy() {
        return ResponseEntity.ok(faceEnrollmentService.getFacePolicy());
    }
}
