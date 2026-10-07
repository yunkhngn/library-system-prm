# Backend and AI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Implement only when the user requests execution of this plan.

**Goal:** Complete the backend and AI service for the library entry/exit system, run them with Docker, and hand over Swagger so the team can develop the App independently.

**Architecture:** Flutter/kiosks call Spring Boot only. The backend owns authentication, data, and transactions; FastAPI performs recognition/liveness and reads the pgvector candidate view using separate permissions. QR and FACE share one session-management flow; realtime events publish after a successful transaction.

**Tech Stack:** Java 21, Spring Boot 3.3.4, Maven, Spring Security/JWT, JPA + JDBC for vectors, Flyway, PostgreSQL 16 + pgvector, Springdoc 2.6.x, Python 3.11/FastAPI, ONNX Runtime CPU, Docker Compose, JUnit/Testcontainers, and pytest.

**Spec:** [Proposed scope, DB, and contracts](../../backend-ai-spec.md), [additional requirements](../../yeu-cau-bo-sung.md). Original source: the user-provided Word document, version 1.0. This plan does not implement functionality.

**API ready to code:** [API inventory, DTOs, errors, permissions, and tests](../../api/api-mvp-ready-to-code.md) · [Backend OpenAPI](../../api/openapi-mvp.yaml) · [Internal AI OpenAPI](../../api/openapi-ai-internal.yaml). This revision covers **54 backend HTTP operations + 4 internal AI operations + STOMP realtime**. Both OpenAPI files are design contracts preceding implementation; compare them with Swagger exported from the running applications after implementation.

**Required reading order:** this plan → DB spec → API contracts and DTOs for the current task. If an Interfaces summary omits fields, OpenAPI is the authoritative schema source; do not invent DTOs/routes. Spec transaction rules and each API's descriptions/acceptance tests define behavior beyond JSON structure.

## Global Constraints

- Keep the existing monorepo; reuse backend and ai-service without initializing new projects.
- Deliver backend, AI, DB, Docker, and Swagger; the team owns UI/Figma/App.
- Account roles: STUDENT / LIBRARIAN / ADMIN; a kiosk is a separate service principal.
- Apply the new requirement: users have email and a shared code; APIs use code instead of studentCode.
- Do not retain original images or log tokens/images/embeddings; obtain consent before enrollment and support embedding deletion.
- Manage DB migrations with Flyway; Hibernate validates only. Store all timestamps as TIMESTAMPTZ.
- Shift scheduling includes creation, assignment, editing/cancellation, overlap prevention, and schedule viewing; exclude employee attendance, shift swaps, and leave.
- Public Swagger is the single contract source for the App team; describe STOMP events in Swagger description/x-realtime.
- Rules absent from the Word document are identified as initial design decisions in the spec. They have concrete values/behavior for implementation and should not be reselected by implementers. Keep them distinct from the user's original requirements.
- Measure the 1–2 second recognition target on representative kiosk/server hardware; mock tests alone do not establish performance.

## Review Focus

1. Rescans/retries or concurrent kiosks must not accidentally turn check-in into checkout or create two open sessions. Task 5.
2. Account locking/consent revocation during AI processing must invalidate the identity before acceptance. Tasks 3, 10–11.
3. Overnight/overlapping shifts and multi-person shift edits must remain valid in both DB and API. Task 7.
4. AI downtime, missing models, and invalid images/clips must preserve QR availability and never fabricate recognition success. Tasks 1, 9–11.
5. Docker restarts, fresh/existing databases, and amd64/arm64 must not duplicate migrations/seeds; document architecture limitations. Tasks 2, 12.

## 1. Initial-code audit: October 7, 2026

| Component | Observed result | Implication |
|---|---|---|
| Backend source | Entrypoint only; controller/service/entity/repository/config are empty | Reusable foundation; no business APIs yet |
| Maven/Java | Java 21 and Maven are available; mvn -B verify succeeded, produced an executable Spring Boot JAR, and passed 1 test | Backend builds; the test only asserts assertTrue(true), without verifying DB/security startup |
| Offline packaging | Initial repackage failed because the cache lacked a plugin dependency; an online run resolved it | Dependency-cache limitation, not an initial-code compilation failure |
| AI source | TestClient health, verify, and openapi requests all returned 200 | verify returns fixed SV2026001 even without an image; it is a mock |
| AI dependencies | FastAPI/pytest/httpx are installed; OpenCV, ONNX Runtime, and InsightFace are absent from the current Python environment | Sample endpoints run; real inference cannot run in this environment yet |
| DB | No migrations/entities; only datasource configuration and ddl-auto=validate | No schema for business testing yet |
| Docker Compose | docker compose config --quiet passed | Configuration is valid; this does not establish healthy service startup |
| Docker Engine | Docker Desktop running on linux/arm64 | Build checks are possible; amd64 remains unverified |
| Current image build | The library-init-audit build downloaded base images and started downloading Maven/Python dependencies; it was deliberately stopped before completion, exit 130 | Image build success is unconfirmed; this is not a demonstrated build failure. No project containers were started |

Initial-code gaps to address:

- README refers to ./mvnw, but backend lacks mvnw/mvnw.cmd; only wrapper properties exist.
- Backend lacks springdoc/actuator/JWT filter/SecurityFilterChain; default security is not business authentication.
- postgres:16-alpine does not provide pgvector required for recognition.
- Current Compose starts the client when all services are started; backend depends on AI service_started without dedicated health checks.
- Python uses >= for every dependency and the base image uses a moving tag; builds are not exactly reproducible.
- Python does not read the Compose face threshold; PORT/HOST do not change the hard-coded startup command. Backend Dockerfile sets PORT, while application.yml reads SERVER_PORT.
- JWT_EXPIRATION defaults to 24 hours; separate access/refresh lifetimes and avoid sample secrets outside dev.
- .env API_BASE_URL is not passed into Flutter builds; it does not prove App connectivity.
- AI CORS allows every origin, conflicting with the internal API architecture; the App will call the backend with an allowlist.
- At the initial audit, .gitignore excluded all /docs. The ready-to-code plan added exceptions for the spec/plan/additional requirements and docs/api so Git can track them; no commit/push yet.

## 2. Implementation order and handover milestones

| Milestone | Tasks | Deliverables |
|---|---|---|
| M0 — Team foundation | 1–2 | Dedicated Docker setup, health, Swagger, migrated schema |
| M1 — App integration begins | 3–5 | Sample accounts, code/email login, kiosks, QR, and complete entry/exit session flow |
| M2 — Management workflows | 6–8 | Realtime, manual/guest access, shifts, configuration, history/statistics |
| M3 — Real AI | 9–11 | Enrollment, liveness, matching, fallback, and complete multipart Swagger |
| M4 — Stable handover | 12 | Versioned images, integration tests, Swagger matching runtime behavior |

At M1, the team can build the App using real APIs without waiting for AI completion. Early Swagger can be provided after M0, but only mark endpoints actually implemented at each milestone as available.

## 3. Planned file layout

Follow the existing backend packages; do not restructure solely for appearance.

- backend/src/main/java/com/library/checkin/config/: SecurityConfig, OpenApiConfig, WebSocketConfig, RestClientConfig.
- controller/: AuthController, UserController, KioskController, AccessController, OccupancyController, ShiftController, SystemConfigController, AnalyticsController, FaceEnrollmentController.
- service/: AuthService, UserService, KioskService, AccessService, QrService, ShiftService, SystemConfigService, AnalyticsService, AutoCheckoutService, FaceEnrollmentService, AiClient.
- service/strategy/: CheckInStrategy, QrCheckInStrategy, FaceCheckInStrategy.
- entity/, repository/, dto/: separate files for each corresponding data/API type. repository/FaceEmbeddingRepository uses JDBC parameter binding for pgvector; do not force vectors into strings through ordinary JPA.
- security/: JwtService, JwtAuthenticationFilter, KioskAuthenticationFilter, CurrentPrincipal.
- exception/: ApiException, ApiError, GlobalExceptionHandler.
- event/: OccupancyChangedEvent, OccupancyEventListener.
- backend/src/main/resources/db/migration/: V1__core_schema.sql, V2__shift_schema.sql, V3__biometric_schema.sql.
- backend/src/main/resources/application-dev.yml and application-test.yml: separate profiles; dev seeding in service/DevSeedService.java.
- ai-service/app/core/: settings.py, security.py, model_registry.py.
- ai-service/app/models/: schemas.py; app/services/: image_decoder.py, embedding_service.py, liveness_service.py, matching_service.py; app/repositories/: candidates.py; app/api/v1/: health.py, enrollment.py, recognition.py.
- ai-service/tests/: test_health.py, test_upload_validation.py, test_embeddings.py, test_matching.py, test_liveness.py.
- compose.dev.yml, compose.test.yml, scripts/dev-up.sh, scripts/dev-down.sh, scripts/test-stack.sh, tests/contracts/conftest.py and test_*.py.

## 4. Implementation tasks

### Task 1: Docker foundation, health, and Swagger

**Files:** modify backend/pom.xml, backend/Dockerfile, ai-service/Dockerfile, ai-service/app/main.py; create compose.dev.yml, backend/src/main/resources/application-dev.yml, config/OpenApiConfig.java, config/SecurityConfig.java, ai-service/app/api/v1/health.py, scripts/dev-up.sh, scripts/dev-down.sh, tests/contracts/test_health.py. Java paths in tasks are relative to backend/src/main/java/com/library/checkin/.

**Interfaces:** GET /actuator/health; GET /swagger-ui/index.html; GET /v3/api-docs. Keep AI GET /api/v1/health for liveness and add GET /api/v1/ready for readiness.

- [ ] Write HTTP health/docs tests and a test that backend remains ready when AI is unavailable; run them to demonstrate missing routes.
- [ ] Add Springdoc 2.6.0 and Actuator; allow docs/health access in dev. Do not permitAll business APIs.
- [ ] Create compose.dev.yml with pgvector PostgreSQL 16 and DB/backend/AI health checks; remove container_name, use environment-configured ports and project-specific volumes. Do not include the App yet.
- [ ] Add explicit mock/real modes; backend startup waits only for healthy DB, not healthy AI. Backend readiness includes DB/schema health.
- [ ] Add dev commands, verify Swagger access, and commit the foundation milestone.

```xml
<dependency>
  <groupId>org.springdoc</groupId>
  <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
  <version>2.6.0</version>
</dependency>
<dependency>
  <groupId>org.springframework.boot</groupId>
  <artifactId>spring-boot-starter-actuator</artifactId>
</dependency>
```

Verification: docker compose -f compose.dev.yml up -d --build postgres backend ai-service; curl -f http://localhost:8080/v3/api-docs; docker compose -f compose.dev.yml stop ai-service, then check backend health and restart AI. Do not run these commands against another project's Compose stack.

### Task 2: Migrations and DB verification

**Files:** create db/migration/V1__core_schema.sql, V2__shift_schema.sql, V3__biometric_schema.sql; entity/SystemConfigEntity.java, repository/SystemConfigRepository.java, service/SystemConfigService.java (configuration reads), dto/SystemConfig.java; backend/src/test/java/com/library/checkin/DatabaseMigrationIT.java; modify backend/pom.xml to add Testcontainers PostgreSQL/JUnit and Maven Failsafe for *IT. Add scripts/db-bootstrap.sql to provision the AI role from environment variables; never put passwords in migrations.

**Interfaces:** complete schema in the spec; read-only ai_face_candidates view; Flyway runs before JPA validation. Define tables first and module entities in their corresponding tasks.

- [ ] Write real-DB integration tests: empty-database migration, second migration run, vector/btree_gist extensions, unique code/email, partial unique open sessions, overlapping-shift exclusion, and AI read permissions. Run them to record failure before the schema exists.
- [ ] Create the exact tables/constraints in the spec. Normalized, UNIQUE, NOT NULL code/email are the proposed defaults; do not add username/student_code.
- [ ] V1 creates users/refresh/kiosks/visitors/checkin_logs/access_requests/qr_grants/system_config/library_state/audit_events; V2 creates shifts/shift_assignments + exclusion; V3 creates consent/embeddings/challenges/recognition_attempts/view. Seed operational configuration and policy via migration as specified; do not enable FACE with fabricated calibration data.
- [ ] Implement SystemConfigService.getOperational() and the DB read DTO in this task for later kiosk/access modules; task 8 adds writes/REST/audit. Name the entity SystemConfigEntity to avoid colliding with dto/SystemConfig; repository: SystemConfigRepository<SystemConfigEntity,String>.
- [ ] Provision the AI role and GRANT SELECT on the view after migration through a bootstrap job dependent on backend healthy; real AI starts DB reads after bootstrap. QR does not depend on AI bootstrap.
- [ ] Test transaction rollback and migration from an earlier schema containing data; do not use baseline to conceal schema drift.
- [ ] Run mvn verify and restart Compose with its volume preserved; commit migrations.

Minimum SQL verification after migration:

```sql
SELECT extname FROM pg_extension WHERE extname IN ('vector', 'btree_gist');
SELECT version, success FROM flyway_schema_history ORDER BY installed_rank;
SELECT tablename FROM pg_tables WHERE schemaname = 'public';
SELECT indexname FROM pg_indexes WHERE indexname IN ('uq_open_user_session', 'uq_open_visitor_session');
```

Pass when DB rejects two open sessions for the same person and overlapping assignments, accepts adjacent shifts, and prevents the AI DB role from reading password_hash.

### Task 3: Login, refresh, users, and dev data

**Files:** create controller/AuthController.java, UserController.java; service/AuthService.java, UserService.java, DevSeedService.java; security/JwtService.java, JwtAuthenticationFilter.java; entity/User.java, RefreshToken.java; repository/UserRepository.java, RefreshTokenRepository.java; exception/GlobalExceptionHandler.java, ApiError.java; backend/src/test/java/com/library/checkin/AuthIT.java; tests/contracts/conftest.py, test_auth.py.

**Interfaces:** POST /auth/login, /auth/refresh, /auth/logout; GET /me; PUT /me/password; GET/POST /users; GET/PATCH /users/{userId}; PUT /users/{userId}/password; prefix /api/v1. LoginRequest/TokenPair/User/PatchUserRequest/ResetPasswordRequest schemas are in OpenAPI. User responses include code/email/mustChangePassword/faceEnrolled/version, never password/hash.

- [ ] Test code/email login, normalization/duplicate code-email, wrong passwords, expiry, refresh rotation/replay, logout, LOCKED users, 403 for students on Admin APIs, and prevention of reading others' histories.
- [ ] BCrypt passwords; separate token purposes/audiences; store refresh hashes in DB; rotate/revoke families transactionally. Codes must not contain @ to avoid email ambiguity.
- [ ] Implement personal password changes and Admin resets; auth_version/must_change_password, JWT sid, fixed family expiry, and immediate access-token revocation follow the spec. Test forced-change restrictions for me/password and permitted auth/me operations until password change completes.
- [ ] Add Admin user CRUD and protect the last Admin from locking/demotion; students only read their own profiles. Only Admin can update code/email/role.
- [ ] Idempotent dev-profile seed only: AD001/admin@example.test, LIB001/librarian@example.test, SV001/student@example.test; use DEV_SEED_PASSWORD from .env. Do not seed production accounts.
- [ ] Update Swagger examples/Authorize/errors; run mvn verify and pytest test_auth; commit auth/users.

Example login contract:

```json
{"identifier":"LIB001","password":"<DEV_SEED_PASSWORD value>"}
```

### Task 4: Kiosk devices and rotating QR

**Files:** create controller/KioskController.java, service/KioskService.java, QrService.java; security/KioskAuthenticationFilter.java; entity/Kiosk.java, QrGrant.java; repository/KioskRepository.java, QrGrantRepository.java; backend/src/test/java/com/library/checkin/QrIT.java; tests/contracts/test_qr.py.

**Interfaces:** GET/POST /kiosks; GET/PATCH /kiosks/{kioskId}; POST /kiosks/{kioskId}/rotate-credential; POST /kiosks/token, /kiosks/heartbeat; GET /kiosks/me/config; POST /me/qr. Kiosk/KioskCredential/KioskToken/KioskRuntimeConfig/QrToken schemas are in OpenAPI. Check kiosk status/mode/credentialVersion server-side on every request; return secrets once, without idempotency-store replay.

- [ ] Test expired QR, tampered signatures, access tokens misused as QR, locked QR owners, REVOKED kiosks, and invalidation of rotated credentials.
- [ ] Issue 30-second QR tokens with hashed nonces; only ACTIVE STUDENT users may request them. Clients render QR images from tokens; backend need not return PNG.
- [ ] Authenticate kiosks separately; heartbeat updates last_seen_at, derive offline status from timeout, and obtain kioskId from the principal rather than body.
- [ ] Document kiosk/student Swagger authorization; run tests and commit kiosk/QR. Consume nonces only within task 5's transaction.

### Task 5: Shared entry/exit sessions and duplicate protection

**Files:** create controller/AccessController.java; service/AccessService.java, AccessRequestService.java, OccupancyStateService.java; service/strategy/CheckInStrategy.java, QrCheckInStrategy.java, IdentityProof.java, AccessCommand.java; dto/AccessResult.java, AccessRequestStatus.java; event/OccupancyChangedEvent.java; entity/CheckinLog.java, AccessRequest.java, LibraryState.java; repository/CheckinLogRepository.java, AccessRequestRepository.java, LibraryStateRepository.java; backend/src/test/java/com/library/checkin/AccessConcurrencyIT.java; tests/contracts/test_access.py.

**Interfaces:** POST /access/qr {token}, Idempotency-Key UUID/kiosk auth; GET /access/requests/{idempotencyKey} for the key's owning principal (KIOSK/LIBRARIAN/ADMIN). CheckInStrategy<I>.authenticate(I) → IdentityProof; AccessService.record(AccessCommand) → AccessResult. IdentityProof carries QR/FACE/MANUAL proof for transaction-lock revalidation (section 8), rather than just UUID. AccessResult/AccessRequestStatus follow OpenAPI; request status recovers results without resending clips/QR.

- [ ] Test entry/exit, same-key retries, different payload with same key 409, different keys within cooldown 409 SCAN_TOO_SOON, QR reuse, concurrent kiosks, ENTRY/EXIT state mismatch, and checkout outside opening hours.
- [ ] Claim unique idempotency in a short transaction before inference; processing deadline 60 seconds, retention 24 hours; REQUEST_IN_PROGRESS/REQUEST_ABORTED and recovery are specified in the spec. Verify HMAC payload+method+path; do not store secrets/raw uploads.
- [ ] Finalize in order: access_request → library_state → user/visitor → session/token. Validate QR, consume nonce, create/close session, increment revision, and store response in one transaction. Rollback preserves QR; replay results before QR/challenge expiry checks, while still requiring principal authorization.
- [ ] Publish OccupancyChangedEvent after commit; AccessRequest stores only a digest, not images/QR. Responses include code, not studentCode.
- [ ] Test with real PostgreSQL rather than only repository mocks; update Swagger retry/cooldown rules and commit access core.

```python
def test_retry_does_not_toggle(kiosk, student):
    from uuid import uuid4
    qr = student.post('/api/v1/me/qr').json()['token']
    headers = {'Idempotency-Key': str(uuid4())}
    a = kiosk.post('/api/v1/access/qr', json={'token': qr}, headers=headers)
    b = kiosk.post('/api/v1/access/qr', json={'token': qr}, headers=headers)
    assert a.status_code == b.status_code == 200
    assert a.json() == b.json()
    assert a.json()['action'] == 'CHECK_IN'
```

The student/kiosk fixtures in conftest log in using seeded accounts and test credentials; create a dedicated student or reset the test volume before this suite. Do not use existing dev data.

### Task 6: Dashboard, realtime, history, and manual access

**Files:** create controller/OccupancyController.java, VisitorController.java; config/WebSocketConfig.java; event/OccupancyEventListener.java; entity/Visitor.java; repository/VisitorRepository.java; extend controller/AccessController.java and service/AccessService.java, OccupancyStateService.java; OccupancyChangedEvent already exists from task 5; backend/src/test/java/com/library/checkin/OccupancyIT.java, WebSocketIT.java; tests/contracts/test_manual.py.

**Interfaces:** GET /occupancy, /occupancy/people; GET /me/access-status, /me/access-history, /me/access-history/{sessionId}; GET /access-history, /access-history/{sessionId}; GET/POST /visitors, GET /visitors/{visitorId}; POST /access/manual. Public prefix /api/v1; staff MANUAL/HISTORY access is limited to LIBRARIAN/ADMIN. STOMP /ws, /topic/occupancy; schemas/events/roles/filters/sort/time ranges are defined in OpenAPI.

- [ ] Test code/name search, pagination/time ranges, history ownership, guests without accounts/student codes, correct directional manual actors, and idempotency.
- [ ] Test personal presence status (currentSession=null outside), history ownership 404, existing-guest search without name merging, and manual checkout for LOCKED users with reasons in each direction. New fields are already in the DB spec; occupancy omits email.
- [ ] Test rejection of WebSocket CONNECT/SUBSCRIBE without JWT, STUDENT occupancy subscriptions, and events after transaction rollback.
- [ ] Implement REST snapshots, history, and visitors; preserve CHECK XOR identity in DB. Manual actions are explicit, without toggling.
- [ ] Implement after-commit events; reconnect fetches REST snapshots; Swagger description/x-realtime includes JSON payloads and full STOMP authentication.
- [ ] Run REST/WebSocket tests and commit dashboard/manual access.

### Task 7: Staff shift scheduling

**Files:** create controller/ShiftController.java; service/ShiftService.java; entity/Shift.java, ShiftAssignment.java; repository/ShiftRepository.java, ShiftAssignmentRepository.java; backend/src/test/java/com/library/checkin/ShiftIT.java; tests/contracts/test_shifts.py.

**Interfaces:** GET/POST /shifts; GET/PATCH /shifts/{shiftId}; POST /shifts/{shiftId}/cancel; GET/POST /shifts/{shiftId}/assignments; PATCH/DELETE /shifts/{shiftId}/assignments/{assignmentId}; GET /me/shifts. ADMIN owns writes/system-wide lists; LIBRARIAN reads their own schedule and assigned shift details. Shift/Assignment/MyShiftPage schemas, DELETE version query, shift/assignment versions, and staffId/status/date filters are fixed in OpenAPI.

- [ ] Test staff codes in responses, rejection of LOCKED/STUDENT assignees, end before start, overnight shifts, adjacent shifts, and overlaps.
- [ ] Test concurrent Admin assignments for the same staff member; shift-time changes causing overlap roll back both shift and assignments; shift/assignment times cannot diverge.
- [ ] Lock shifts/staff in a stable order; copy starts_at/ends_at to assignments in one transaction; the exclusion constraint is the final safeguard.
- [ ] Use versions to return 409 for stale updates; shift cancellation cancels assignments but preserves history. Do not block librarian login outside shifts.
- [ ] PATCH assignment replaces staff atomically, without requiring DELETE then POST; failed replacement retains the old staff. GET detail/assignments enforces ownership/roles. Every assignment change increments assignment/shift versions.
- [ ] Add Swagger examples with +07:00 timestamps and SHIFT_OVERLAP; run tests and commit scheduling.

```json
{"name":"Evening shift","startsAt":"2026-10-07T18:00:00+07:00","endsAt":"2026-10-08T00:30:00+07:00"}
```

### Task 8: Configuration, automatic checkout, and analytics

**Files:** create controller/SystemConfigController.java, AnalyticsController.java; service/AutoCheckoutService.java, AnalyticsService.java; extend service/SystemConfigService.java from task 2; backend/src/test/java/com/library/checkin/ConfigIT.java, AutoCheckoutIT.java; tests/contracts/test_config.py.

**Interfaces:** GET/PATCH /system-config; GET /analytics/access?from=...&to=...&bucket=DAY|HOUR; GET /analytics/recognition?from=...&to=.... Configuration includes openingHours, maxCapacity, nearCapacityRatio, capacityEnforcement, maxSessionDurationMinutes, faceMaxCosineDistance, livenessMinScore, scanCooldownSeconds.

- [ ] Test negative values, out-of-range thresholds, stale versions, and ADMIN-only updates; closing times/statistical days use Asia/Ho_Chi_Minh.
- [ ] Validate JSONB schemas by key; read configuration at runtime without restart. Seed configuration has versions and actor audit.
- [ ] Automatic checkout locks sessions, records CLOSING_TIME/MAX_DURATION, runs safely again, and publishes occupancy after commit. Missing student heartbeat does not imply inactivity.
- [ ] Derive FACE/QR/MANUAL statistics from logs and failure rates from recognition_attempts (populated in task 11); successful logs alone cannot measure failures. Count by entry day/hour and calculate duration from closed sessions.
- [ ] Test automatic-close/kiosk-checkout races and concurrent capacity enforcement; commit operational management.

### Task 9: AI contracts and input validation

**Files:** create ai-service/app/core/settings.py, security.py; app/models/schemas.py; app/api/v1/enrollment.py, recognition.py; app/services/image_decoder.py; ai-service/tests/test_upload_validation.py, test_health.py; modify app/main.py and requirements.txt.

**Internal interfaces:** GET /api/v1/health (public process liveness), GET /api/v1/ready (service auth); POST /api/v1/embeddings multipart images; POST /api/v1/recognize multipart clip+challengeId+challengeInstructions (JSON part)+modelVersion+maxCosineDistance+minDistanceGap+livenessMinScore. Separate AI OpenAPI defines complete DTOs/inputs/contentType. Header X-Service-Key, backend only; remove the existing fixed /verify endpoint.

- [ ] Test missing/invalid service keys, missing files, invalid MIME/fake images, oversized uploads, image bombs, no/multiple faces, undecodable clips, and unready models.
- [ ] Proposed limits: JPEG/PNG ≤5 MB/image, ≤25 MB total, ≤16 megapixels; MP4 ≤10 MB, 1–3 seconds, no audio. Validate decoded content rather than trusting extensions/MIME.
- [ ] FastAPI Pydantic schemas/errors follow contract naming; embedding response {embeddings,dimension:512,modelId,modelVersion}; do not expose enrollment endpoints directly to the App.
- [ ] Explicit simulated=true for mock recognition; backend must not record real FACE from mock results. Real mode with unready models returns 503 MODEL_NOT_READY, never default verified=true.
- [ ] Validate incoming multipart and outgoing AI responses: matched/outcome/userId/consentId/biometricVersion/liveness/modelVersion must be consistent; invalid AI schemas become 503 AI_UNAVAILABLE without session writes.
- [ ] Lock dependencies, write pytest/internal OpenAPI, and commit the AI contract.

Verification: python -m pytest ai-service/tests/test_upload_validation.py ai-service/tests/test_health.py -q in the locked-dependency environment or test image. Existing sample endpoints are insufficient to pass this task.

### Task 10: Embedding models, enrollment, consent, and matching

**Files:** create ai-service/app/core/model_registry.py; app/services/embedding_service.py, matching_service.py; app/repositories/candidates.py; app/models/manifest.json; ai-service/tests/test_embeddings.py, test_matching.py; backend controller/FaceEnrollmentController.java, service/FaceEnrollmentService.java, AiClient.java, repository/FaceEmbeddingRepository.java; backend/src/test/java/com/library/checkin/EnrollmentIT.java.

**Public interfaces:** GET /face-policy; POST /me/face-consent; GET/POST/DELETE /me/face-enrollment. FacePolicy/FaceConsent/FaceEnrollment/FaceDeletion schemas are in OpenAPI; POST multipart images+version, DELETE query version; version is users.biometric_version. STUDENT accesses their own data only; DELETE revokes consent and deletes embeddings while preserving history.

- [ ] Select a 512-dimensional ArcFace model running on ONNX CPU; verify artifacts/license/hashes and detector/preprocessing; record model/version and usage conditions in the manifest. Public InsightFace pretrained models have non-commercial research restrictions in the [official model zoo](https://github.com/deepinsight/insightface/blob/master/python-package/docs/model_zoo.md); verify suitability before selecting weights.
- [ ] Test embedding dimensions/finite/nonzero/norm and same-person/different-person images from a representative consented dataset; synthetic fixtures cannot establish accuracy.
- [ ] Test enrollment without consent, wrong roles, 2 or 6 images, one invalid image preserving old data, consent deletion removing candidates, and concurrent deletion/locking during enrollment causing rollback/rejection.
- [ ] Load models once at startup, verify checksums, and cache via volumes; readiness reflects the actual model. AI uses a read-only connection and exact cosine distance, grouping by person rather than treating two images of one person as different candidates.
- [ ] Enrollment takes user identity from JWT rather than arbitrary userId; persist consent/model/embeddings transactionally. Do not treat face_enrolled as independent data.
- [ ] Make consent grants idempotent (existing 200/new 201); revoke/re-enroll under user locks and increment biometricVersion. The AI view returns consentId/biometricVersion without gallery caching. Test rejection of old-enrollment candidates after deletion/re-enrollment.
- [ ] Calibrate thresholds using FAR/FRR and an identity margin if supported by data; record measured configuration and do not label cosine distance as probability.
- [ ] Run tests and measure detector/extractor/query latency; commit enrollment/matching.

### Task 11: Real liveness, end-to-end FACE, and fallback

**Files:** create ai-service/app/services/liveness_service.py; ai-service/tests/test_liveness.py; backend service/strategy/FaceCheckInStrategy.java; extend AiClient.java, AccessController.java, AccessService.java; entity/RecognitionAttempt.java; repository/RecognitionAttemptRepository.java; backend/src/test/java/com/library/checkin/FaceAccessIT.java; tests/contracts/test_face.py.

**Interfaces:** POST /access/face-challenge → FaceChallenge; POST /access/face multipart clip+challengeId and Idempotency-Key. AI InternalRecognitionResult includes consentId/biometricVersion/distanceGap/model versions; public result: AccessResult. Both OpenAPI files define all error codes/upload limits/fallback rules.

- [ ] Complete a liveness spike using clips/challenges and a verified anti-spoofing model: reject printed photos, screen/video replay, old clips, and expired/wrong-kiosk challenges. Until a solution passes, FACE cannot write real access logs; QR remains usable.
- [ ] Use one-time server-generated challenges bound to kiosk/expiry; limit concurrent requests/inference to protect backend resources. Bound total timeout and use consistent error codes.
- [ ] Persist face_challenges (TTL 60 seconds, BLINK then TURN_LEFT/RIGHT, config/modelVersion), rather than memory only. Clips: 1–3 seconds, ≤10MiB, 1280x720, 30fps; backend sends DB instructions to AI. Bound total recognition requests to 15 seconds and inference queues to at most one running request per kiosk; terminal outcomes consume challenges, while timeouts store 503 without session writes.
- [ ] Accept candidates only when livenessPassed, matched, valid model, and simulated=false; lock users and recheck ACTIVE/consent/enrollment. Resolve retries through idempotency before challenge consumption.
- [ ] Reuse task 5's AccessService rather than duplicating session logic. Failures write recognition_attempts without checkin_logs; AI timeout leaves session state unchanged.
- [ ] Keep QR available; Swagger instructs the App to recommend QR after two face failures and immediately when AI is unavailable. Backend returns attempt outcomes; kiosk UI decisions belong to the App.
- [ ] Run enrollment → recognition → entry/exit end to end; test QR during AI downtime; measure p50/p95 and FAR/FRR on representative hardware; commit FACE integration.

### Task 12: Reproducible Docker, full testing, and Swagger handover

**Files:** modify backend/Dockerfile, ai-service/Dockerfile, .env.example, .gitignore, README.md; add backend/mvnw, backend/mvnw.cmd; compose.test.yml, scripts/test-stack.sh, scripts/export-openapi.sh, docs/api/openapi.json; tests/contracts/test_schema.py.

**Handover interfaces:** one dev command, Swagger UI, versioned OpenAPI JSON, sample accounts through dev seeding, and AI mock/real configuration. The commands below are implementation targets, not existing scripts.

- [ ] Add functional Maven Wrapper files; remove go-offline || true that hides errors; control dependency caching. Image builds do not replace verification.
- [ ] Lock Python dependencies, pin base images/model checksums/build tags, and test CPU dev on arm64/amd64; document tested architectures. GPU is a separate profile if needed, not required for every teammate.
- [ ] compose.test.yml uses dedicated projects/volumes/ports; run mvn verify, AI pytest, HTTP contracts, and STOMP tests. Do not reset dev DB; clean only test-project volumes.
- [ ] Test data-preserving restarts, fresh/existing DB migrations, idempotent seeding, AI/DB downtime, token expiry, and session/shift contention; verify sensitive data is absent from logs.
- [ ] Export OpenAPI from running applications; Swagger covers tags, roles, DTO examples, errors, multipart, pagination, Idempotency-Key, kiosk auth, and realtime descriptions. Do not publish unimplemented endpoints.
- [ ] Verify .gitignore exceptions preserve the spec/plan/contracts/export and keep handover documents tracked.
- [ ] Write a concise README covering Docker start/stop, port conflicts, env, mock/real, seeding, and emulator/phone hosts; keep Swagger as the team's API documentation.
- [ ] Review requirement → test/API mapping, update audit findings, and commit handover. Do not push images until the team selects a registry destination.

```bash
cp .env.example .env
./scripts/dev-up.sh
# Swagger: http://localhost:8080/swagger-ui/index.html
./scripts/test-stack.sh
./scripts/export-openapi.sh
./scripts/dev-down.sh
```

## 5. Shared contract tests

Task 3 creates tests/contracts/conftest.py so subsequent tests authenticate against real APIs; take secrets from the dev/test environment. Example fixture without requiring App code:

```python
import os
import httpx
import pytest

@pytest.fixture
def admin():
    base = os.environ.get('API_BASE_URL', 'http://localhost:8080')
    with httpx.Client(base_url=base, timeout=15) as client:
        response = client.post('/api/v1/auth/login', json={
            'identifier': 'AD001',
            'password': os.environ['DEV_SEED_PASSWORD'],
        })
        assert response.status_code == 200, response.text
        client.headers['Authorization'] = 'Bearer ' + response.json()['accessToken']
        yield client

def test_swagger_declares_bearer(admin):
    schema = admin.get('/v3/api-docs').json()
    assert schema['components']['securitySchemes']['bearerAuth']['scheme'] == 'bearer'
```

Student fixtures create unique test accounts via Admin; kiosk fixtures register test devices, receive credentials once, obtain tokens, and attach Bearer headers. Each test writes its own data. Java/AI unit tests check logic quickly; Testcontainers/Compose verify real transactions/DB behavior. H2 cannot establish pgvector/range-constraint correctness.

## 6. Completion criteria

- [ ] Teammates clone → fill .env → run one Docker command → access Swagger.
- [ ] Real APIs/tests cover code/email login, user/kiosk CRUD, QR entry/exit, history, manual/guest access, realtime, configuration, automatic checkout, analytics, and shifts.
- [ ] Never two open sessions per person; duplicate scans do not toggle state; overlapping shifts are rejected even under concurrent writes.
- [ ] Enrollment requires consent and supports deletion; images are not retained; real matching/liveness is verified; mocks are marked and cannot create real FACE logs.
- [ ] Swagger enables App development without reading backend source; realtime instructions are in the same documentation.
- [ ] All 54 backend and 4 AI design operationIds have implementations/tests, including detail/profile/password/visitor/assignment/request-status APIs. Runtime Swagger matches contract paths/DTOs/errors/roles.
- [ ] Docker image versions and DB migrations are reproducible; report results for each architecture and any remaining AI quality/latency limits.

## 7. Verified technical references

- [Springdoc compatibility matrix](https://springdoc.org/v2/#what-is-the-compatibility-matrix-of-springdoc-openapi-with-spring-boot).
- [pgvector: Docker, cosine distance, and indexes](https://github.com/pgvector/pgvector).
- [PostgreSQL partial indexes](https://www.postgresql.org/docs/16/indexes-partial.html), [range/exclusion constraints](https://www.postgresql.org/docs/16/rangetypes.html#RANGETYPES-CONSTRAINT).
- [Docker Compose startup/readiness](https://docs.docker.com/compose/how-tos/startup-order/), [multi-platform builds](https://docs.docker.com/build/building/multi-platform/).
- [OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3), [InsightFace model zoo](https://github.com/deepinsight/insightface/blob/master/python-package/docs/model_zoo.md).

## 8. Module interfaces for implementation

Public/internal DTOs use the exact component names in both OpenAPI files; Java records and Pydantic models match types/required/nullable/enums. Never return JPA entities directly. Map checkin_logs.method → AccessSession.checkInMethod; visitors.reference_code → Subject.code for kind=VISITOR.

Place the following domain types in service/strategy, one top-level type per file. Define them all in task 5 for tasks 6/11; do not delay AccessService signature changes until FACE:

```java
enum AccessMethod { FACE, QR, MANUAL }
enum AccessAction { AUTO, CHECK_IN, CHECK_OUT }
enum SubjectKind { USER, VISITOR }
sealed interface IdentityProof permits QrProof, FaceProof, ManualProof {}
record QrProof(java.util.UUID userId, java.util.UUID qrGrantId)
    implements IdentityProof {}
record FaceProof(java.util.UUID userId, java.util.UUID consentId,
                 long biometricVersion, java.util.UUID challengeId,
                 String modelVersion) implements IdentityProof {}
record ManualProof(java.util.UUID subjectId, SubjectKind kind,
                   java.util.UUID actorUserId, String reason)
    implements IdentityProof {}
record AccessCommand(java.util.UUID requestId, CurrentPrincipal principal,
                     AccessAction action, IdentityProof proof) {}
interface CheckInStrategy<I> {
    AccessMethod method();
    IdentityProof authenticate(I input);
}
```

CurrentPrincipal (security/CurrentPrincipal.java, tasks 3–4) is a record {PrincipalType USER/KIOSK, UUID id, UUID familyId nullable, Long authVersion nullable, Long credentialVersion nullable, String role nullable}; kiosks do not impersonate user roles. Strategy authenticate verifies identity; AccessService.record(AccessCommand) exclusively owns session changes/capacity/idempotency finalization. Controllers do not create logs directly through repositories.

- QrCheckInStrategy<QrAccessRequest> → QrProof; never consume nonces outside AccessService.
- FaceCheckInStrategy<FaceRecognitionInput> → FaceProof. FaceRecognitionInput is a record {UUID kioskId, UUID challengeId, byte[] clip, String clipMimeType, List<ChallengeInstruction> instructions, SystemConfig config}; backend constructs it from verified principal/DB data, not user-supplied JSON.
- Manual access does not invoke AI/QR strategies; AccessController checks staff role and creates ManualProof + CHECK_IN/CHECK_OUT; AccessService revalidates the subject/session under locks.
- AccessRequestService.claim(principal, UUID key, String method, String path, String digest) returns AccessClaim {UUID requestId, ClaimState NEW/IN_PROGRESS/COMPLETED, Integer responseStatus nullable, String responseBody nullable}. Authenticate only for NEW; IN_PROGRESS returns 409; COMPLETED replays. Never infer twice for one key.
- OccupancyStateService.snapshot() → Occupancy DTO; AccessService finalization reads snapshot/revision while holding the library_state lock. REST GET uses a consistent transaction snapshot; WebSocket listeners send the event's existing snapshot rather than recounting with an old revision.
- SystemConfigService.getOperational() → SystemConfig DTO (task 2); task 8 adds update(PatchSystemConfigRequest, CurrentPrincipal) → SystemConfig. DB seed defaults are fixed in the spec.
- AiClient.getReadiness() → AiReadiness; extractEmbeddings(List<ImageUpload>) → InternalEmbeddingResult; recognize(FaceRecognitionInput) → InternalRecognitionResult. ImageUpload is a record {String filename, String contentType, byte[] bytes}; enforce limits before allocation/decoding.
- AiClient validates schemas/types/model/normalized512/liveness and does not treat distance as probability. Readiness probe timeout: 1 second; connect: 2 seconds; inference read: 8 seconds; public FACE request total: 15 seconds. Do not automatically retry inference within the same request, avoiding queue growth when AI slows down.

### Fixed AI outcome rules

- Challenge: BLINK then TURN_LEFT/RIGHT, order 1/2; liveness requires both dynamic challenge completion and model-based anti-spoofing. Static face detection is insufficient. Manifest includes recognition/detector/liveness model IDs, versions, hashes, preprocessing/input/output shapes, and calibrated thresholds, verified at startup.
- Group candidates by distinct user, using each person's minimum embedding distance; reject ties between people. With two or more identities, gap=d2−d1 must be >=faceMinDistanceGap; with one identity, gap=null and apply distance/liveness only. No candidates → NO_MATCH. Vectors must be finite, nonzero, and L2-normalized.
- Internal MATCHED requires non-null userId/consentId/biometricVersion/modelVersion, matched=true, and livenessPassed=true. NO_MATCH: matched=false, userId/consentId/biometricVersion=null, livenessPassed=true. LIVENESS_FAILED: matched=false, identity=null, livenessPassed=false. Backend maps the latter two to 422 with fallbackRecommended=true and no session writes.
- Backend rechecks challenge/config/model/consent/biometricVersion under locks before finalization. Configuration changed since challenge issuance → 422 CHALLENGE_INVALID, requiring a new challenge; enrollment changed → 409 ENROLLMENT_CHANGED. Return 503 for missing models/calibration, mock results, or unavailable DB reads.
- Enrollment consistency threshold is required in the calibrated manifest; do not disguise an arbitrary default as a verified threshold. Missing valid model parameters → 503 MODEL_NOT_READY. The API contract is ready to code; model binaries/recognition quality are verified in tasks 10–11.

### Per-task gates

- [ ] Retrieve every operationId with the task's x-task from YAML (inventory in section 2 of API ready to code); implement controller/service/DTO/tests for each, not merely one representative endpoint.
- [ ] Test required/null/unknown fields, role/purpose/ownership, errors/status, and each operation's acceptance tests. Mutation tests verify x-retry-policy.
- [ ] Run mvn verify (backend), python -m pytest (AI), and relevant contract tests; commit after passing. Build images only after tests; -DskipTests is not business verification.
- [ ] After completing task 12, compare runtime Swagger to the design and set version 1.0.0; do not declare MVP complete while an operation is missing or the real model remains unverified.

## 9. API coverage by task

This table is checked against x-task in both OpenAPI files; all 58 operationIds have implementation tasks. Tasks without new APIs own schemas or handover verification.

| Task | API count | Required operationIds |
|---|---:|---|
| 1 | 1 | `backendHealth` |
| 2 | 0 | Migrations, DB constraints, and internal configuration reads |
| 3 | 10 | `login`, `refreshTokens`, `logout`, `getMyProfile`, `changeMyPassword`, `listUsers`, `createUser`, `getUser`, `updateUser`, `resetUserPassword` |
| 4 | 9 | `issueMyQr`, `listKiosks`, `createKiosk`, `getKiosk`, `updateKiosk`, `rotateKioskCredential`, `loginKiosk`, `heartbeatKiosk`, `getKioskRuntimeConfig` |
| 5 | 2 | `recordQrAccess`, `getAccessRequestStatus` |
| 6 | 11 | `getMyAccessStatus`, `listMyAccessHistory`, `getMyAccessSession`, `recordManualAccess`, `listAccessHistory`, `getAccessSession`, `getOccupancy`, `listOccupants`, `listVisitors`, `createVisitor`, `getVisitor` |
| 7 | 10 | `listShifts`, `createShift`, `getShift`, `updateShift`, `cancelShift`, `listShiftAssignments`, `assignStaff`, `replaceAssignedStaff`, `cancelAssignment`, `listMyShifts` |
| 8 | 4 | `getSystemConfig`, `updateSystemConfig`, `getAccessAnalytics`, `getRecognitionAnalytics` |
| 9 | 2 | `aiHealth`, `aiReady` |
| 10 | 6 | `getFacePolicy`, `grantFaceConsent`, `getMyFaceEnrollment`, `enrollMyFace`, `deleteMyFaceEnrollment`, `extractEmbeddings` |
| 11 | 3 | `issueFaceChallenge`, `recordFaceAccess`, `recognizeFace` |
| 12 | 0 | Docker/testing/Swagger export and full MVP verification |
