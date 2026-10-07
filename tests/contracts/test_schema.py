import httpx
import pytest


def test_runtime_openapi_schema_completeness(http_client: httpx.Client):
    """
    Validates that the runtime OpenAPI document:
    1. Conforms to OpenAPI 3.0.x specification.
    2. Declares JWT Bearer authentication scheme.
    3. Contains all critical endpoints across Auth, Kiosks, Access, Shifts, Biometrics, Config, Visitors, and Analytics.
    4. Declares standard API schemas and error structures.
    """
    res = http_client.get("/v3/api-docs")
    assert res.status_code == 200, f"Failed fetching OpenAPI docs: {res.text}"
    schema = res.json()

    # 1. Version validation
    assert schema.get("openapi", "").startswith("3.0"), f"Expected OpenAPI 3.0.x, got: {schema.get('openapi')}"
    assert "info" in schema
    assert "paths" in schema
    assert "components" in schema

    # 2. Security schemes
    components = schema["components"]
    security_schemes = components.get("securitySchemes", {})
    assert "bearerAuth" in security_schemes, "Missing 'bearerAuth' security scheme"
    bearer_auth = security_schemes["bearerAuth"]
    assert bearer_auth.get("type") == "http"
    assert bearer_auth.get("scheme") == "bearer"
    assert bearer_auth.get("bearerFormat") == "JWT"

    # 3. Path presence
    paths = schema["paths"]
    expected_critical_paths = [
        "/api/v1/auth/login",
        "/api/v1/auth/refresh",
        "/api/v1/auth/logout",
        "/api/v1/users",
        "/api/v1/kiosks",
        "/api/v1/kiosks/token",
        "/api/v1/access/qr",
        "/api/v1/access/face-challenge",
        "/api/v1/access/face",
        "/api/v1/access/manual",
        "/api/v1/access-history",
        "/api/v1/me/qr",
        "/api/v1/face-policy",
        "/api/v1/me/face-consent",
        "/api/v1/me/face-enrollment",
        "/api/v1/shifts",
        "/api/v1/shifts/{shiftId}/assignments",
        "/api/v1/occupancy",
        "/api/v1/system-config",
        "/api/v1/analytics/access",
        "/api/v1/visitors",
    ]

    for p in expected_critical_paths:
        assert p in paths, f"Missing expected endpoint in OpenAPI schema: {p}"

    # 4. Schema definitions
    schemas = components.get("schemas", {})
    expected_schemas = [
        "LoginRequest",
        "TokenPair",
        "UserDto",
        "ApiError",
        "KioskDto",
        "FaceChallenge",
        "FaceConsent",
        "FacePolicy",
        "SystemConfig",
    ]

    for s in expected_schemas:
        assert s in schemas, f"Missing expected schema component in OpenAPI: {s}"
