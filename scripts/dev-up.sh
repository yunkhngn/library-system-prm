#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if [ ! -f .env ]; then
    echo "Creating .env from .env.example..."
    cp .env.example .env
fi

echo "Starting library dev stack (PostgreSQL, Backend, AI service)..."
docker compose -f compose.dev.yml up -d --build postgres backend ai-service

# The AI service reads enrolled faces through a read-only DB role. The ai_face_candidates view it
# needs is created by the backend's Flyway migrations, so wait for the backend before provisioning.
echo "Waiting for the backend (database migrations)..."
for _ in $(seq 1 90); do
    if curl -fsS "http://localhost:${BACKEND_PORT:-8080}/actuator/health" >/dev/null 2>&1; then
        break
    fi
    sleep 2
done
echo "Provisioning read-only AI database role..."
docker compose -f compose.dev.yml exec -T postgres sh -c \
    'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"' < scripts/db-bootstrap.sql

echo "Services started. Actuator health: http://localhost:${BACKEND_PORT:-8080}/actuator/health"
echo "Swagger UI: http://localhost:${BACKEND_PORT:-8080}/swagger-ui/index.html"
