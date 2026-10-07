import httpx
import pytest


def test_student_issue_qr(http_client: httpx.Client, seed_password: str):
    # Student login
    stu_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    assert stu_res.status_code == 200
    token = stu_res.json()["accessToken"]

    # Issue QR
    qr_res = http_client.post(
        "/api/v1/me/qr",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert qr_res.status_code == 200
    data = qr_res.json()
    assert "token" in data
    assert "expiresAt" in data
    assert data["refreshAfterSeconds"] == 25


def test_admin_cannot_issue_qr(http_client: httpx.Client, seed_password: str):
    # Admin login
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    token = admin_res.json()["accessToken"]

    # Attempt to issue QR
    qr_res = http_client.post(
        "/api/v1/me/qr",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert qr_res.status_code == 403
    assert qr_res.json().get("code") == "FORBIDDEN"


def test_kiosk_lifecycle_and_auth(http_client: httpx.Client, seed_password: str):
    # Admin login
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]

    # Create Kiosk
    kiosk_code = "K-DEV-TEST"
    create_res = http_client.post(
        "/api/v1/kiosks",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"code": kiosk_code, "name": "Dev Test Kiosk", "mode": "AUTO"},
    )
    if create_res.status_code == 409:
        # If already exists from earlier test run, rotate credential
        kiosks_list = http_client.get(
            "/api/v1/kiosks",
            headers={"Authorization": f"Bearer {admin_token}"},
            params={"q": kiosk_code},
        ).json()["items"]
        target_kiosk = [k for k in kiosks_list if k["code"] == kiosk_code][0]
        kiosk_id = target_kiosk["id"]
        rotate_res = http_client.post(
            f"/api/v1/kiosks/{kiosk_id}/rotate-credential",
            headers={"Authorization": f"Bearer {admin_token}"},
            json={"version": target_kiosk["version"]},
        )
        assert rotate_res.status_code == 200
        credential = rotate_res.json()["credential"]
    else:
        assert create_res.status_code == 201
        data = create_res.json()
        kiosk_id = data["kiosk"]["id"]
        credential = data["credential"]

    # Kiosk login with credential
    kiosk_token_res = http_client.post(
        "/api/v1/kiosks/token",
        json={"kioskId": kiosk_id, "credential": credential},
    )
    assert kiosk_token_res.status_code == 200
    kiosk_jwt = kiosk_token_res.json()["accessToken"]

    # Kiosk heartbeat
    hb_res = http_client.post(
        "/api/v1/kiosks/heartbeat",
        headers={"Authorization": f"Bearer {kiosk_jwt}"},
        json={"appVersion": "1.0.0", "cameraStatus": "OK"},
    )
    assert hb_res.status_code == 200
    hb_data = hb_res.json()
    assert hb_data["kiosk"]["isOnline"] is True
    assert hb_data["heartbeatIntervalSeconds"] == 30

    # Kiosk runtime config
    cfg_res = http_client.get(
        "/api/v1/kiosks/me/config",
        headers={"Authorization": f"Bearer {kiosk_jwt}"},
    )
    assert cfg_res.status_code == 200
    cfg_data = cfg_res.json()
    assert cfg_data["kioskId"] == kiosk_id
    assert cfg_data["qrTtlSeconds"] == 30
    assert cfg_data["faceEnabled"] is False
