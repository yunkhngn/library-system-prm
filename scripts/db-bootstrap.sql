-- =============================================================================
-- Database Bootstrap Script: Provisions dedicated read-only AI service role
-- Execute with: psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -f db-bootstrap.sql
-- =============================================================================

DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'ai_service_user') THEN
        CREATE ROLE ai_service_user WITH LOGIN PASSWORD 'ai_service_secure_password';
    END IF;
END
$$;

-- Grant usage on public schema
GRANT USAGE ON SCHEMA public TO ai_service_user;

-- Revoke all table access by default
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM ai_service_user;

-- Grant read-only access STRICTLY to the ai_face_candidates view
GRANT SELECT ON ai_face_candidates TO ai_service_user;
