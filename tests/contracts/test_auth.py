import httpx
import pytest


def test_login_invalid_credentials(http_client: httpx.Client):
    response = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "NONEXISTENT_USER", "password": "WrongPassword123!"},
    )
    assert response.status_code == 401
    data = response.json()
    assert data.get("code") == "INVALID_CREDENTIALS"
    assert "traceId" in data


def test_login_seeded_accounts(http_client: httpx.Client, seed_password: str):
    # Admin login
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_data = admin_res.json()
    assert admin_data.get("tokenType") == "Bearer"
    assert "accessToken" in admin_data
    assert "refreshToken" in admin_data
    assert admin_data["user"]["role"] == "ADMIN"

    # Librarian login
    lib_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "LIB001", "password": seed_password},
    )
    assert lib_res.status_code == 200
    assert lib_res.json()["user"]["role"] == "LIBRARIAN"

    # Student login
    stu_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    assert stu_res.status_code == 200
    assert stu_res.json()["user"]["role"] == "STUDENT"


def test_login_normalization(http_client: httpx.Client, seed_password: str):
    # Lowercase code
    res_code = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "ad001", "password": seed_password},
    )
    assert res_code.status_code == 200
    assert res_code.json()["user"]["code"] == "AD001"

    # Uppercase email
    res_email = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "ADMIN@EXAMPLE.TEST", "password": seed_password},
    )
    assert res_email.status_code == 200
    assert res_email.json()["user"]["email"] == "admin@example.test"


def test_refresh_rotation_and_replay(http_client: httpx.Client, seed_password: str):
    # Login
    login_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    assert login_res.status_code == 200
    token1 = login_res.json()["refreshToken"]

    # Refresh
    refresh_res = http_client.post(
        "/api/v1/auth/refresh",
        json={"refreshToken": token1},
    )
    assert refresh_res.status_code == 200
    token2 = refresh_res.json()["refreshToken"]
    assert token1 != token2

    # Replay token1 -> must fail with TOKEN_REVOKED
    replay_res = http_client.post(
        "/api/v1/auth/refresh",
        json={"refreshToken": token1},
    )
    assert replay_res.status_code == 401
    assert replay_res.json().get("code") == "TOKEN_REVOKED"

    # token2 should now also be revoked due to replay detection
    replay2_res = http_client.post(
        "/api/v1/auth/refresh",
        json={"refreshToken": token2},
    )
    assert replay2_res.status_code == 401
    assert replay2_res.json().get("code") == "TOKEN_REVOKED"


def test_logout_and_session_invalidation(http_client: httpx.Client, seed_password: str):
    # Login
    login_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "LIB001", "password": seed_password},
    )
    assert login_res.status_code == 200
    access_token = login_res.json()["accessToken"]
    refresh_token = login_res.json()["refreshToken"]

    # Profile works
    me_res = http_client.get(
        "/api/v1/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert me_res.status_code == 200

    # Logout
    logout_res = http_client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"refreshToken": refresh_token},
    )
    assert logout_res.status_code == 204

    # Repeated logout is idempotent
    logout_repeat = http_client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"refreshToken": refresh_token},
    )
    assert logout_repeat.status_code == 204

    # Access token is revoked
    me_revoked = http_client.get(
        "/api/v1/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert me_revoked.status_code == 401
    assert me_revoked.json().get("code") == "TOKEN_REVOKED"


def test_role_based_access(http_client: httpx.Client, seed_password: str):
    # Student login
    stu_login = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    stu_token = stu_login.json()["accessToken"]

    # Student cannot access /users
    users_stu = http_client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {stu_token}"},
    )
    assert users_stu.status_code == 403
    assert users_stu.json().get("code") == "FORBIDDEN"

    # Admin login
    admin_login = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_login.json()["accessToken"]

    # Admin can list users
    users_admin = http_client.get(
        "/api/v1/users",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert users_admin.status_code == 200
    data = users_admin.json()
    assert "items" in data
    assert data["totalElements"] >= 3
