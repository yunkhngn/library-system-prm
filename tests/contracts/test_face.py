import uuid
import pytest
import httpx


def _create_minimal_mp4() -> bytes:
    # 32-byte minimal valid MP4 header with 'ftyp' box
    header = bytearray(32)
    header[0:4] = (20).to_bytes(4, "big")
    header[4:8] = b"ftyp"
    header[8:12] = b"isom"
    return bytes(header)


def _login(http_client: httpx.Client, identifier: str, password: str) -> str:
    res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": identifier, "password": password},
    )
    assert res.status_code == 200, f"Login failed for {identifier}: {res.text}"
    return res.json()["accessToken"]


def _get_or_create_kiosk_token(http_client: httpx.Client, seed_password: str) -> tuple[str, str]:
    """Registers/retrieves a kiosk and logs in to get Kiosk Bearer token."""
    admin_token = _login(http_client, "AD001", seed_password)
    kiosk_code = f"K_CONTRACT_{uuid.uuid4().hex[:6].upper()}"

    res = http_client.post(
        "/api/v1/kiosks",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={
            "code": kiosk_code,
            "name": "Contract Test Kiosk",
            "mode": "AUTO",
            "cameraStatus": "ONLINE",
            "appVersion": "1.0.0",
        },
    )
    assert res.status_code == 201, f"Failed creating kiosk: {res.text}"
    data = res.json()
    kiosk_id = data["kiosk"]["id"]
    credential = data["credential"]

    # Exchange credential for kiosk token
    login_res = http_client.post(
        "/api/v1/kiosks/token",
        json={"kioskId": kiosk_id, "credential": credential},
    )
    assert login_res.status_code == 200, f"Failed logging in kiosk: {login_res.text}"
    return kiosk_code, login_res.json()["accessToken"]


def test_face_challenge_unauthenticated(http_client: httpx.Client):
    res = http_client.post("/api/v1/access/face-challenge")
    assert res.status_code == 401


def test_face_challenge_rbac(http_client: httpx.Client, seed_password: str):
    stu_token = _login(http_client, "SV001", seed_password)
    res = http_client.post(
        "/api/v1/access/face-challenge",
        headers={"Authorization": f"Bearer {stu_token}"},
    )
    assert res.status_code == 403


def test_face_challenge_lifecycle(http_client: httpx.Client, seed_password: str):
    _, kiosk_token = _get_or_create_kiosk_token(http_client, seed_password)
    res = http_client.post(
        "/api/v1/access/face-challenge",
        headers={"Authorization": f"Bearer {kiosk_token}"},
    )
    assert res.status_code == 201
    assert "Location" in res.headers
    data = res.json()
    assert "challengeId" in data
    assert "expiresAt" in data
    assert len(data["instructions"]) == 2
    assert data["instructions"][0]["action"] == "BLINK"
    assert data["instructions"][0]["order"] == 1
    assert data["instructions"][1]["action"] in ("TURN_LEFT", "TURN_RIGHT")
    assert data["instructions"][1]["order"] == 2
    assert "captureRules" in data
    assert data["captureRules"]["minImages"] == 3


def test_face_access_validation(http_client: httpx.Client, seed_password: str):
    _, kiosk_token = _get_or_create_kiosk_token(http_client, seed_password)
    headers = {"Authorization": f"Bearer {kiosk_token}"}

    # 1. Missing Idempotency-Key -> 400
    mp4_bytes = _create_minimal_mp4()
    res_no_idem = http_client.post(
        "/api/v1/access/face",
        headers=headers,
        data={"challengeId": str(uuid.uuid4())},
        files={"clip": ("clip.mp4", mp4_bytes, "video/mp4")},
    )
    assert res_no_idem.status_code == 400
    assert res_no_idem.json().get("code") == "IDEMPOTENCY_KEY_REQUIRED"

    # 2. Invalid challengeId -> 422
    files = {"clip": ("clip.mp4", mp4_bytes, "video/mp4")}
    data = {"challengeId": str(uuid.uuid4())}
    idem = str(uuid.uuid4())

    res_inv_chal = http_client.post(
        "/api/v1/access/face",
        headers={**headers, "Idempotency-Key": idem},
        data=data,
        files=files,
    )
    assert res_inv_chal.status_code == 422
    assert res_inv_chal.json().get("code") == "CHALLENGE_INVALID"

    # 3. Invalid video container format (not MP4) -> 422 VIDEO_INVALID
    # Create a fresh challenge
    chal_res = http_client.post("/api/v1/access/face-challenge", headers=headers)
    assert chal_res.status_code == 201
    chal_id = chal_res.json()["challengeId"]

    fake_video = b"NOT_A_VALID_MP4_HEADER_TEXT_BYTES"
    res_inv_video = http_client.post(
        "/api/v1/access/face",
        headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
        data={"challengeId": chal_id},
        files={"clip": ("clip.mp4", fake_video, "video/mp4")},
    )
    assert res_inv_video.status_code == 422
    assert res_inv_video.json().get("code") == "VIDEO_INVALID"


def test_face_access_simulated_and_idempotency(http_client: httpx.Client, seed_password: str):
    _, kiosk_token = _get_or_create_kiosk_token(http_client, seed_password)
    headers = {"Authorization": f"Bearer {kiosk_token}"}

    chal_res = http_client.post("/api/v1/access/face-challenge", headers=headers)
    assert chal_res.status_code == 201
    chal_id = chal_res.json()["challengeId"]

    mp4_bytes = _create_minimal_mp4()
    idem_key = str(uuid.uuid4())

    # In dev environment, AI_MOCK_MODE=true is active -> simulated result rejected with 503
    res = http_client.post(
        "/api/v1/access/face",
        headers={**headers, "Idempotency-Key": idem_key},
        data={"challengeId": chal_id},
        files={"clip": ("clip.mp4", mp4_bytes, "video/mp4")},
    )
    assert res.status_code in (503, 422, 200)
    if res.status_code == 503:
        assert res.json().get("code") == "SIMULATED_RESULT_REJECTED"
        assert res.json().get("fallbackRecommended") is True

    # Replay with same Idempotency-Key -> returns cached response
    replay_res = http_client.post(
        "/api/v1/access/face",
        headers={**headers, "Idempotency-Key": idem_key},
        data={"challengeId": chal_id},
        files={"clip": ("clip.mp4", mp4_bytes, "video/mp4")},
    )
    assert replay_res.status_code == res.status_code

    # Calling with a NEW Idempotency-Key after challenge was consumed -> 409 CHALLENGE_ALREADY_USED
    new_idem = str(uuid.uuid4())
    res_used = http_client.post(
        "/api/v1/access/face",
        headers={**headers, "Idempotency-Key": new_idem},
        data={"challengeId": chal_id},
        files={"clip": ("clip.mp4", mp4_bytes, "video/mp4")},
    )
    assert res_used.status_code == 409
    assert res_used.json().get("code") == "CHALLENGE_ALREADY_USED"
