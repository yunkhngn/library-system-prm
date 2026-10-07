# MVP API — ready-to-code contract

Updated: October 7, 2026. This is a design contract for implementation; these APIs are not yet running.

[Implementation plan](../superpowers/plans/2026-10-07-backend-ai.md) · [Data design](../backend-ai-spec.md) · [Backend OpenAPI](openapi-mvp.yaml) · [Internal AI OpenAPI](openapi-ai-internal.yaml)

Coverage includes the document requirements and additions: **54 backend HTTP operations, 4 internal AI operations**, plus the realtime protocol. Excludes App/Figma, sending email, employee attendance/shift swaps/leave, multiple branches, and report exports.

## 1. Fixed conventions

- Public business APIs use the /api/v1 prefix; infrastructure health does not. AI has a separate host and paths. The two YAML files keep servers/security separate.
- JSON requests use camelCase; UUIDs are strings; timestamps use ISO-8601 with an offset and DB TIMESTAMPTZ; the business timezone is Asia/Ho_Chi_Minh.
- JSON requests reject unknown fields; PATCH requires version and at least one other field; null is rejected unless nullable=true. Responses include all required fields and explicitly return null for nullable values.
- Code: 3–32 characters matching the regex, trimmed/uppercase; email: trimmed/lowercase, max 254 characters; code/email are unique across the system. Passwords are not trimmed, require 12–64 characters and UTF-8 ≤72 bytes. Seed passwords must satisfy the same constraints.
- Roles: STUDENT/LIBRARIAN/ADMIN; kiosks are separate principals. H in the permission matrix means LIBRARIAN or ADMIN. User/kiosk JWTs have distinct purposes and cannot replace each other.
- Lists default to page=0, size=20, max size=100; response: {items,page,size,totalElements,totalPages}. Sorting uses a per-route allowlist. Search uses case-insensitive contains; escape % and _ in LIKE so they remain literals.
- History filters by check-in time, default [now−30 days,now); shifts filter by overlap with [from,to), default [now−7 days,now+30 days). The to boundary is exclusive; maximum range: 366 days. Analytics require from/to; HOUR allows at most 31 days.
- Successful GET/PATCH/PUT default to 200; creation returns 201 + Location; DELETE/logout return 204 except face deletion, which returns 200 with the new version. Existing-consent 200 is declared separately.
- Mutations declare x-retry-policy: READ_SAFE/IDEMPOTENT/VERSIONED/IDEMPOTENCY_KEY/DO_NOT_AUTORETRY. VERSIONED: after losing a response, GET the current state before deciding; do not blindly resend with a new version.
- Idempotency is required only for QR/FACE/MANUAL access recording. Scope: (principalId,key); the client creates one UUID per intent; results are retained for 24 hours. Reusing a key with a different method/path/body digest returns 409 IDEMPOTENCY_CONFLICT. In-progress requests return 409 REQUEST_IN_PROGRESS + Retry-After:1; stored responses replay even after QR/challenge expiry, provided the principal remains authorized.
- Hash requests using HMAC-SHA256 with a separate key over method+path+canonical JSON or the multipart bytes digest; do not store raw tokens/clips/passwords. The idempotency secret differs from the JWT key.
- Mutations outside access do not store/replay secrets. If a creation response is lost, look up and compare the resource; kiosk credentials are returned once, and a lost credential must be rotated using the current version.
- No physical DELETE for users/kiosks: lock users with PATCH status=LOCKED and revoke kiosks with PATCH status=REVOKED; preserve FKs/history. Guests use visitors without requiring accounts.
- Default rate limits: login 10/minute/IP+identifier; refresh 30/minute/family; kiosk token 10/minute/kiosk; issueQR 12/minute/user; heartbeat 6/minute/kiosk; face challenge/access 10/minute/kiosk; enrollment 3/hour/user; others 120/minute/principal. The single-instance MVP backend uses an in-memory limiter; move to a shared store before scaling to multiple instances.

## 2. API inventory

| Host | Method | Path | Permissions | Request → Response | Task |
|---|---|---|---|---|---|
| Backend | POST | `/api/v1/auth/login` | PUBLIC | LoginRequest → TokenPair (200) | 3 |
| Backend | POST | `/api/v1/auth/refresh` | PUBLIC | RefreshRequest → TokenPair (200) | 3 |
| Backend | POST | `/api/v1/auth/logout` | STUDENT, LIBRARIAN, ADMIN | RefreshRequest → — (204) | 3 |
| Backend | GET | `/api/v1/me` | STUDENT, LIBRARIAN, ADMIN | — → User (200) | 3 |
| Backend | PUT | `/api/v1/me/password` | STUDENT, LIBRARIAN, ADMIN | ChangePasswordRequest → TokenPair (200) | 3 |
| Backend | GET | `/api/v1/users` | ADMIN | — → UserPage (200) | 3 |
| Backend | POST | `/api/v1/users` | ADMIN | CreateUserRequest → User (201) | 3 |
| Backend | GET | `/api/v1/users/{userId}` | ADMIN | — → User (200) | 3 |
| Backend | PATCH | `/api/v1/users/{userId}` | ADMIN | PatchUserRequest → User (200) | 3 |
| Backend | PUT | `/api/v1/users/{userId}/password` | ADMIN | ResetPasswordRequest → User (200) | 3 |
| Backend | GET | `/api/v1/me/access-status` | STUDENT | — → AccessStatus (200) | 6 |
| Backend | POST | `/api/v1/me/qr` | STUDENT | — → QrToken (200) | 4 |
| Backend | GET | `/api/v1/me/access-history` | STUDENT | — → AccessSessionPage (200) | 6 |
| Backend | GET | `/api/v1/me/access-history/{sessionId}` | STUDENT | — → AccessSession (200) | 6 |
| Backend | GET | `/api/v1/kiosks` | ADMIN | — → KioskPage (200) | 4 |
| Backend | POST | `/api/v1/kiosks` | ADMIN | CreateKioskRequest → KioskCredential (201) | 4 |
| Backend | GET | `/api/v1/kiosks/{kioskId}` | ADMIN | — → Kiosk (200) | 4 |
| Backend | PATCH | `/api/v1/kiosks/{kioskId}` | ADMIN | PatchKioskRequest → Kiosk (200) | 4 |
| Backend | POST | `/api/v1/kiosks/{kioskId}/rotate-credential` | ADMIN | VersionRequest → KioskCredential (200) | 4 |
| Backend | POST | `/api/v1/kiosks/token` | PUBLIC | KioskLoginRequest → KioskToken (200) | 4 |
| Backend | POST | `/api/v1/kiosks/heartbeat` | KIOSK | HeartbeatRequest → HeartbeatResult (200) | 4 |
| Backend | GET | `/api/v1/kiosks/me/config` | KIOSK | — → KioskRuntimeConfig (200) | 4 |
| Backend | POST | `/api/v1/access/qr` | KIOSK | QrAccessRequest → AccessResult (200) | 5 |
| Backend | POST | `/api/v1/access/manual` | LIBRARIAN, ADMIN | ManualAccessRequest → AccessResult (200) | 6 |
| Backend | GET | `/api/v1/access/requests/{idempotencyKey}` | LIBRARIAN, ADMIN, KIOSK | — → AccessRequestStatus (200) | 5 |
| Backend | GET | `/api/v1/access-history` | LIBRARIAN, ADMIN | — → AccessSessionPage (200) | 6 |
| Backend | GET | `/api/v1/access-history/{sessionId}` | LIBRARIAN, ADMIN | — → AccessSession (200) | 6 |
| Backend | GET | `/api/v1/occupancy` | LIBRARIAN, ADMIN | — → Occupancy (200) | 6 |
| Backend | GET | `/api/v1/occupancy/people` | LIBRARIAN, ADMIN | — → OccupantPage (200) | 6 |
| Backend | GET | `/api/v1/visitors` | LIBRARIAN, ADMIN | — → VisitorPage (200) | 6 |
| Backend | POST | `/api/v1/visitors` | LIBRARIAN, ADMIN | CreateVisitorRequest → Visitor (201) | 6 |
| Backend | GET | `/api/v1/visitors/{visitorId}` | LIBRARIAN, ADMIN | — → Visitor (200) | 6 |
| Backend | GET | `/api/v1/shifts` | ADMIN | — → ShiftPage (200) | 7 |
| Backend | POST | `/api/v1/shifts` | ADMIN | CreateShiftRequest → Shift (201) | 7 |
| Backend | GET | `/api/v1/shifts/{shiftId}` | LIBRARIAN, ADMIN | — → Shift (200) | 7 |
| Backend | PATCH | `/api/v1/shifts/{shiftId}` | ADMIN | PatchShiftRequest → Shift (200) | 7 |
| Backend | POST | `/api/v1/shifts/{shiftId}/cancel` | ADMIN | CancelShiftRequest → Shift (200) | 7 |
| Backend | GET | `/api/v1/shifts/{shiftId}/assignments` | ADMIN | — → AssignmentPage (200) | 7 |
| Backend | POST | `/api/v1/shifts/{shiftId}/assignments` | ADMIN | AssignStaffRequest → AssignmentBatch (201) | 7 |
| Backend | PATCH | `/api/v1/shifts/{shiftId}/assignments/{assignmentId}` | ADMIN | PatchAssignmentRequest → AssignmentBatch (200) | 7 |
| Backend | DELETE | `/api/v1/shifts/{shiftId}/assignments/{assignmentId}` | ADMIN | — → — (204) | 7 |
| Backend | GET | `/api/v1/me/shifts` | LIBRARIAN | — → MyShiftPage (200) | 7 |
| Backend | GET | `/api/v1/system-config` | LIBRARIAN, ADMIN | — → SystemConfig (200) | 8 |
| Backend | PATCH | `/api/v1/system-config` | ADMIN | PatchSystemConfigRequest → SystemConfig (200) | 8 |
| Backend | GET | `/api/v1/analytics/access` | ADMIN | — → AccessAnalytics (200) | 8 |
| Backend | GET | `/api/v1/analytics/recognition` | ADMIN | — → RecognitionAnalytics (200) | 8 |
| Backend | GET | `/api/v1/face-policy` | STUDENT | — → FacePolicy (200) | 10 |
| Backend | POST | `/api/v1/me/face-consent` | STUDENT | ConsentRequest → FaceConsent (201/200) | 10 |
| Backend | GET | `/api/v1/me/face-enrollment` | STUDENT | — → FaceEnrollment (200) | 10 |
| Backend | POST | `/api/v1/me/face-enrollment` | STUDENT | EnrollmentUpload → FaceEnrollment (200) | 10 |
| Backend | DELETE | `/api/v1/me/face-enrollment` | STUDENT | — → FaceDeletion (200) | 10 |
| Backend | POST | `/api/v1/access/face-challenge` | KIOSK | — → FaceChallenge (201) | 11 |
| Backend | POST | `/api/v1/access/face` | KIOSK | FaceAccessUpload → AccessResult (200) | 11 |
| Backend | GET | `/actuator/health` | PUBLIC | — → BackendHealth (200) | 1 |
| Internal AI | GET | `/api/v1/health` | PUBLIC | — → AiHealth (200) | 9 |
| Internal AI | GET | `/api/v1/ready` | BACKEND_SERVICE | — → AiReadiness (200) | 9 |
| Internal AI | POST | `/api/v1/embeddings` | BACKEND_SERVICE | InternalEnrollmentUpload → InternalEmbeddingResult (200) | 10 |
| Internal AI | POST | `/api/v1/recognize` | BACKEND_SERVICE | InternalRecognitionUpload → InternalRecognitionResult (200) | 11 |

## 3. Details for each API

### POST /api/v1/auth/login

Operation: `login` · Host: Backend · Permissions: PUBLIC · Task 3 · Retry: `DO_NOT_AUTORETRY`.

Log in with code or email. Access: 15 minutes; refresh: 7 days. Return mustChangePassword; tokens are restricted until the password changes. Invalid identifier/password returns the same error to avoid exposing account existence.

Request: `application/json` → [LoginRequest](#loginrequest).

Success 200: [TokenPair](#tokenpair).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `INVALID_CREDENTIALS`.
- 403: `ACCOUNT_LOCKED`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Code/email both support login after normalization.
- An incorrect password does not reveal whether the account exists.
- LOCKED accounts receive no tokens.

### POST /api/v1/auth/refresh

Operation: `refreshTokens` · Host: Backend · Permissions: PUBLIC · Task 3 · Retry: `DO_NOT_AUTORETRY`.

Single-use rotation: revoke the old token and issue a new pair within one transaction. Reusing a rotated token revokes the entire family. Do not automatically retry after a lost response; log in again. Business APIs are unavailable while mustChangePassword=true.

Request: `application/json` → [RefreshRequest](#refreshrequest).

Success 200: [TokenPair](#tokenpair).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `INVALID_REFRESH_TOKEN`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `ACCOUNT_LOCKED`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Two concurrent refreshes: only one succeeds.
- Reuse revokes the family.

### POST /api/v1/auth/logout

Operation: `logout` · Host: Backend · Permissions: STUDENT, LIBRARIAN, ADMIN · Task 3 · Retry: `IDEMPOTENT`.

Revoke the family of the current user's refreshToken. Already-revoked tokens return 204. Another user's refresh token returns 404. Access tokens whose sid belongs to this family become invalid immediately. Allowed for tokens restricted by PASSWORD_CHANGE_REQUIRED.

Request: `application/json` → [RefreshRequest](#refreshrequest).

Success 204: no body.

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Repeated logout returns 204.
- An access token with a logged-out sid returns 401.

### GET /api/v1/me

Operation: `getMyProfile` · Host: Backend · Permissions: STUDENT, LIBRARIAN, ADMIN · Task 3 · Retry: `READ_SAFE`.

Profile of the current JWT; no userId input. Allowed when mustChangePassword=true.

Success 200: [User](#user).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Omit password_hash/authVersion.

### PUT /api/v1/me/password

Operation: `changeMyPassword` · Host: Backend · Permissions: STUDENT, LIBRARIAN, ADMIN · Task 3 · Retry: `DO_NOT_AUTORETRY`.

Check currentPassword. The new password must differ, contain 12–64 characters, and use ≤72 UTF-8 bytes. Update the hash, increment auth_version, revoke all old families, clear mustChangePassword, then issue a new family/token pair. If the response is lost, log in with the new password; do not automatically retry.

Request: `application/json` → [ChangePasswordRequest](#changepasswordrequest).

Success 200: [TokenPair](#tokenpair).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `VALIDATION_ERROR`, `CURRENT_PASSWORD_INVALID`, `PASSWORD_UNCHANGED`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Old passwords/refresh tokens/access tokens all become invalid.
- Forced-change accounts must change the password via me/password before other business APIs become available.

### GET /api/v1/users

Operation: `listUsers` · Host: Backend · Permissions: ADMIN · Task 3 · Retry: `READ_SAFE`.

Search code, fullName, and email; default to all roles/statuses. q uses case-insensitive contains. Defaults: page=0,size=20.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `q` | No | type="string", maxLength=150 |
| query | `role` | No | type="string", enum=["STUDENT", "LIBRARIAN", "ADMIN"] |
| query | `status` | No | type="string", enum=["ACTIVE", "LOCKED"] |
| query | `sort` | No | type="string", enum=["createdAt,desc", "code,asc", "fullName,asc"], default="createdAt,desc" |

Success 200: [UserPage](#userpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Student/Librarian receive 403.
- Email is only exposed in account data authorized for Admin.

### POST /api/v1/users

Operation: `createUser` · Host: Backend · Permissions: ADMIN · Task 3 · Retry: `DO_NOT_AUTORETRY`.

Code/email are UNIQUE after normalization; default status ACTIVE; mustChangePassword=true when omitted. Role is not inferred from code. Do not automatically retry; for CODE_EXISTS/EMAIL_EXISTS, compare the resource via list. Responses omit passwords.

Request: `application/json` → [CreateUserRequest](#createuserrequest).

Success 201: [User](#user).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 409: `CODE_EXISTS`, `EMAIL_EXISTS`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- SV001 and sv001 are treated as duplicates.
- Email normalization cannot create duplicates.

### GET /api/v1/users/{userId}

Operation: `getUser` · Host: Backend · Permissions: ADMIN · Task 3 · Retry: `READ_SAFE`.

Account details; Admin can also retrieve locked accounts.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `userId` | Yes | type="string", format="uuid" |

Success 200: [User](#user).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- A nonexistent ID returns 404.

### PATCH /api/v1/users/{userId}

Operation: `updateUser` · Host: Backend · Permissions: ADMIN · Task 3 · Retry: `VERSIONED`.

Versioned partial update; reject null/unknown fields. Role/status changes increment auth_version and revoke tokens. Do not lock/demote the last ACTIVE Admin. Do not change a STUDENT with an open session to another role. Locking a person inside the library preserves the session for librarian handling; no automatic checkout.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `userId` | Yes | type="string", format="uuid" |

Request: `application/json` → [PatchUserRequest](#patchuserrequest).

Success 200: [User](#user).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`, `CODE_EXISTS`, `EMAIL_EXISTS`, `LAST_ADMIN_PROTECTED`, `USER_HAS_OPEN_SESSION`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Two Admins locking an account concurrently: stale version returns 409.
- Preserve the last active Admin.

### PUT /api/v1/users/{userId}/password

Operation: `resetUserPassword` · Host: Backend · Permissions: ADMIN · Task 3 · Retry: `VERSIONED`.

Admin sets a new password; mustChangePassword=true; increment auth_version and revoke all tokens. Do not return the password or send email. LOCKED users can be reset without being unlocked automatically.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `userId` | Yes | type="string", format="uuid" |

Request: `application/json` → [ResetPasswordRequest](#resetpasswordrequest).

Success 200: [User](#user).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Old JWT/refresh tokens become invalid; the user must change their password on the next login.

### GET /api/v1/me/access-status

Operation: `getMyAccessStatus` · Host: Backend · Permissions: STUDENT · Task 6 · Retry: `READ_SAFE`.

The student's current state and open session. currentSession=null when outside the library.

Success 200: [AccessStatus](#accessstatus).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Check-in/out updates isInside correctly; never two currentSession values.

### POST /api/v1/me/qr

Operation: `issueMyQr` · Host: Backend · Permissions: STUDENT · Task 4 · Retry: `DO_NOT_AUTORETRY`.

Issue a QR token valid for 30 seconds with purpose QR_ACCESS. Every call creates a new nonce; other unexpired QR tokens remain valid, while cooldown/session locks prevent duplicate scans. refreshAfterSeconds=25. Do not automatically retry; request a new code if needed.

Success 200: [QrToken](#qrtoken).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- An access JWT used as a QR token is rejected.
- QR contains no email/images.

### GET /api/v1/me/access-history

Operation: `listMyAccessHistory` · Host: Backend · Permissions: STUDENT · Task 6 · Retry: `READ_SAFE`.

Only sessions belonging to the JWT student, filtered by checkInTime. If from/to are omitted: [now−30 days,now); if one boundary is provided, default the other. Maximum range: 366 days.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `from` | No | type="string", format="date-time" |
| query | `to` | No | type="string", format="date-time" |
| query | `sort` | No | type="string", enum=["checkInTime,desc", "checkInTime,asc"], default="checkInTime,desc" |

Success 200: [AccessSessionPage](#accesssessionpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- A userId query cannot expose another user's data.

### GET /api/v1/me/access-history/{sessionId}

Operation: `getMyAccessSession` · Host: Backend · Permissions: STUDENT · Task 6 · Retry: `READ_SAFE`.

Sessions owned by another user also return 404.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `sessionId` | Yes | type="string", format="uuid" |

Success 200: [AccessSession](#accesssession).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Another user's ID does not disclose existence.

### GET /api/v1/kiosks

Operation: `listKiosks` · Host: Backend · Permissions: ADMIN · Task 4 · Retry: `READ_SAFE`.

Online iff ACTIVE and lastSeenAt is within 90 seconds. Omit credentials/hashes/tokens.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `q` | No | type="string", maxLength=150 |
| query | `status` | No | type="string", enum=["ACTIVE", "REVOKED"] |
| query | `isOnline` | No | type="boolean" |
| query | `sort` | No | type="string", enum=["createdAt,desc", "code,asc"], default="createdAt,desc" |

Success 200: [KioskPage](#kioskpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Offline status is derived from the heartbeat timeout.

### POST /api/v1/kiosks

Operation: `createKiosk` · Host: Backend · Permissions: ADMIN · Task 4 · Retry: `DO_NOT_AUTORETRY`.

Create ACTIVE with a random credential of ≥32 bytes returned once; the DB stores only its hash. Do not automatically retry; if the response is lost, find by code and rotate-credential.

Request: `application/json` → [CreateKioskRequest](#createkioskrequest).

Success 201: [KioskCredential](#kioskcredential).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 409: `CODE_EXISTS`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- GET never returns credentials.

### GET /api/v1/kiosks/{kioskId}

Operation: `getKiosk` · Host: Backend · Permissions: ADMIN · Task 4 · Retry: `READ_SAFE`.

Device details, mode, and online status; omit credentials.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `kioskId` | Yes | type="string", format="uuid" |

Success 200: [Kiosk](#kiosk).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- A kiosk token cannot read another device.

### PATCH /api/v1/kiosks/{kioskId}

Operation: `updateKiosk` · Host: Backend · Permissions: ADMIN · Task 4 · Retry: `VERSIONED`.

Update name/mode/status; code is immutable. REVOKED clears the credential hash, increments credential_version, and immediately invalidates kiosk tokens. PATCH cannot transition REVOKED→ACTIVE; use rotate-credential to issue a new secret and activate. Mode changes do not alter open sessions.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `kioskId` | Yes | type="string", format="uuid" |

Request: `application/json` → [PatchKioskRequest](#patchkioskrequest).

Success 200: [Kiosk](#kiosk).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`, `KIOSK_REACTIVATION_REQUIRES_ROTATION`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Old tokens become invalid immediately after revocation.
- Activation never restores old credentials.

### POST /api/v1/kiosks/{kioskId}/rotate-credential

Operation: `rotateKioskCredential` · Host: Backend · Permissions: ADMIN · Task 4 · Retry: `VERSIONED`.

Increment credential_version, invalidate old tokens, issue a new credential once, and set ACTIVE. After a lost response, GET the version and rotate again; do not replay secrets from the idempotency store.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `kioskId` | Yes | type="string", format="uuid" |

Request: `application/json` → [VersionRequest](#versionrequest).

Success 200: [KioskCredential](#kioskcredential).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- New secrets work; old secrets/tokens are blocked.

### POST /api/v1/kiosks/token

Operation: `loginKiosk` · Host: Backend · Permissions: PUBLIC · Task 4 · Retry: `DO_NOT_AUTORETRY`.

Token purpose KIOSK, valid for 1 hour; JWT claims include kioskId and credentialVersion. Check DB status/epoch on every operation. Store the device secret in kiosk secure storage.

Request: `application/json` → [KioskLoginRequest](#kioskloginrequest).

Success 200: [KioskToken](#kiosktoken).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `INVALID_CREDENTIALS`.
- 403: `KIOSK_REVOKED`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- User JWTs cannot replace kiosk tokens.

### POST /api/v1/kiosks/heartbeat

Operation: `heartbeatKiosk` · Host: Backend · Permissions: KIOSK · Task 4 · Retry: `IDEMPOTENT`.

Update lastSeenAt using server time; camera/appVersion are telemetry, not identity. Send every 30 seconds; offline after 90 seconds.

Request: `application/json` → [HeartbeatRequest](#heartbeatrequest).

Success 200: [HeartbeatResult](#heartbeatresult).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `KIOSK_REVOKED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- KioskId always comes from the principal.

### GET /api/v1/kiosks/me/config

Operation: `getKioskRuntimeConfig` · Host: Backend · Permissions: KIOSK · Task 4 · Retry: `READ_SAFE`.

Configuration for kiosk capture/QR and display; omit credentials, email, and internal thresholds. faceEnabled=false when model/calibration/liveness is not ready.

Success 200: [KioskRuntimeConfig](#kioskruntimeconfig).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `KIOSK_REVOKED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Configuration changes take effect without rebuilding the App.

### POST /api/v1/access/qr

Operation: `recordQrAccess` · Host: Backend · Permissions: KIOSK · Task 5 · Retry: `IDEMPOTENCY_KEY`.

AUTO toggles based on the session; ENTRY only checks in, EXIT only checks out. Consume QR, write logs, update occupancy revision, and store the idempotency response in one transaction. Only ACTIVE STUDENT users. Checkout remains allowed outside opening hours. Cooldown: 10 seconds; retrying the same key returns the stored response before checking QR expiry.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| header | `Idempotency-Key` | Yes | type="string", format="uuid" |

Request: `application/json` → [QrAccessRequest](#qraccessrequest).

Success 200: [AccessResult](#accessresult).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`, `IDEMPOTENCY_KEY_REQUIRED`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `KIOSK_REVOKED`, `INVALID_TOKEN_PURPOSE`.
- 409: `IDEMPOTENCY_CONFLICT`, `REQUEST_IN_PROGRESS`, `QR_ALREADY_USED`, `SCAN_TOO_SOON`, `ALREADY_INSIDE`, `NOT_INSIDE`.
- 422: `QR_INVALID`, `QR_EXPIRED`, `LIBRARY_CLOSED`, `CAPACITY_REACHED`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `DB_UNAVAILABLE`, `REQUEST_ABORTED`.

Required tests:

- Retry does not toggle state.
- Concurrent kiosks produce only one effect.
- A rolled-back QR is not consumed.

### POST /api/v1/access/manual

Operation: `recordManualAccess` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `IDEMPOTENCY_KEY`.

Exactly one userId or visitorId; explicit CHECK_IN/CHECK_OUT action and required reason. User check-in requires ACTIVE STUDENT; manual checkout may close a LOCKED user's session. Guests use MANUAL only. Do not bypass opening hours/capacity. No cooldown because the action is explicit; the single-open-session and idempotency requirements still apply.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| header | `Idempotency-Key` | Yes | type="string", format="uuid" |

Request: `application/json` → [ManualAccessRequest](#manualaccessrequest).

Success 200: [AccessResult](#accessresult).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`, `IDEMPOTENCY_KEY_REQUIRED`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `IDEMPOTENCY_CONFLICT`, `REQUEST_IN_PROGRESS`, `ALREADY_INSIDE`, `NOT_INSIDE`.
- 422: `VALIDATION_ERROR`, `LIBRARY_CLOSED`, `CAPACITY_REACHED`, `SUBJECT_NOT_ELIGIBLE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `DB_UNAVAILABLE`, `REQUEST_ABORTED`.

Required tests:

- Manual checkout is allowed for LOCKED users.
- actor/reason are stored separately for each direction.

### GET /api/v1/access/requests/{idempotencyKey}

Operation: `getAccessRequestStatus` · Host: Backend · Permissions: LIBRARIAN, ADMIN, KIOSK · Task 5 · Retry: `READ_SAFE`.

Recover a lost QR/FACE/MANUAL response using the App-generated key without resending clip/QR. Scoped to the current principal; another principal's key, missing keys, or expired retention return 404. IN_PROGRESS: result/error/httpStatus=null; COMPLETED: exactly one result or error with the original httpStatus. No new operation is created.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `idempotencyKey` | Yes | type="string", format="uuid" |

Success 200: [AccessRequestStatus](#accessrequeststatus).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`, `KIOSK_REVOKED`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Do not expose another kiosk/user's result.
- A lost FACE response can be recovered without uploading the clip again.

### GET /api/v1/access-history

Operation: `listAccessHistory` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `READ_SAFE`.

Filter by checkInTime; method means checkInMethod; userId/visitorId are mutually exclusive. q searches code/referenceCode/fullName. Default date range: 30 days; maximum: 366 days.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `from` | No | type="string", format="date-time" |
| query | `to` | No | type="string", format="date-time" |
| query | `q` | No | type="string", maxLength=150 |
| query | `userId` | No | type="string", format="uuid" |
| query | `visitorId` | No | type="string", format="uuid" |
| query | `isOpen` | No | type="boolean" |
| query | `method` | No | type="string", enum=["FACE", "QR", "MANUAL"] |
| query | `sort` | No | type="string", enum=["checkInTime,desc", "checkInTime,asc"], default="checkInTime,desc" |

Success 200: [AccessSessionPage](#accesssessionpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`, `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Reject simultaneous userId and visitorId.

### GET /api/v1/access-history/{sessionId}

Operation: `getAccessSession` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `READ_SAFE`.

Return session details with actors and reasons for both directions.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `sessionId` | Yes | type="string", format="uuid" |

Success 200: [AccessSession](#accesssession).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Students receive 403 on staff routes.

### GET /api/v1/occupancy

Operation: `getOccupancy` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `READ_SAFE`.

Count open sessions for students/guests. Read count/revision within one transaction snapshot; do not count librarians based on shifts.

Success 200: [Occupancy](#occupancy).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- DB count matches the snapshot and is nonnegative.

### GET /api/v1/occupancy/people

Operation: `listOccupants` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `READ_SAFE`.

Open sessions only; q searches code/referenceCode/name. durationSeconds is calculated up to query time. Omit email.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `q` | No | type="string", maxLength=150 |
| query | `kind` | No | type="string", enum=["USER", "VISITOR"] |
| query | `sort` | No | type="string", enum=["checkInTime,asc", "checkInTime,desc", "code,asc"], default="checkInTime,asc" |

Success 200: [OccupantPage](#occupantpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- A closed session disappears from the list.

### GET /api/v1/visitors

Operation: `listVisitors` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `READ_SAFE`.

Search existing guest profiles by code/name; identical names may represent different identities. Do not merge by fullName automatically.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `q` | No | type="string", maxLength=150 |
| query | `sort` | No | type="string", enum=["createdAt,desc", "referenceCode,asc"], default="createdAt,desc" |

Success 200: [VisitorPage](#visitorpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Existing guests can be found before creating a new profile.

### POST /api/v1/visitors

Operation: `createVisitor` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `DO_NOT_AUTORETRY`.

Server assigns referenceCode GUEST-<sequence>; fullName is not UNIQUE. No password/email/account. Do not automatically retry after a lost response; search the list first.

Request: `application/json` → [CreateVisitorRequest](#createvisitorrequest).

Success 201: [Visitor](#visitor).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Guests do not require student codes; identical names are not incorrectly merged.

### GET /api/v1/visitors/{visitorId}

Operation: `getVisitor` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 6 · Retry: `READ_SAFE`.

Guest profile details for manual access recording.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `visitorId` | Yes | type="string", format="uuid" |

Success 200: [Visitor](#visitor).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Guest IDs work on the manual route.

### GET /api/v1/shifts

Operation: `listShifts` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `READ_SAFE`.

Filter by overlap with [from,to), not only startsAt. Default: [now−7 days,now+30 days), all statuses; q searches shift names; staffId filters ACTIVE assignments. Maximum: 366 days.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `from` | No | type="string", format="date-time" |
| query | `to` | No | type="string", format="date-time" |
| query | `status` | No | type="string", enum=["ACTIVE", "CANCELLED"] |
| query | `staffId` | No | type="string", format="uuid" |
| query | `q` | No | type="string", maxLength=150 |
| query | `sort` | No | type="string", enum=["startsAt,asc", "startsAt,desc"], default="startsAt,asc" |

Success 200: [ShiftPage](#shiftpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Overlapping overnight shifts still appear.

### POST /api/v1/shifts

Operation: `createShift` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `DO_NOT_AUTORETRY`.

A shift on a specific date, endsAt>startsAt, duration ≤24 hours. No staff-per-shift limit in MVP. No recurring schedule. Do not automatically retry after a lost response.

Request: `application/json` → [CreateShiftRequest](#createshiftrequest).

Success 201: [Shift](#shift).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`, `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Overnight shifts are valid; ends<=starts is rejected.

### GET /api/v1/shifts/{shiftId}

Operation: `getShift` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 7 · Retry: `READ_SAFE`.

Admin can read all shifts; librarians can only read shifts containing their own assignment, including cancelled assignments for history. Outside ownership, return 404.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `shiftId` | Yes | type="string", format="uuid" |

Success 200: [Shift](#shift).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Librarians cannot read unassigned shifts.

### PATCH /api/v1/shifts/{shiftId}

Operation: `updateShift` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `VERSIONED`.

Update name/startsAt/endsAt; CANCELLED shifts cannot be edited. Copy times to all ACTIVE assignments and check overlaps in one transaction; roll back everything if any employee overlaps.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `shiftId` | Yes | type="string", format="uuid" |

Request: `application/json` → [PatchShiftRequest](#patchshiftrequest).

Success 200: [Shift](#shift).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`, `SHIFT_CANCELLED`, `SHIFT_OVERLAP`.
- 422: `INVALID_TIME_RANGE`, `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- If changing a multi-person shift causes an overlap, no one's times change partially.

### POST /api/v1/shifts/{shiftId}/cancel

Operation: `cancelShift` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `VERSIONED`.

Soft-cancel the shift and all ACTIVE assignments, recording reason. If already cancelled with the current version, return the current resource; stale version returns 409. Cancelled shifts cannot be reopened.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `shiftId` | Yes | type="string", format="uuid" |

Request: `application/json` → [CancelShiftRequest](#cancelshiftrequest).

Success 200: [Shift](#shift).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Cancellation preserves history and releases the overlapping interval.

### GET /api/v1/shifts/{shiftId}/assignments

Operation: `listShiftAssignments` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `READ_SAFE`.

Return all assignments when status is omitted; staff contains only {id,code,fullName}, without email.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `status` | No | type="string", enum=["ACTIVE", "CANCELLED"] |
| query | `sort` | No | type="string", enum=["createdAt,asc", "createdAt,desc"], default="createdAt,asc" |
| path | `shiftId` | Yes | type="string", format="uuid" |

Success 200: [AssignmentPage](#assignmentpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Active/cancelled filtering is accurate.

### POST /api/v1/shifts/{shiftId}/assignments

Operation: `assignStaff` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `VERSIONED`.

version is shift.version. staffIds contains 1–100 unique IDs, only ACTIVE LIBRARIAN users; create the batch atomically and increment shift.version. Existing ACTIVE assignments return 409, including assignments in this shift.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `shiftId` | Yes | type="string", format="uuid" |

Request: `application/json` → [AssignStaffRequest](#assignstaffrequest).

Success 201: [AssignmentBatch](#assignmentbatch).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`, `SHIFT_CANCELLED`, `SHIFT_OVERLAP`, `ASSIGNMENT_EXISTS`.
- 422: `STAFF_NOT_ELIGIBLE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- One overlapping staff member rolls back the entire batch.
- Concurrent Admins cannot create overlaps.

### PATCH /api/v1/shifts/{shiftId}/assignments/{assignmentId}

Operation: `replaceAssignedStaff` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `VERSIONED`.

version is assignment.version. Replace staff within one transaction rather than DELETE then POST; inherit shift times. Return AssignmentBatch with the changed assignment and new shift.version. Only ACTIVE shifts/assignments.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| path | `shiftId` | Yes | type="string", format="uuid" |
| path | `assignmentId` | Yes | type="string", format="uuid" |

Request: `application/json` → [PatchAssignmentRequest](#patchassignmentrequest).

Success 200: [AssignmentBatch](#assignmentbatch).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`, `SHIFT_CANCELLED`, `SHIFT_OVERLAP`, `ASSIGNMENT_EXISTS`.
- 422: `STAFF_NOT_ELIGIBLE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- A failed staff replacement preserves the old assignment.

### DELETE /api/v1/shifts/{shiftId}/assignments/{assignmentId}

Operation: `cancelAssignment` · Host: Backend · Permissions: ADMIN · Task 7 · Retry: `VERSIONED`.

version is assignment.version and is required in the query. Soft-cancel; increment assignment.version and shift.version; preserve history. Already CANCELLED with the current version returns 204; stale version returns 409.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `version` | Yes | type="integer", format="int64", minimum=0 |
| path | `shiftId` | Yes | type="string", format="uuid" |
| path | `assignmentId` | Yes | type="string", format="uuid" |

Success 204: no body.

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 404: `RESOURCE_NOT_FOUND`.
- 409: `VERSION_CONFLICT`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Individual cancellation does not affect other staff.

### GET /api/v1/me/shifts

Operation: `listMyShifts` · Host: Backend · Permissions: LIBRARIAN · Task 7 · Retry: `READ_SAFE`.

Own schedule, filtered by assignment status; default all statuses, overlap with [now−7 days,now+30 days), maximum range 366 days. Shifts do not determine login permission.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `page` | No | type="integer", format="int64", minimum=0, default=0 |
| query | `size` | No | type="integer", format="int64", minimum=1, maximum=100, default=20 |
| query | `from` | No | type="string", format="date-time" |
| query | `to` | No | type="string", format="date-time" |
| query | `status` | No | type="string", enum=["ACTIVE", "CANCELLED"] |
| query | `sort` | No | type="string", enum=["startsAt,asc", "startsAt,desc"], default="startsAt,asc" |

Success 200: [MyShiftPage](#myshiftpage).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Employees only receive their own assignments.

### GET /api/v1/system-config

Operation: `getSystemConfig` · Host: Backend · Permissions: LIBRARIAN, ADMIN · Task 8 · Retry: `READ_SAFE`.

Operational configuration and calibration metadata; omit JWT/DB/service secrets. Librarians can read; Admin can edit.

Success 200: [SystemConfig](#systemconfig).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Responses contain no secrets.

### PATCH /api/v1/system-config

Operation: `updateSystemConfig` · Host: Backend · Permissions: ADMIN · Task 8 · Retry: `VERSIONED`.

Atomic update with audit; timezone is fixed. Validate unique weekdays, ranges, and model-specific thresholds. Null calibration fields disable real FACE. Enabling requires updating the entire modelVersion/distance/gap/liveness calibration group; do not treat the old 0.65 value as a measured threshold.

Request: `application/json` → [PatchSystemConfigRequest](#patchsystemconfigrequest).

Success 200: [SystemConfig](#systemconfig).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 409: `VERSION_CONFLICT`.
- 422: `VALIDATION_ERROR`, `MODEL_VERSION_MISMATCH`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Invalid configuration cannot be partially applied.
- Opening-hour changes take effect at runtime.

### GET /api/v1/analytics/access

Operation: `getAccessAnalytics` · Host: Backend · Permissions: ADMIN · Task 8 · Retry: `READ_SAFE`.

Range [from,to); DAY maximum 366 days, HOUR maximum 31 days; zero-fill buckets in the business timezone. checkIns count entry times; checkOuts count exit times, including sessions entered before from; averageStay uses sessions checked out within the range.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `from` | Yes | type="string", format="date-time" |
| query | `to` | Yes | type="string", format="date-time" |
| query | `bucket` | No | type="string", enum=["DAY", "HOUR"], default="DAY" |

Success 200: [AccessAnalytics](#accessanalytics).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Midnight uses the Vietnam calendar day; empty buckets contain zeros.

### GET /api/v1/analytics/recognition

Operation: `getRecognitionAnalytics` · Host: Backend · Permissions: ADMIN · Task 8 · Retry: `READ_SAFE`.

Real kiosk recognition only, excluding enrollment/mock; maximum range 366 days. failureRate=failed/total, null when total=0; matched means identity recognition succeeded even if the session is rejected by cooldown/capacity. p50/p95 include every attempt.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `from` | Yes | type="string", format="date-time" |
| query | `to` | Yes | type="string", format="date-time" |
| query | `kioskId` | No | type="string", format="uuid" |

Success 200: [RecognitionAnalytics](#recognitionanalytics).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 422: `INVALID_TIME_RANGE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- AI errors are counted, not only successful FACE logs.

### GET /api/v1/face-policy

Operation: `getFacePolicy` · Host: Backend · Permissions: STUDENT · Task 10 · Retry: `READ_SAFE`.

Current policy version and capture limits; content is a business notice managed in file configuration, without claiming legal certification.

Success 200: [FacePolicy](#facepolicy).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Consent uses the correct policy version.

### POST /api/v1/me/face-consent

Operation: `grantFaceConsent` · Host: Backend · Permissions: STUDENT · Task 10 · Retry: `IDEMPOTENT`.

Require accepted=true and the current version. Existing ACTIVE consent for the same policy returns 200; new consent returns 201. Use a user lock; do not silently renew consent after a policy change.

Request: `application/json` → [ConsentRequest](#consentrequest).

Success 201: [FaceConsent](#faceconsent).
Success 200: [FaceConsent](#faceconsent).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 409: `CONSENT_POLICY_CHANGED`.
- 422: `VALIDATION_ERROR`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- accepted=false creates no consent.
- Repeated consent creates no second ACTIVE record.

### GET /api/v1/me/face-enrollment

Operation: `getMyFaceEnrollment` · Host: Backend · Permissions: STUDENT · Task 10 · Retry: `READ_SAFE`.

Return status even before enrollment (isEnrolled=false,imageCount=0,version from user.biometricVersion). Omit embeddings/images.

Success 200: [FaceEnrollment](#faceenrollment).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Version is 0 on creation; deletion/enrollment increments it.

### POST /api/v1/me/face-enrollment

Operation: `enrollMyFace` · Host: Backend · Permissions: STUDENT · Task 10 · Retry: `VERSIONED`.

3–5 JPEG/PNG images, each ≤5MiB, total ≤25MiB, max 16MP; version is the previously read biometricVersion. One face per image, same person; AI checks pairwise consistency. Current-policy consent is required. Replace embeddings atomically only if the whole set is valid; images stay in memory/cleaned-up temporary storage.

Request: `multipart/form-data` → [EnrollmentUpload](#enrollmentupload).

Success 200: [FaceEnrollment](#faceenrollment).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 409: `VERSION_CONFLICT`, `CONSENT_REQUIRED`, `CONSENT_POLICY_CHANGED`, `ENROLLMENT_CHANGED`.
- 413: `PAYLOAD_TOO_LARGE`.
- 422: `IMAGE_INVALID`, `FACE_NOT_FOUND`, `MULTIPLE_FACES`, `LOW_QUALITY`, `INCONSISTENT_FACES`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `AI_UNAVAILABLE`, `MODEL_NOT_READY`, `SIMULATED_RESULT_REJECTED`.

Required tests:

- One invalid image does not remove the old enrollment.
- Consent revocation/account locking during inference prevents embedding writes.

### DELETE /api/v1/me/face-enrollment

Operation: `deleteMyFaceEnrollment` · Host: Backend · Permissions: STUDENT · Task 10 · Retry: `VERSIONED`.

version=biometricVersion. Delete embeddings, revoke consent, and increment version in one transaction; preserve history. If consent/embeddings are already absent and version matches, return 200 without another increment. The initial version has no AI candidate cache, so deletion takes effect immediately.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| query | `version` | Yes | type="integer", format="int64", minimum=0 |

Success 200: [FaceDeletion](#facedeletion).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `ACCOUNT_LOCKED`, `PASSWORD_CHANGE_REQUIRED`, `INVALID_TOKEN_PURPOSE`.
- 409: `VERSION_CONFLICT`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- The user disappears from the candidate view; history remains.

### POST /api/v1/access/face-challenge

Operation: `issueFaceChallenge` · Host: Backend · Permissions: KIOSK · Task 11 · Retry: `DO_NOT_AUTORETRY`.

Challenge valid for 60 seconds with two actions: BLINK, then randomly chosen TURN_LEFT or TURN_RIGHT. Bound to kiosk and calibration/model version. Backend stores instructions/expiry/consumedAt in DB; do not automatically retry, but a new challenge may be requested.

Success 201: [FaceChallenge](#facechallenge).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `KIOSK_REVOKED`, `INVALID_TOKEN_PURPOSE`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `AI_UNAVAILABLE`, `MODEL_NOT_READY`, `MODEL_NOT_CALIBRATED`.

Required tests:

- A challenge from another kiosk cannot be used.

### POST /api/v1/access/face

Operation: `recordFaceAccess` · Host: Backend · Permissions: KIOSK · Task 11 · Retry: `IDEMPOTENCY_KEY`.

MP4 clip: 1–3 seconds, ≤10MiB, ≤1280x720 and 30fps; no audio. Backend validates the challenge and sends its stored DB instructions to AI. Only matched+livenessPassed+real+correct modelVersion reaches AccessService. Consume the challenge only for a determined attempt outcome; AI timeout records no session, returns 503, and requires QR/a new challenge. Do not accept studentId for client-selected identity.

| Location | Name | Required | Type / limits |
|---|---|---|---|
| header | `Idempotency-Key` | Yes | type="string", format="uuid" |

Request: `multipart/form-data` → [FaceAccessUpload](#faceaccessupload).

Success 200: [AccessResult](#accessresult).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`, `IDEMPOTENCY_KEY_REQUIRED`.
- 401: `UNAUTHENTICATED`, `TOKEN_EXPIRED`, `TOKEN_REVOKED`.
- 403: `FORBIDDEN`, `KIOSK_REVOKED`, `INVALID_TOKEN_PURPOSE`.
- 409: `IDEMPOTENCY_CONFLICT`, `REQUEST_IN_PROGRESS`, `CHALLENGE_ALREADY_USED`, `SCAN_TOO_SOON`, `ALREADY_INSIDE`, `NOT_INSIDE`, `ENROLLMENT_CHANGED`.
- 413: `PAYLOAD_TOO_LARGE`.
- 422: `CHALLENGE_EXPIRED`, `CHALLENGE_INVALID`, `VIDEO_INVALID`, `FACE_NOT_FOUND`, `MULTIPLE_FACES`, `LOW_QUALITY`, `LIVENESS_FAILED`, `NO_MATCH`, `LIBRARY_CLOSED`, `CAPACITY_REACHED`, `MODEL_VERSION_MISMATCH`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `AI_UNAVAILABLE`, `MODEL_NOT_READY`, `MODEL_NOT_CALIBRATED`, `SIMULATED_RESULT_REJECTED`, `REQUEST_ABORTED`, `DB_UNAVAILABLE`.

Required tests:

- Fake/mock face results create no session.
- No match/AI downtime recommends QR.
- Concurrent face deletion/account locking before commit is blocked.

### GET /actuator/health

Operation: `backendHealth` · Host: Backend · Permissions: PUBLIC · Task 1 · Retry: `READ_SAFE`.

Health UP when DB/schema are usable, independent of AI. DOWN returns 503. Do not expose credential/internal details.

Success 200: [BackendHealth](#backendhealth).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `DB_UNAVAILABLE`.

Required tests:

- AI downtime does not make backend health DOWN.

### GET /api/v1/health

Operation: `aiHealth` · Host: AI · Permissions: PUBLIC · Task 9 · Retry: `READ_SAFE`.

Process liveness, independent of models/DB.

Success 200: [AiHealth](#aihealth).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- An active process returns 200 even when the model is not ready.

### GET /api/v1/ready

Operation: `aiReady` · Host: AI · Permissions: BACKEND_SERVICE · Task 9 · Retry: `READ_SAFE`.

REAL readiness requires model+checksum+liveness model+DB view. MOCK readiness has simulated=true and cannot enable real face access. NOT_READY returns 503 with AiReadiness.

Success 200: [AiReadiness](#aireadiness).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `INVALID_SERVICE_KEY`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.

Required tests:

- Missing models cannot report ready.

### POST /api/v1/embeddings

Operation: `extractEmbeddings` · Host: AI · Permissions: BACKEND_SERVICE · Task 10 · Retry: `DO_NOT_AUTORETRY`.

Extract embeddings only; no DB writes. One face per image, 3–5 images of the same person; finite, L2-normalized 512-dimensional vectors. The model is declared in readiness/manifest and results must match it. Images stay in memory/cleaned-up temporary storage; bound the inference queue.

Request: `multipart/form-data` → [InternalEnrollmentUpload](#internalenrollmentupload).

Success 200: [InternalEmbeddingResult](#internalembeddingresult).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `INVALID_SERVICE_KEY`.
- 413: `PAYLOAD_TOO_LARGE`.
- 422: `IMAGE_INVALID`, `FACE_NOT_FOUND`, `MULTIPLE_FACES`, `LOW_QUALITY`, `INCONSISTENT_FACES`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `MODEL_NOT_READY`.

Required tests:

- Dimension=512, no NaN/zero vectors; mixed identities are rejected.

### POST /api/v1/recognize

Operation: `recognizeFace` · Host: AI · Permissions: BACKEND_SERVICE · Task 11 · Retry: `DO_NOT_AUTORETRY`.

No business writes. Read candidates view with userId/consentId/biometricVersion/model; exact cosine distance grouped by distinct user, rejecting ties. MATCHED iff liveness and distance/gap pass; NO_MATCH or LIVENESS_FAILED returns 200 with matched=false,userId=null. Validation/no-face/quality errors return 422. Do not accept candidate studentId from the App.

Request: `multipart/form-data` → [InternalRecognitionUpload](#internalrecognitionupload).

Success 200: [InternalRecognitionResult](#internalrecognitionresult).

Applicable errors (all use ApiError except health/readiness):

- 400: `INVALID_REQUEST`, `INVALID_JSON`, `INVALID_QUERY`, `UNKNOWN_FIELD`.
- 401: `INVALID_SERVICE_KEY`.
- 413: `PAYLOAD_TOO_LARGE`.
- 422: `VIDEO_INVALID`, `FACE_NOT_FOUND`, `MULTIPLE_FACES`, `LOW_QUALITY`, `MODEL_VERSION_MISMATCH`.
- 429: `RATE_LIMITED`.
- 500: `INTERNAL_ERROR`.
- 503: `MODEL_NOT_READY`, `DB_UNAVAILABLE`.

Required tests:

- No match is a determined result, not fabricated success.
- The read-only DB role cannot modify tables.

## 4. Complete DTOs and validation

All DTOs set additionalProperties=false; requests/responses use separate types. `$ref` points to schemas defined below or in OpenAPI. Cross-field constraints are specified in API descriptions/transaction rules.

### AccessAnalytics

| Field | Required | Schema / validation |
|---|---|---|
| `from` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `to` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `timezone` | Yes | `{"type":"string","enum":["Asia/Ho_Chi_Minh"]}` |
| `bucket` | Yes | `{"type":"string","enum":["DAY","HOUR"]}` |
| `totalCheckIns` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalCheckOuts` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `averageStaySeconds` | Yes | `{"type":"number","format":"double","minimum":0,"nullable":true}` |
| `buckets` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/AccessBucket"},"minItems":1,"maxItems":10000}` |

### AccessBucket

| Field | Required | Schema / validation |
|---|---|---|
| `startsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `endsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `checkIns` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `checkOuts` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `faceCheckIns` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `qrCheckIns` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `manualCheckIns` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### AccessRequestStatus

| Field | Required | Schema / validation |
|---|---|---|
| `requestId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `idempotencyKey` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `status` | Yes | `{"type":"string","enum":["IN_PROGRESS","COMPLETED"]}` |
| `httpStatus` | Yes | `{"type":"integer","format":"int64","minimum":100,"maximum":599,"nullable":true}` |
| `result` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/AccessResult"}],"nullable":true}` |
| `error` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/ApiError"}],"nullable":true}` |
| `processingDeadline` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `expiresAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### AccessResult

| Field | Required | Schema / validation |
|---|---|---|
| `requestId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `sessionId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `action` | Yes | `{"type":"string","enum":["CHECK_IN","CHECK_OUT"]}` |
| `subject` | Yes | `{"$ref":"#/components/schemas/Subject"}` |
| `method` | Yes | `{"type":"string","enum":["FACE","QR","MANUAL"]}` |
| `occurredAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `occupancy` | Yes | `{"$ref":"#/components/schemas/Occupancy"}` |
| `simulated` | Yes | `{"type":"boolean","enum":[false]}` |

### AccessSession

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `subject` | Yes | `{"$ref":"#/components/schemas/Subject"}` |
| `checkInTime` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `checkOutTime` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00","nullable":true}` |
| `checkInMethod` | Yes | `{"type":"string","enum":["FACE","QR","MANUAL"]}` |
| `checkOutMethod` | Yes | `{"type":"string","enum":["FACE","QR","MANUAL"],"nullable":true}` |
| `checkInKiosk` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/KioskSummary"}],"nullable":true}` |
| `checkOutKiosk` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/KioskSummary"}],"nullable":true}` |
| `checkInBy` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/Actor"}],"nullable":true}` |
| `checkOutBy` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/Actor"}],"nullable":true}` |
| `checkoutReason` | Yes | `{"type":"string","enum":["USER_ACTION","MANUAL","CLOSING_TIME","MAX_DURATION"],"nullable":true}` |
| `manualReason` | Yes | `{"type":"string","nullable":true,"maxLength":1000}` |
| `checkOutManualReason` | Yes | `{"type":"string","nullable":true,"maxLength":1000}` |
| `durationSeconds` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Until checkout for closed sessions, or snapshot time for open sessions."}` |

### AccessSessionPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/AccessSession"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### AccessStatus

| Field | Required | Schema / validation |
|---|---|---|
| `isInside` | Yes | `{"type":"boolean"}` |
| `currentSession` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/AccessSession"}],"nullable":true}` |
| `asOf` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### Actor

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `code` | Yes | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `fullName` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |

### AiHealth

| Field | Required | Schema / validation |
|---|---|---|
| `status` | Yes | `{"type":"string","enum":["ok"]}` |
| `service` | Yes | `{"type":"string","enum":["ai-service"]}` |

### AiReadiness

| Field | Required | Schema / validation |
|---|---|---|
| `status` | Yes | `{"type":"string","enum":["READY","NOT_READY"]}` |
| `mode` | Yes | `{"type":"string","enum":["MOCK","REAL"]}` |
| `modelId` | Yes | `{"type":"string","nullable":true}` |
| `modelVersion` | Yes | `{"type":"string","nullable":true}` |
| `livenessModelVersion` | Yes | `{"type":"string","nullable":true}` |
| `simulated` | Yes | `{"type":"boolean"}` |
| `reason` | Yes | `{"type":"string","nullable":true}` |

### ApiError

| Field | Required | Schema / validation |
|---|---|---|
| `code` | Yes | `{"type":"string","enum":["ACCOUNT_LOCKED","AI_UNAVAILABLE","ALREADY_INSIDE","ASSIGNMENT_EXISTS","CAPACITY_REACHED","CHALLENGE_ALREADY_USED","CHALLENGE_EXPIRED","CHALLENGE_INVALID","CODE_EXISTS","CONSENT_POLICY_CHANGED","CONSENT_REQUIRED","CURRENT_PASSWORD_INVALID","DB_UNAVAILABLE","EMAIL_EXISTS","ENROLLMENT_CHANGED","FACE_NOT_FOUND","FORBIDDEN","IDEMPOTENCY_CONFLICT","IDEMPOTENCY_KEY_REQUIRED","IMAGE_INVALID","INCONSISTENT_FACES","INTERNAL_ERROR","INVALID_CREDENTIALS","INVALID_JSON","INVALID_QUERY","INVALID_REFRESH_TOKEN","INVALID_REQUEST","INVALID_SERVICE_KEY","INVALID_TIME_RANGE","INVALID_TOKEN_PURPOSE","KIOSK_REACTIVATION_REQUIRES_ROTATION","KIOSK_REVOKED","LAST_ADMIN_PROTECTED","LIBRARY_CLOSED","LIVENESS_FAILED","LOW_QUALITY","MODEL_NOT_CALIBRATED","MODEL_NOT_READY","MODEL_VERSION_MISMATCH","MULTIPLE_FACES","NOT_INSIDE","NO_MATCH","PASSWORD_CHANGE_REQUIRED","PASSWORD_UNCHANGED","PAYLOAD_TOO_LARGE","QR_ALREADY_USED","QR_EXPIRED","QR_INVALID","RATE_LIMITED","REQUEST_ABORTED","REQUEST_IN_PROGRESS","RESOURCE_NOT_FOUND","SCAN_TOO_SOON","SHIFT_CANCELLED","SHIFT_OVERLAP","SIMULATED_RESULT_REJECTED","STAFF_NOT_ELIGIBLE","SUBJECT_NOT_ELIGIBLE","TOKEN_EXPIRED","TOKEN_REVOKED","UNAUTHENTICATED","UNKNOWN_FIELD","USER_HAS_OPEN_SESSION","VALIDATION_ERROR","VERSION_CONFLICT","VIDEO_INVALID"]}` |
| `message` | Yes | `{"type":"string"}` |
| `fieldErrors` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/FieldError"}}` |
| `traceId` | Yes | `{"type":"string"}` |
| `timestamp` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `fallbackRecommended` | Yes | `{"type":"boolean","default":false}` |

### AssignStaffRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `staffIds` | Yes | `{"type":"array","items":{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"},"minItems":1,"maxItems":100,"uniqueItems":true}` |

### Assignment

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `shiftId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `staff` | Yes | `{"$ref":"#/components/schemas/Actor"}` |
| `startsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `endsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `status` | Yes | `{"type":"string","enum":["ACTIVE","CANCELLED"]}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `assignedBy` | Yes | `{"$ref":"#/components/schemas/Actor"}` |
| `createdAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `updatedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### AssignmentBatch

| Field | Required | Schema / validation |
|---|---|---|
| `shift` | Yes | `{"$ref":"#/components/schemas/Shift"}` |
| `assignments` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/Assignment"}}` |

### AssignmentPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/Assignment"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### BackendHealth

| Field | Required | Schema / validation |
|---|---|---|
| `status` | Yes | `{"type":"string","enum":["UP","DOWN"]}` |

### CancelShiftRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `reason` | Yes | `{"type":"string","minLength":1,"maxLength":1000}` |

### ChallengeInstruction

| Field | Required | Schema / validation |
|---|---|---|
| `action` | Yes | `{"type":"string","enum":["BLINK","TURN_LEFT","TURN_RIGHT"]}` |
| `order` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":2}` |

### ChangePasswordRequest

| Field | Required | Schema / validation |
|---|---|---|
| `currentPassword` | Yes | `{"type":"string","minLength":1,"maxLength":64,"format":"password","writeOnly":true}` |
| `newPassword` | Yes | `{"type":"string","minLength":12,"maxLength":64,"format":"password","writeOnly":true,"description":"12–64 characters, with total UTF-8 length no greater than 72 bytes (BCrypt). Do not trim passwords.","example":"DevOnly!2026Change"}` |

### ConfigChangedEvent

| Field | Required | Schema / validation |
|---|---|---|
| `eventId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `occurredAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `revision` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `count` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `maxCapacity` | Yes | `{"type":"integer","format":"int64","minimum":1}` |
| `nearCapacity` | Yes | `{"type":"boolean"}` |
| `change` | Yes | `{"type":"object","additionalProperties":false,"properties":{"action":{"type":"string","enum":["CONFIG_CHANGED"]}},"required":["action"]}` |

### ConsentRequest

| Field | Required | Schema / validation |
|---|---|---|
| `policyVersion` | Yes | `{"type":"string","minLength":1,"maxLength":32}` |
| `accepted` | Yes | `{"type":"boolean","enum":[true]}` |

### CreateKioskRequest

| Field | Required | Schema / validation |
|---|---|---|
| `code` | Yes | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `name` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `mode` | Yes | `{"type":"string","enum":["ENTRY","EXIT","AUTO"]}` |

### CreateShiftRequest

| Field | Required | Schema / validation |
|---|---|---|
| `name` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `startsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `endsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### CreateUserRequest

| Field | Required | Schema / validation |
|---|---|---|
| `code` | Yes | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `email` | Yes | `{"type":"string","format":"email","maxLength":254,"example":"librarian@example.test","description":"Trim and lowercase the entire value before storage."}` |
| `fullName` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `role` | Yes | `{"type":"string","enum":["STUDENT","LIBRARIAN","ADMIN"]}` |
| `password` | Yes | `{"type":"string","minLength":12,"maxLength":64,"format":"password","writeOnly":true,"description":"12–64 characters, with total UTF-8 length no greater than 72 bytes (BCrypt). Do not trim passwords.","example":"DevOnly!2026Change"}` |
| `mustChangePassword` | No | `{"type":"boolean","default":true}` |

### CreateVisitorRequest

| Field | Required | Schema / validation |
|---|---|---|
| `fullName` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |

### EnrollmentUpload

| Field | Required | Schema / validation |
|---|---|---|
| `images` | Yes | `{"type":"array","items":{"type":"string","format":"binary"},"minItems":3,"maxItems":5}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |

### FaceAccessUpload

| Field | Required | Schema / validation |
|---|---|---|
| `clip` | Yes | `{"type":"string","format":"binary"}` |
| `challengeId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |

### FaceCaptureRules

| Field | Required | Schema / validation |
|---|---|---|
| `imageMimeTypes` | Yes | `{"type":"array","items":{"type":"string","enum":["image/jpeg","image/png"]}}` |
| `minImages` | Yes | `{"type":"integer","format":"int64","enum":[3]}` |
| `maxImages` | Yes | `{"type":"integer","format":"int64","enum":[5]}` |
| `maxImageBytes` | Yes | `{"type":"integer","format":"int64","enum":[5242880]}` |
| `maxTotalImageBytes` | Yes | `{"type":"integer","format":"int64","enum":[26214400]}` |
| `maxImagePixels` | Yes | `{"type":"integer","format":"int64","enum":[16000000]}` |
| `clipMimeTypes` | Yes | `{"type":"array","items":{"type":"string","enum":["video/mp4"]}}` |
| `maxClipBytes` | Yes | `{"type":"integer","format":"int64","enum":[10485760]}` |
| `minClipDurationSeconds` | Yes | `{"type":"number","format":"double","enum":[1]}` |
| `maxClipDurationSeconds` | Yes | `{"type":"number","format":"double","enum":[3]}` |
| `maxClipFps` | Yes | `{"type":"integer","format":"int64","enum":[30]}` |
| `maxClipWidth` | Yes | `{"type":"integer","format":"int64","enum":[1280]}` |
| `maxClipHeight` | Yes | `{"type":"integer","format":"int64","enum":[720]}` |

### FaceChallenge

| Field | Required | Schema / validation |
|---|---|---|
| `challengeId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `expiresAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `instructions` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/ChallengeInstruction"},"minItems":2,"maxItems":2}` |
| `captureRules` | Yes | `{"$ref":"#/components/schemas/FaceCaptureRules"}` |

### FaceConsent

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `policyVersion` | Yes | `{"type":"string"}` |
| `grantedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `revokedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00","nullable":true}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |

### FaceDeletion

| Field | Required | Schema / validation |
|---|---|---|
| `isEnrolled` | Yes | `{"type":"boolean","enum":[false]}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `deletedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### FaceEnrollment

| Field | Required | Schema / validation |
|---|---|---|
| `isEnrolled` | Yes | `{"type":"boolean"}` |
| `consent` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/FaceConsent"}],"nullable":true}` |
| `imageCount` | Yes | `{"type":"integer","format":"int64","minimum":0,"maximum":5}` |
| `modelId` | Yes | `{"type":"string","nullable":true}` |
| `modelVersion` | Yes | `{"type":"string","nullable":true}` |
| `enrolledAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00","nullable":true}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |

### FacePolicy

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"string","example":"1.0"}` |
| `title` | Yes | `{"type":"string"}` |
| `content` | Yes | `{"type":"string"}` |
| `captureRules` | Yes | `{"$ref":"#/components/schemas/FaceCaptureRules"}` |

### FieldError

| Field | Required | Schema / validation |
|---|---|---|
| `field` | Yes | `{"type":"string"}` |
| `message` | Yes | `{"type":"string"}` |

### HeartbeatRequest

| Field | Required | Schema / validation |
|---|---|---|
| `appVersion` | Yes | `{"type":"string","minLength":1,"maxLength":32}` |
| `cameraStatus` | Yes | `{"type":"string","enum":["OK","ERROR","UNAVAILABLE"]}` |

### HeartbeatResult

| Field | Required | Schema / validation |
|---|---|---|
| `serverTime` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `heartbeatIntervalSeconds` | Yes | `{"type":"integer","format":"int64","example":30}` |
| `kiosk` | Yes | `{"$ref":"#/components/schemas/Kiosk"}` |

### InternalEmbeddingResult

| Field | Required | Schema / validation |
|---|---|---|
| `embeddings` | Yes | `{"type":"array","items":{"type":"array","items":{"type":"number","format":"double"},"minItems":512,"maxItems":512},"minItems":3,"maxItems":5}` |
| `dimension` | Yes | `{"type":"integer","format":"int64","enum":[512]}` |
| `modelId` | Yes | `{"type":"string"}` |
| `modelVersion` | Yes | `{"type":"string"}` |
| `simulated` | Yes | `{"type":"boolean"}` |

### InternalEnrollmentUpload

| Field | Required | Schema / validation |
|---|---|---|
| `images` | Yes | `{"type":"array","items":{"type":"string","format":"binary"},"minItems":3,"maxItems":5}` |

### InternalRecognitionResult

| Field | Required | Schema / validation |
|---|---|---|
| `matched` | Yes | `{"type":"boolean"}` |
| `userId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001","nullable":true}` |
| `biometricVersion` | Yes | `{"type":"integer","format":"int64","minimum":0,"nullable":true}` |
| `consentId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001","nullable":true}` |
| `cosineDistance` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":2,"nullable":true}` |
| `distanceGap` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":2,"nullable":true}` |
| `livenessPassed` | Yes | `{"type":"boolean"}` |
| `livenessScore` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":1}` |
| `modelId` | Yes | `{"type":"string"}` |
| `modelVersion` | Yes | `{"type":"string"}` |
| `livenessModelVersion` | Yes | `{"type":"string"}` |
| `simulated` | Yes | `{"type":"boolean"}` |
| `outcome` | Yes | `{"type":"string","enum":["MATCHED","NO_MATCH","LIVENESS_FAILED"]}` |

### InternalRecognitionUpload

| Field | Required | Schema / validation |
|---|---|---|
| `clip` | Yes | `{"type":"string","format":"binary"}` |
| `challengeId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `challengeInstructions` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/ChallengeInstruction"},"minItems":2,"maxItems":2,"description":"JSON part: backend supplies trusted ordered actions, not App."}` |
| `modelVersion` | Yes | `{"type":"string"}` |
| `maxCosineDistance` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":2}` |
| `minDistanceGap` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":2}` |
| `livenessMinScore` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":1}` |

### Kiosk

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `code` | Yes | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `name` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `mode` | Yes | `{"type":"string","enum":["ENTRY","EXIT","AUTO"]}` |
| `status` | Yes | `{"type":"string","enum":["ACTIVE","REVOKED"]}` |
| `isOnline` | Yes | `{"type":"boolean"}` |
| `lastSeenAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00","nullable":true}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `createdAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `updatedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### KioskCredential

| Field | Required | Schema / validation |
|---|---|---|
| `kiosk` | Yes | `{"$ref":"#/components/schemas/Kiosk"}` |
| `credential` | Yes | `{"type":"string","description":"Secret returned once; the server stores only its hash. Never log it."}` |

### KioskLoginRequest

| Field | Required | Schema / validation |
|---|---|---|
| `kioskId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `credential` | Yes | `{"type":"string","minLength":32,"maxLength":256,"writeOnly":true}` |

### KioskPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/Kiosk"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### KioskRuntimeConfig

| Field | Required | Schema / validation |
|---|---|---|
| `kioskId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `mode` | Yes | `{"type":"string","enum":["ENTRY","EXIT","AUTO"]}` |
| `timezone` | Yes | `{"type":"string","enum":["Asia/Ho_Chi_Minh"]}` |
| `openingHours` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/OpeningSlot"}}` |
| `qrTtlSeconds` | Yes | `{"type":"integer","format":"int64","enum":[30]}` |
| `scanCooldownSeconds` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":60}` |
| `faceEnabled` | Yes | `{"type":"boolean"}` |
| `faceCapture` | Yes | `{"$ref":"#/components/schemas/FaceCaptureRules"}` |
| `serverTime` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `configVersion` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |

### KioskSummary

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `code` | Yes | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `name` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |

### KioskToken

| Field | Required | Schema / validation |
|---|---|---|
| `accessToken` | Yes | `{"type":"string"}` |
| `tokenType` | Yes | `{"type":"string","enum":["Bearer"]}` |
| `expiresIn` | Yes | `{"type":"integer","format":"int64","example":3600}` |
| `kiosk` | Yes | `{"$ref":"#/components/schemas/Kiosk"}` |

### LoginRequest

| Field | Required | Schema / validation |
|---|---|---|
| `identifier` | Yes | `{"type":"string","minLength":1,"maxLength":254,"example":"LIB001","description":"Code or email, trimmed; code uppercase/email lowercase."}` |
| `password` | Yes | `{"type":"string","minLength":1,"maxLength":64,"format":"password","writeOnly":true}` |

### ManualAccessRequest

Exactly one variant: `ManualUserAccessRequest`, `ManualVisitorAccessRequest`.

### ManualUserAccessRequest

| Field | Required | Schema / validation |
|---|---|---|
| `userId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `action` | Yes | `{"type":"string","enum":["CHECK_IN","CHECK_OUT"]}` |
| `reason` | Yes | `{"type":"string","minLength":1,"maxLength":1000}` |

### ManualVisitorAccessRequest

| Field | Required | Schema / validation |
|---|---|---|
| `visitorId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `action` | Yes | `{"type":"string","enum":["CHECK_IN","CHECK_OUT"]}` |
| `reason` | Yes | `{"type":"string","minLength":1,"maxLength":1000}` |

### MyShift

| Field | Required | Schema / validation |
|---|---|---|
| `shift` | Yes | `{"$ref":"#/components/schemas/Shift"}` |
| `assignment` | Yes | `{"$ref":"#/components/schemas/Assignment"}` |

### MyShiftPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/MyShift"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### Occupancy

| Field | Required | Schema / validation |
|---|---|---|
| `count` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `maxCapacity` | Yes | `{"type":"integer","format":"int64","minimum":1}` |
| `nearCapacity` | Yes | `{"type":"boolean"}` |
| `capacityEnforcement` | Yes | `{"type":"boolean"}` |
| `revision` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `asOf` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### OccupancyChange

| Field | Required | Schema / validation |
|---|---|---|
| `sessionId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `action` | Yes | `{"type":"string","enum":["CHECK_IN","CHECK_OUT","AUTO_CHECK_OUT"]}` |

### OccupancyEvent

| Field | Required | Schema / validation |
|---|---|---|
| `eventId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `occurredAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `revision` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `count` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `maxCapacity` | Yes | `{"type":"integer","format":"int64","minimum":1}` |
| `nearCapacity` | Yes | `{"type":"boolean"}` |
| `change` | Yes | `{"$ref":"#/components/schemas/OccupancyChange"}` |

### Occupant

| Field | Required | Schema / validation |
|---|---|---|
| `sessionId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `subject` | Yes | `{"$ref":"#/components/schemas/Subject"}` |
| `checkInTime` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `durationSeconds` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `checkInMethod` | Yes | `{"type":"string","enum":["FACE","QR","MANUAL"]}` |

### OccupantPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/Occupant"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### OpeningSlot

| Field | Required | Schema / validation |
|---|---|---|
| `dayOfWeek` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":7,"description":"ISO weekday: Monday=1"}` |
| `opensAt` | Yes | `{"type":"string","pattern":"^([01][0-9]/2[0-3]):[0-5][0-9]$","example":"08:00"}` |
| `closesAt` | Yes | `{"type":"string","pattern":"^([01][0-9]/2[0-3]):[0-5][0-9]$","example":"22:00"}` |

### OutcomeCount

| Field | Required | Schema / validation |
|---|---|---|
| `outcome` | Yes | `{"type":"string"}` |
| `count` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### PatchAssignmentRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `staffId` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |

### PatchKioskRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `name` | No | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `mode` | No | `{"type":"string","enum":["ENTRY","EXIT","AUTO"]}` |
| `status` | No | `{"type":"string","enum":["ACTIVE","REVOKED"]}` |

### PatchShiftRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `name` | No | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `startsAt` | No | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `endsAt` | No | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### PatchSystemConfigRequest

| Field | Required | Schema / validation |
|---|---|---|
| `timezone` | No | `{"type":"string","enum":["Asia/Ho_Chi_Minh"]}` |
| `openingHours` | No | `{"type":"array","items":{"$ref":"#/components/schemas/OpeningSlot"},"maxItems":7,"description":"At most one slot per day; days without slots are closed. opensAt=closesAt is invalid. closesAt<opensAt means overnight."}` |
| `maxCapacity` | No | `{"type":"integer","format":"int64","minimum":1,"maximum":100000,"default":250}` |
| `nearCapacityRatio` | No | `{"type":"number","format":"double","minimum":0.1,"maximum":1,"default":0.9}` |
| `capacityEnforcement` | No | `{"type":"boolean","default":false}` |
| `maxSessionDurationMinutes` | No | `{"type":"integer","format":"int64","minimum":1,"maximum":10080,"nullable":true,"default":null}` |
| `scanCooldownSeconds` | No | `{"type":"integer","format":"int64","minimum":1,"maximum":60,"default":10}` |
| `faceModelVersion` | No | `{"type":"string","minLength":1,"maxLength":128,"nullable":true}` |
| `faceMaxCosineDistance` | No | `{"type":"number","format":"double","minimum":0,"maximum":2,"nullable":true}` |
| `faceMinDistanceGap` | No | `{"type":"number","format":"double","minimum":0,"maximum":2,"nullable":true}` |
| `livenessMinScore` | No | `{"type":"number","format":"double","minimum":0,"maximum":1,"nullable":true}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |

### PatchUserRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `code` | No | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `email` | No | `{"type":"string","format":"email","maxLength":254,"example":"librarian@example.test","description":"Trim and lowercase the entire value before storage."}` |
| `fullName` | No | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `role` | No | `{"type":"string","enum":["STUDENT","LIBRARIAN","ADMIN"]}` |
| `status` | No | `{"type":"string","enum":["ACTIVE","LOCKED"]}` |

At least one field besides version; reject null/unknown fields.

### QrAccessRequest

| Field | Required | Schema / validation |
|---|---|---|
| `token` | Yes | `{"type":"string","minLength":20,"maxLength":4096,"writeOnly":true}` |

### QrToken

| Field | Required | Schema / validation |
|---|---|---|
| `token` | Yes | `{"type":"string"}` |
| `expiresAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `refreshAfterSeconds` | Yes | `{"type":"integer","format":"int64","example":25}` |

### RealtimeEvent

Exactly one variant: `OccupancyEvent`, `ConfigChangedEvent`.

### RecognitionAnalytics

| Field | Required | Schema / validation |
|---|---|---|
| `from` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `to` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `totalAttempts` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `matched` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `failed` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `failureRate` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":1,"nullable":true}` |
| `p50LatencyMs` | Yes | `{"type":"number","format":"double","minimum":0,"nullable":true}` |
| `p95LatencyMs` | Yes | `{"type":"number","format":"double","minimum":0,"nullable":true}` |
| `outcomes` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/OutcomeCount"}}` |

### RefreshRequest

| Field | Required | Schema / validation |
|---|---|---|
| `refreshToken` | Yes | `{"type":"string","minLength":20,"maxLength":4096,"writeOnly":true}` |

### ResetPasswordRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `newPassword` | Yes | `{"type":"string","minLength":12,"maxLength":64,"format":"password","writeOnly":true,"description":"12–64 characters, with total UTF-8 length no greater than 72 bytes (BCrypt). Do not trim passwords.","example":"DevOnly!2026Change"}` |

### Shift

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `name` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `startsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `endsAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `status` | Yes | `{"type":"string","enum":["ACTIVE","CANCELLED"]}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `assignmentCount` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `createdBy` | Yes | `{"$ref":"#/components/schemas/Actor"}` |
| `createdAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `updatedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `cancellationReason` | Yes | `{"type":"string","nullable":true,"maxLength":1000}` |

### ShiftPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/Shift"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### Subject

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `kind` | Yes | `{"type":"string","enum":["USER","VISITOR"]}` |
| `code` | Yes | `{"type":"string","maxLength":40}` |
| `fullName` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |

### SystemConfig

| Field | Required | Schema / validation |
|---|---|---|
| `timezone` | Yes | `{"type":"string","enum":["Asia/Ho_Chi_Minh"]}` |
| `openingHours` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/OpeningSlot"},"maxItems":7,"description":"At most one slot per day; days without slots are closed. opensAt=closesAt is invalid. closesAt<opensAt means overnight."}` |
| `maxCapacity` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100000,"default":250}` |
| `nearCapacityRatio` | Yes | `{"type":"number","format":"double","minimum":0.1,"maximum":1,"default":0.9}` |
| `capacityEnforcement` | Yes | `{"type":"boolean","default":false}` |
| `maxSessionDurationMinutes` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":10080,"nullable":true,"default":null}` |
| `scanCooldownSeconds` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":60,"default":10}` |
| `faceModelVersion` | Yes | `{"type":"string","minLength":1,"maxLength":128,"nullable":true}` |
| `faceMaxCosineDistance` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":2,"nullable":true}` |
| `faceMinDistanceGap` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":2,"nullable":true}` |
| `livenessMinScore` | Yes | `{"type":"number","format":"double","minimum":0,"maximum":1,"nullable":true}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `updatedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `updatedBy` | Yes | `{"type":"object","allOf":[{"$ref":"#/components/schemas/Actor"}],"nullable":true}` |

### TokenPair

| Field | Required | Schema / validation |
|---|---|---|
| `accessToken` | Yes | `{"type":"string"}` |
| `refreshToken` | Yes | `{"type":"string"}` |
| `tokenType` | Yes | `{"type":"string","enum":["Bearer"]}` |
| `expiresIn` | Yes | `{"type":"integer","format":"int64","example":900}` |
| `user` | Yes | `{"$ref":"#/components/schemas/User"}` |

### User

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `code` | Yes | `{"type":"string","pattern":"^[A-Z0-9][A-Z0-9_-]{2,31}$","minLength":3,"maxLength":32,"example":"LIB001","description":"Trim and uppercase before validation/storage; a shared code for all roles."}` |
| `email` | Yes | `{"type":"string","format":"email","maxLength":254,"example":"librarian@example.test","description":"Trim and lowercase the entire value before storage."}` |
| `fullName` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `role` | Yes | `{"type":"string","enum":["STUDENT","LIBRARIAN","ADMIN"]}` |
| `status` | Yes | `{"type":"string","enum":["ACTIVE","LOCKED"]}` |
| `mustChangePassword` | Yes | `{"type":"boolean"}` |
| `faceEnrolled` | Yes | `{"type":"boolean"}` |
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |
| `createdAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |
| `updatedAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### UserPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/User"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

### VersionRequest

| Field | Required | Schema / validation |
|---|---|---|
| `version` | Yes | `{"type":"integer","format":"int64","minimum":0,"description":"Optimistic lock; send the most recently read version."}` |

### Visitor

| Field | Required | Schema / validation |
|---|---|---|
| `id` | Yes | `{"type":"string","format":"uuid","example":"14867700-9090-4000-8000-000000000001"}` |
| `referenceCode` | Yes | `{"type":"string","example":"GUEST-000001"}` |
| `fullName` | Yes | `{"type":"string","minLength":1,"maxLength":150,"example":"Alex Nguyen","description":"Trim; reject whitespace-only values."}` |
| `createdBy` | Yes | `{"$ref":"#/components/schemas/Actor"}` |
| `createdAt` | Yes | `{"type":"string","format":"date-time","example":"2026-10-07T10:00:00+07:00"}` |

### VisitorPage

| Field | Required | Schema / validation |
|---|---|---|
| `items` | Yes | `{"type":"array","items":{"$ref":"#/components/schemas/Visitor"}}` |
| `page` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `size` | Yes | `{"type":"integer","format":"int64","minimum":1,"maximum":100}` |
| `totalElements` | Yes | `{"type":"integer","format":"int64","minimum":0}` |
| `totalPages` | Yes | `{"type":"integer","format":"int64","minimum":0}` |

## 5. Realtime STOMP

WebSocket is a separate contract, not an HTTP endpoint. The `RealtimeEvent` schema is defined in the OpenAPI x-realtime extension.

- Native WebSocket ws://host:8080/ws (wss in production), STOMP 1.2, without SockJS. CONNECT includes Authorization: Bearer user accessToken; only LIBRARIAN/ADMIN are allowed. Heartbeat: 10000,10000.
- SUBSCRIBE /topic/occupancy. The server checks role/purpose/expiry and blocks client SEND. Close sessions when tokens expire, families are revoked, authVersion changes, or accounts are locked.
- Every session mutation increments library_state.occupancy_revision within its transaction; events publish after commit with revision/count from the same snapshot. Capacity/nearCapacityRatio configuration changes also increment revision and publish CONFIG_CHANGED.
- Clients discard events with old revisions; CONNECT→SUBSCRIBE→GET snapshot, then process newer revisions. Refetch the list on changes; do not publish full identities/emails to the topic. Always fetch a REST snapshot on reconnect; event replay is not guaranteed.
- CHECK_IN/CHECK_OUT/AUTO_CHECK_OUT events include change.sessionId; CONFIG_CHANGED omits sessionId. Server timestamps and revisions determine ordering; do not use the App device clock.

## 6. Contract tests and handover

- Check every operationId, request schema, success/error schema, role, pagination rule, and x-retry-policy against OpenAPI. Each route has acceptance tests in section 3 and x-acceptance-tests.
- Test the role matrix: missing token 401, wrong purpose 403, wrong role 403, wrong ownership 404. Forced-change tokens can only access auth refresh/logout, me, and me/password.
- Test concurrency with real PostgreSQL: sessions/idempotency/QR/refresh/shifts/consent; do not use H2 to verify extensions/ranges/partial unique indexes.
- Design OpenAPI version: 1.0.0-design. After implementation, export /v3/api-docs and diff it against the contract (operationId,paths,required fields,status codes,security); opening Swagger alone is insufficient.
- AI models/liveness require real quality tests, versions/hashes/thresholds; a complete API contract does not establish recognition accuracy. Implement the contract, then measure and calibrate models while preserving the agreed interfaces.
- Swagger UI serves the backend contract; internal AI Swagger is for backend developers. App handover does not require clients to call AI directly.

Format references: [OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3), [Swagger multipart](https://swagger.io/docs/specification/v3_0/describing-request-body/multipart-requests/).
