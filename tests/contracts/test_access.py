import uuid
import httpx
import pytest


def get_or_create_kiosk(http_client: httpx.Client, admin_token: str, code: str, mode: str = "AUTO") -> str:
    res = http_client.post(
        "/api/v1/kiosks",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"code": code, "name": f"Kiosk {code}", "mode": mode},
    )
    if res.status_code == 201:
        data = res.json()
        kiosk_id = data["kiosk"]["id"]
        credential = data["credential"]
    else:
        kiosks_list = http_client.get(
            "/api/v1/kiosks",
            headers={"Authorization": f"Bearer {admin_token}"},
            params={"q": code},
        ).json()["items"]
        target = [k for k in kiosks_list if k["code"] == code][0]
        kiosk_id = target["id"]
        rotate_res = http_client.post(
            f"/api/v1/kiosks/{kiosk_id}/rotate-credential",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"version": target["version"]},
        )
        assert rotate_res.status_code == 200
        credential = rotate_res.json()["credential"]

    login_res = http_client.post(
        "/api/v1/kiosks/token",
        json={"kioskId": kiosk_id, "credential": credential},
    )
    assert login_res.status_code == 200
    return login_res.json()["accessToken"]


def test_retry_does_not_toggle(http_client: httpx.Client, seed_password: str):
    # Admin login
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]

    # Student login & issue QR
    stu_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    assert stu_res.status_code == 200
    stu_token = stu_res.json()["accessToken"]

    qr_res = http_client.post(
        "/api/v1/me/qr",
        headers={"Authorization": f"Bearer {stu_token}"},
    )
    assert qr_res.status_code == 200
    qr_token = qr_res.json()["token"]

    kiosk_token = get_or_create_kiosk(http_client, admin_token, "K-ACC-RETRY", "AUTO")
    key = str(uuid.uuid4())

    # First attempt
    res1 = http_client.post(
        "/api/v1/access/qr",
        headers={"Authorization": f"Bearer {kiosk_token}", "Idempotency-Key": key},
        json={"token": qr_token},
    )
    # Could be CHECK_IN (200) or SCAN_TOO_SOON (409) if SV001 was scanned recently in another test
    if res1.status_code == 409 and res1.json().get("code") == "SCAN_TOO_SOON":
        # Wait out the cooldown or retry is still valid to test replay of that error
        pass

    assert res1.status_code in (200, 409)

    # Replay attempt with same key
    res2 = http_client.post(
        "/api/v1/access/qr",
        headers={"Authorization": f"Bearer {kiosk_token}", "Idempotency-Key": key},
        json={"token": qr_token},
    )
    assert res1.status_code == res2.status_code
    assert res1.json() == res2.json()


def test_missing_idempotency_key(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_res.json()["accessToken"]
    kiosk_token = get_or_create_kiosk(http_client, admin_token, "K-ACC-NOKEY", "AUTO")

    res = http_client.post(
        "/api/v1/access/qr",
        headers={"Authorization": f"Bearer {kiosk_token}"},
        json={"token": "dummy-token-12345678901234567890"},
    )
    assert res.status_code == 400
    assert res.json().get("code") == "IDEMPOTENCY_KEY_REQUIRED"


def test_idempotency_conflict_different_payload(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_res.json()["accessToken"]
    kiosk_token = get_or_create_kiosk(http_client, admin_token, "K-ACC-CONFLICT", "AUTO")

    key = str(uuid.uuid4())
    # First request with invalid QR -> 422 QR_INVALID
    res1 = http_client.post(
        "/api/v1/access/qr",
        headers={"Authorization": f"Bearer {kiosk_token}", "Idempotency-Key": key},
        json={"token": "invalid-token-12345678901234567890"},
    )
    assert res1.status_code == 422

    # Second request with different token and same key -> 409 IDEMPOTENCY_CONFLICT
    res2 = http_client.post(
        "/api/v1/access/qr",
        headers={"Authorization": f"Bearer {kiosk_token}", "Idempotency-Key": key},
        json={"token": "different-token-12345678901234567890"},
    )
    assert res2.status_code == 409
    assert res2.json().get("code") == "IDEMPOTENCY_CONFLICT"


def test_access_request_status_recovery_and_isolation(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_res.json()["accessToken"]

    kiosk1_token = get_or_create_kiosk(http_client, admin_token, "K-ACC-ISO-1", "AUTO")
    kiosk2_token = get_or_create_kiosk(http_client, admin_token, "K-ACC-ISO-2", "AUTO")

    key = str(uuid.uuid4())
    res1 = http_client.post(
        "/api/v1/access/qr",
        headers={"Authorization": f"Bearer {kiosk1_token}", "Idempotency-Key": key},
        json={"token": "dummy-token-12345678901234567890"},
    )
    assert res1.status_code == 422

    # Kiosk 1 queries status -> 200 with COMPLETED
    stat_res1 = http_client.get(
        f"/api/v1/access/requests/{key}",
        headers={"Authorization": f"Bearer {kiosk1_token}"},
    )
    assert stat_res1.status_code == 200
    data = stat_res1.json()
    assert data["status"] == "COMPLETED"
    assert data["httpStatus"] == 422
    assert data["error"]["code"] == "QR_INVALID"

    # Kiosk 2 queries Kiosk 1's key -> 404 RESOURCE_NOT_FOUND (principal isolation!)
    stat_res2 = http_client.get(
        f"/api/v1/access/requests/{key}",
        headers={"Authorization": f"Bearer {kiosk2_token}"},
    )
    assert stat_res2.status_code == 404
    assert stat_res2.json().get("code") == "RESOURCE_NOT_FOUND"
