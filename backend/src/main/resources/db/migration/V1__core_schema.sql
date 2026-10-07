-- =============================================================================
-- V1: Core Extensions and Base Schema
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- -----------------------------------------------------------------------------
-- 1. Users
-- -----------------------------------------------------------------------------
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    must_change_password BOOLEAN NOT NULL DEFAULT false,
    auth_version BIGINT NOT NULL DEFAULT 0,
    biometric_version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uq_user_code UNIQUE (code),
    CONSTRAINT uq_user_email UNIQUE (email),
    CONSTRAINT chk_user_code_normalized CHECK (code = upper(trim(code)) AND code NOT LIKE '%@%'),
    CONSTRAINT chk_user_email_normalized CHECK (email = lower(trim(email))),
    CONSTRAINT chk_user_role CHECK (role IN ('STUDENT', 'LIBRARIAN', 'ADMIN')),
    CONSTRAINT chk_user_status CHECK (status IN ('ACTIVE', 'LOCKED'))
);

CREATE INDEX idx_users_role_status ON users(role, status);

-- -----------------------------------------------------------------------------
-- 2. Auth Refresh Tokens
-- -----------------------------------------------------------------------------
CREATE TABLE auth_refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    family_id UUID NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    replaced_by UUID REFERENCES auth_refresh_tokens(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_refresh_token_hash UNIQUE (token_hash)
);

CREATE INDEX idx_refresh_tokens_family ON auth_refresh_tokens(family_id);
CREATE INDEX idx_refresh_tokens_expires_at ON auth_refresh_tokens(expires_at);

-- -----------------------------------------------------------------------------
-- 3. Kiosks
-- -----------------------------------------------------------------------------
CREATE TABLE kiosks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    mode VARCHAR(20) NOT NULL DEFAULT 'AUTO',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    credential_hash VARCHAR(255),
    credential_version BIGINT NOT NULL DEFAULT 0,
    last_seen_at TIMESTAMPTZ,
    app_version VARCHAR(50),
    camera_status VARCHAR(50),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_kiosk_code UNIQUE (code),
    CONSTRAINT chk_kiosk_mode CHECK (mode IN ('ENTRY', 'EXIT', 'AUTO')),
    CONSTRAINT chk_kiosk_status CHECK (status IN ('ACTIVE', 'REVOKED'))
);

-- -----------------------------------------------------------------------------
-- 4. Visitors (Guests)
-- -----------------------------------------------------------------------------
CREATE TABLE visitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name VARCHAR(255) NOT NULL,
    reference_code VARCHAR(50) NOT NULL,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_visitor_ref_code UNIQUE (reference_code)
);

-- -----------------------------------------------------------------------------
-- 5. System Configuration
-- -----------------------------------------------------------------------------
CREATE TABLE system_config (
    key VARCHAR(50) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_by UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

-- -----------------------------------------------------------------------------
-- 6. Library State (Lock table for occupancy and session concurrency)
-- -----------------------------------------------------------------------------
CREATE TABLE library_state (
    id SMALLINT PRIMARY KEY CHECK (id = 1),
    occupancy_revision BIGINT NOT NULL DEFAULT 0
);

-- Initial row for library state
INSERT INTO library_state (id, occupancy_revision) VALUES (1, 0);

-- -----------------------------------------------------------------------------
-- 7. Access Requests (Idempotency and Dedup)
-- -----------------------------------------------------------------------------
CREATE TABLE access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    principal_type VARCHAR(20) NOT NULL,
    principal_id UUID NOT NULL,
    idempotency_key UUID NOT NULL,
    request_method VARCHAR(10) NOT NULL,
    request_path VARCHAR(255) NOT NULL,
    request_digest VARCHAR(64) NOT NULL,
    status VARCHAR(20) NOT NULL,
    response_status INT,
    response_body JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processing_deadline TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT uq_access_request UNIQUE (principal_type, principal_id, idempotency_key),
    CONSTRAINT chk_principal_type CHECK (principal_type IN ('USER', 'KIOSK')),
    CONSTRAINT chk_access_request_status CHECK (status IN ('IN_PROGRESS', 'COMPLETED'))
);

CREATE INDEX idx_access_requests_expires_at ON access_requests(expires_at);

-- -----------------------------------------------------------------------------
-- 8. QR Grants (Rotating single-use tokens)
-- -----------------------------------------------------------------------------
CREATE TABLE qr_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    nonce_hash VARCHAR(64) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_qr_grant_nonce UNIQUE (nonce_hash)
);

CREATE INDEX idx_qr_grants_expires_at ON qr_grants(expires_at);

-- -----------------------------------------------------------------------------
-- 9. Check-in Logs (Sessions)
-- -----------------------------------------------------------------------------
CREATE TABLE checkin_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    visitor_id UUID REFERENCES visitors(id),
    method VARCHAR(20) NOT NULL,
    kiosk_id UUID REFERENCES kiosks(id),
    performed_by UUID REFERENCES users(id),
    manual_reason TEXT,
    check_in_time TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    scheduled_checkout_at TIMESTAMPTZ,
    entry_config_version BIGINT,
    check_out_time TIMESTAMPTZ,
    check_out_method VARCHAR(20),
    check_out_kiosk_id UUID REFERENCES kiosks(id),
    checked_out_by UUID REFERENCES users(id),
    checkout_reason VARCHAR(30),
    checkout_manual_reason TEXT,
    CONSTRAINT chk_subject_xor CHECK (
        (user_id IS NOT NULL AND visitor_id IS NULL) OR
        (user_id IS NULL AND visitor_id IS NOT NULL)
    ),
    CONSTRAINT chk_checkout_after_checkin CHECK (
        check_out_time IS NULL OR check_out_time >= check_in_time
    ),
    CONSTRAINT chk_in_method_kiosk CHECK (
        (method = 'MANUAL' AND performed_by IS NOT NULL AND manual_reason IS NOT NULL AND kiosk_id IS NULL) OR
        (method IN ('FACE', 'QR') AND kiosk_id IS NOT NULL AND performed_by IS NULL AND manual_reason IS NULL)
    ),
    CONSTRAINT chk_checkin_method CHECK (method IN ('FACE', 'QR', 'MANUAL')),
    CONSTRAINT chk_checkout_method CHECK (check_out_method IS NULL OR check_out_method IN ('FACE', 'QR', 'MANUAL')),
    CONSTRAINT chk_checkout_reason CHECK (
        checkout_reason IS NULL OR checkout_reason IN ('USER_ACTION', 'MANUAL', 'CLOSING_TIME', 'MAX_DURATION')
    )
);

-- Partial unique indexes ensuring single open session per user and visitor
CREATE UNIQUE INDEX uq_open_user_session ON checkin_logs(user_id)
WHERE user_id IS NOT NULL AND check_out_time IS NULL;

CREATE UNIQUE INDEX uq_open_visitor_session ON checkin_logs(visitor_id)
WHERE visitor_id IS NOT NULL AND check_out_time IS NULL;

CREATE INDEX idx_checkin_logs_user_history ON checkin_logs(user_id, check_in_time DESC);
CREATE INDEX idx_checkin_logs_occupancy ON checkin_logs(check_in_time) WHERE check_out_time IS NULL;

-- -----------------------------------------------------------------------------
-- 10. Audit Events
-- -----------------------------------------------------------------------------
CREATE TABLE audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id),
    actor_kiosk_id UUID REFERENCES kiosks(id),
    action VARCHAR(100) NOT NULL,
    target_type VARCHAR(100) NOT NULL,
    target_id VARCHAR(100),
    metadata JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_events_occurred_at ON audit_events(occurred_at DESC);

-- -----------------------------------------------------------------------------
-- Seed Operational & Face Policy Configuration
-- -----------------------------------------------------------------------------
INSERT INTO system_config (key, value, version) VALUES
(
    'operational',
    '{
        "timezone": "Asia/Ho_Chi_Minh",
        "openingHours": [
            {"dayOfWeek": 1, "opensAt": "08:00", "closesAt": "22:00"},
            {"dayOfWeek": 2, "opensAt": "08:00", "closesAt": "22:00"},
            {"dayOfWeek": 3, "opensAt": "08:00", "closesAt": "22:00"},
            {"dayOfWeek": 4, "opensAt": "08:00", "closesAt": "22:00"},
            {"dayOfWeek": 5, "opensAt": "08:00", "closesAt": "22:00"},
            {"dayOfWeek": 6, "opensAt": "08:00", "closesAt": "22:00"},
            {"dayOfWeek": 7, "opensAt": "08:00", "closesAt": "22:00"}
        ],
        "maxCapacity": 250,
        "nearCapacityRatio": 0.9,
        "capacityEnforcement": false,
        "maxSessionDurationMinutes": null,
        "scanCooldownSeconds": 10,
        "faceModelVersion": null,
        "faceMaxCosineDistance": null,
        "faceMinDistanceGap": null,
        "livenessMinScore": null
    }'::jsonb,
    1
),
(
    'face_policy',
    '{
        "version": "1.0",
        "notice": "Biometric face data is used solely for library entry and exit verification. Data is stored as mathematical vector embeddings and can be revoked and deleted at any time."
    }'::jsonb,
    1
);
