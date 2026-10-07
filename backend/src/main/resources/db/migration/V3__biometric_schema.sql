-- =============================================================================
-- V3: Biometrics, Embeddings, Challenges, Recognition Attempts & Candidates View
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Biometric Consents
-- -----------------------------------------------------------------------------
CREATE TABLE biometric_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    policy_version VARCHAR(20) NOT NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMPTZ,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uq_user_consent_id UNIQUE (id, user_id)
);

CREATE UNIQUE INDEX uq_active_consent ON biometric_consents(user_id)
WHERE revoked_at IS NULL;

-- -----------------------------------------------------------------------------
-- 2. Face Embeddings (512-dimensional ArcFace vectors)
-- -----------------------------------------------------------------------------
CREATE TABLE face_embeddings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    consent_id UUID NOT NULL,
    embedding vector(512) NOT NULL,
    model_id VARCHAR(100) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_face_embeddings_consent FOREIGN KEY (consent_id, user_id)
        REFERENCES biometric_consents(id, user_id) ON DELETE CASCADE
);

CREATE INDEX idx_face_embeddings_user ON face_embeddings(user_id);

-- -----------------------------------------------------------------------------
-- 3. Face Challenges (Single-use liveness challenges)
-- -----------------------------------------------------------------------------
CREATE TABLE face_challenges (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    kiosk_id UUID NOT NULL REFERENCES kiosks(id),
    instructions JSONB NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    config_version BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL,
    consumed_at TIMESTAMPTZ
);

CREATE INDEX idx_face_challenges_kiosk_expires ON face_challenges(kiosk_id, expires_at);

-- -----------------------------------------------------------------------------
-- 4. Recognition Attempts (Real kiosk inferences)
-- -----------------------------------------------------------------------------
CREATE TABLE recognition_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    access_request_id UUID UNIQUE REFERENCES access_requests(id),
    kiosk_id UUID NOT NULL REFERENCES kiosks(id),
    user_id UUID REFERENCES users(id),
    outcome VARCHAR(50) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    cosine_distance DOUBLE PRECISION,
    liveness_score DOUBLE PRECISION,
    latency_ms INT NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_recognition_attempts_occurred ON recognition_attempts(occurred_at DESC);
CREATE INDEX idx_recognition_attempts_outcome ON recognition_attempts(outcome, occurred_at);

-- -----------------------------------------------------------------------------
-- 5. Read-only Candidate View for AI service
-- -----------------------------------------------------------------------------
CREATE OR REPLACE VIEW ai_face_candidates AS
SELECT
    fe.id AS embedding_id,
    fe.user_id,
    fe.consent_id,
    u.biometric_version,
    fe.embedding,
    fe.model_id,
    fe.model_version
FROM face_embeddings fe
JOIN users u ON u.id = fe.user_id
JOIN biometric_consents bc ON bc.id = fe.consent_id AND bc.user_id = fe.user_id
WHERE u.status = 'ACTIVE'
  AND u.role = 'STUDENT'
  AND bc.revoked_at IS NULL;
