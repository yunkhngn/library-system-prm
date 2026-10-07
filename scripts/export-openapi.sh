#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${ROOT_DIR}"

if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

PORT="${BACKEND_PORT:-8082}"
TARGET_FILE="${ROOT_DIR}/docs/api/openapi.json"

echo "Exporting OpenAPI JSON from http://localhost:${PORT}/v3/api-docs ..."

if ! curl -sf "http://localhost:${PORT}/v3/api-docs" -o "${TARGET_FILE}.raw"; then
    echo "Error: Backend is not reachable at http://localhost:${PORT}/v3/api-docs"
    echo "Ensure the backend is running (e.g. ./scripts/dev-up.sh)"
    rm -f "${TARGET_FILE}.raw"
    exit 1
fi

python3 -m json.tool "${TARGET_FILE}.raw" > "${TARGET_FILE}"
rm -f "${TARGET_FILE}.raw"

SIZE=$(wc -c < "${TARGET_FILE}" | tr -d ' ')
echo "Successfully exported runtime OpenAPI specification to ${TARGET_FILE} (${SIZE} bytes)"
