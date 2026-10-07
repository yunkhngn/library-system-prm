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

echo "Services started. Actuator health: http://localhost:${BACKEND_PORT:-8080}/actuator/health"
echo "Swagger UI: http://localhost:${BACKEND_PORT:-8080}/swagger-ui/index.html"
