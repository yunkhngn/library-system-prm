-- =============================================================================
-- V2: Staff Shift Scheduling and Overlap Exclusion
-- =============================================================================

CREATE TABLE shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    cancellation_reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_shift_status CHECK (status IN ('ACTIVE', 'CANCELLED')),
    CONSTRAINT chk_shift_duration CHECK (ends_at > starts_at AND ends_at <= starts_at + INTERVAL '24 hours')
);

CREATE INDEX idx_shifts_starts_at ON shifts(starts_at);

CREATE TABLE shift_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID NOT NULL REFERENCES shifts(id) ON DELETE CASCADE,
    staff_id UUID NOT NULL REFERENCES users(id),
    starts_at TIMESTAMPTZ NOT NULL,
    ends_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    assigned_by UUID NOT NULL REFERENCES users(id),
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_assignment_status CHECK (status IN ('ACTIVE', 'CANCELLED')),
    CONSTRAINT chk_assignment_duration CHECK (ends_at > starts_at)
);

CREATE INDEX idx_shift_assignments_staff ON shift_assignments(staff_id, starts_at);

-- Exclusion constraint preventing overlapping active assignments for the same staff member
ALTER TABLE shift_assignments ADD CONSTRAINT no_staff_overlap
EXCLUDE USING gist (
    staff_id WITH =,
    tstzrange(starts_at, ends_at, '[)') WITH &&
) WHERE (status = 'ACTIVE');
