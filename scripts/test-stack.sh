#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

BACKEND_TEST_PORT="${BACKEND_TEST_PORT:-8089}"
AI_SERVICE_TEST_PORT="${AI_SERVICE_TEST_PORT:-8009}"
POSTGRES_TEST_PORT="${POSTGRES_TEST_PORT:-5439}"

export BACKEND_TEST_PORT
export AI_SERVICE_TEST_PORT
export POSTGRES_TEST_PORT

cleanup() {
    echo "Tearing down test environment..."
    docker compose -f compose.test.yml -p library-test down -v --remove-orphans || true
}
trap cleanup EXIT

echo "=== 1. Starting isolated test stack ==="
docker compose -f compose.test.yml -p library-test up -d --build

echo "Waiting for test stack health..."
max_retries=30
counter=0
until curl -sf "http://localhost:${BACKEND_TEST_PORT}/actuator/health" > /dev/null && \
      curl -sf "http://localhost:${AI_SERVICE_TEST_PORT}/api/v1/health" > /dev/null; do
    sleep 2
    counter=$((counter + 1))
    if [ "${counter}" -ge "${max_retries}" ]; then
        echo "Error: Test stack failed to become healthy within timeout"
        docker compose -f compose.test.yml -p library-test logs --tail 50
        exit 1
    fi
done

echo "Test stack is healthy!"

echo "=== 2. Running AI Service Unit Tests ==="
PYTHONPATH=ai-service pytest ai-service/tests/ -v

echo "=== 3. Running HTTP Contract & OpenAPI Schema Tests ==="
API_BASE_URL="http://localhost:${BACKEND_TEST_PORT}" \
AI_BASE_URL="http://localhost:${AI_SERVICE_TEST_PORT}" \
DEV_SEED_PASSWORD="dev_secret_password_123" \
pytest tests/contracts/ -v

echo "=== 4. Running Backend Unit and Testcontainers Integration Tests ==="
./backend/mvnw test -f backend/pom.xml -Dtest=DatabaseMigrationIT,AuthIT,QrIT,AccessConcurrencyIT,OccupancyIT,WebSocketIT,ShiftIT,ConfigIT,AutoCheckoutIT,EnrollmentIT,FaceAccessIT,HealthAndDocsTest

echo "=========================================================="
echo " ALL TESTS PASSED: Full stack verification complete!"
echo "=========================================================="
