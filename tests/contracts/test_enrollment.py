import io
import pytest
import httpx
from PIL import Image


def _create_test_image(color: str = "blue", size: tuple[int, int] = (200, 200)) -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", size, color=color)
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _login(http_client: httpx.Client, identifier: str, password: str) -> str:
    res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": identifier, "password": password},
    )
    assert res.status_code == 200, f"Login failed for {identifier}: {res.text}"
    return res.json()["accessToken"]


def test_face_policy_unauthenticated(http_client: httpx.Client):
    res = http_client.get("/api/v1/face-policy")
    assert res.status_code == 401


def test_face_policy_authenticated(http_client: httpx.Client, seed_password: str):
    token = _login(http_client, "SV001", seed_password)
    res = http_client.get(
        "/api/v1/face-policy",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    data = res.json()
    assert data["version"] == "1.0"
    assert "title" in data
    assert "content" in data
    assert "captureRules" in data
    rules = data["captureRules"]
    assert rules["minImages"] == 3
    assert rules["maxImages"] == 5
    assert rules["maxImageBytes"] == 5 * 1024 * 1024
    assert rules["maxTotalImageBytes"] == 25 * 1024 * 1024
    assert rules["maxImagePixels"] == 16000000
    assert "image/jpeg" in rules["imageMimeTypes"]
    assert "image/png" in rules["imageMimeTypes"]


def test_face_consent_rbac_and_validation(http_client: httpx.Client, seed_password: str):
    # Non-student forbidden
    lib_token = _login(http_client, "LIB001", seed_password)
    res = http_client.post(
        "/api/v1/me/face-consent",
        headers={"Authorization": f"Bearer {lib_token}"},
        json={"policyVersion": "1.0", "accepted": True},
    )
    assert res.status_code == 403

    # Student with accepted=false -> 422
    stu_token = _login(http_client, "SV002", seed_password)
    res = http_client.post(
        "/api/v1/me/face-consent",
        headers={"Authorization": f"Bearer {stu_token}"},
        json={"policyVersion": "1.0", "accepted": False},
    )
    assert res.status_code == 422

    # Student with unknown policyVersion -> 409
    res = http_client.post(
        "/api/v1/me/face-consent",
        headers={"Authorization": f"Bearer {stu_token}"},
        json={"policyVersion": "9.9", "accepted": True},
    )
    assert res.status_code == 409


def test_face_consent_lifecycle(http_client: httpx.Client, seed_password: str):
    stu_token = _login(http_client, "SV002", seed_password)
    headers = {"Authorization": f"Bearer {stu_token}"}

    # Grant consent
    res = http_client.post(
        "/api/v1/me/face-consent",
        headers=headers,
        json={"policyVersion": "1.0", "accepted": True},
    )
    assert res.status_code in (200, 201)
    consent = res.json()
    assert consent["policyVersion"] == "1.0"
    assert consent["grantedAt"] is not None
    assert consent["revokedAt"] is None

    # Idempotent re-grant
    res_repeat = http_client.post(
        "/api/v1/me/face-consent",
        headers=headers,
        json={"policyVersion": "1.0", "accepted": True},
    )
    assert res_repeat.status_code == 200
    assert res_repeat.json()["id"] == consent["id"]


def test_face_enrollment_full_lifecycle(http_client: httpx.Client, seed_password: str):
    # Use SV003 for a fresh lifecycle test
    token = _login(http_client, "SV003", seed_password)
    headers = {"Authorization": f"Bearer {token}"}

    # Clean up prior enrollment if any exists
    init_res = http_client.get("/api/v1/me/face-enrollment", headers=headers)
    assert init_res.status_code == 200
    init_data = init_res.json()
    current_version = init_data["version"]

    if init_data["isEnrolled"]:
        del_res = http_client.delete(
            f"/api/v1/me/face-enrollment?version={current_version}",
            headers=headers,
        )
        assert del_res.status_code == 200
        current_version = del_res.json()["version"]

    # Grant consent
    consent_res = http_client.post(
        "/api/v1/me/face-consent",
        headers=headers,
        json={"policyVersion": "1.0", "accepted": True},
    )
    assert consent_res.status_code in (200, 201)

    # Refresh current status
    status_res = http_client.get("/api/v1/me/face-enrollment", headers=headers)
    assert status_res.status_code == 200
    current_version = status_res.json()["version"]

    # 1. Version conflict on enrollment
    img_bytes1 = _create_test_image("red")
    img_bytes2 = _create_test_image("green")
    img_bytes3 = _create_test_image("blue")

    files = [
        ("images", ("face1.jpg", img_bytes1, "image/jpeg")),
        ("images", ("face2.jpg", img_bytes2, "image/jpeg")),
        ("images", ("face3.jpg", img_bytes3, "image/jpeg")),
    ]
    res_conflict = http_client.post(
        f"/api/v1/me/face-enrollment?version={current_version + 99}",
        headers=headers,
        files=files,
    )
    assert res_conflict.status_code == 409
    assert res_conflict.json().get("code") == "VERSION_CONFLICT"

    # 2. Too few images (2 instead of 3-5)
    files_few = [
        ("images", ("face1.jpg", img_bytes1, "image/jpeg")),
        ("images", ("face2.jpg", img_bytes2, "image/jpeg")),
    ]
    res_few = http_client.post(
        f"/api/v1/me/face-enrollment?version={current_version}",
        headers=headers,
        files=files_few,
    )
    assert res_few.status_code in (400, 422)

    # 3. Successful enrollment with 3 images
    files_ok = [
        ("images", ("face1.jpg", img_bytes1, "image/jpeg")),
        ("images", ("face2.jpg", img_bytes2, "image/jpeg")),
        ("images", ("face3.jpg", img_bytes3, "image/jpeg")),
    ]
    res_enroll = http_client.post(
        f"/api/v1/me/face-enrollment?version={current_version}",
        headers=headers,
        files=files_ok,
    )
    assert res_enroll.status_code == 200, f"Enroll failed: {res_enroll.text}"
    enroll_data = res_enroll.json()
    assert enroll_data["isEnrolled"] is True
    assert enroll_data["imageCount"] == 3
    assert enroll_data["modelId"] == "arcface-512-r100"
    assert enroll_data["modelVersion"] == "arcface-512-v1"
    assert enroll_data["enrolledAt"] is not None
    assert enroll_data["version"] == current_version + 1
    new_version = enroll_data["version"]

    # 4. GET status reflects active enrollment
    get_res = http_client.get("/api/v1/me/face-enrollment", headers=headers)
    assert get_res.status_code == 200
    get_data = get_res.json()
    assert get_data["isEnrolled"] is True
    assert get_data["imageCount"] == 3
    assert get_data["version"] == new_version

    # 5. Delete with wrong version -> 409
    del_conflict = http_client.delete(
        f"/api/v1/me/face-enrollment?version={new_version + 10}",
        headers=headers,
    )
    assert del_conflict.status_code == 409
    assert del_conflict.json().get("code") == "VERSION_CONFLICT"

    # 6. Delete with correct version -> 200
    del_ok = http_client.delete(
        f"/api/v1/me/face-enrollment?version={new_version}",
        headers=headers,
    )
    assert del_ok.status_code == 200
    del_data = del_ok.json()
    assert del_data["isEnrolled"] is False
    assert del_data["version"] == new_version + 1
    assert del_data["deletedAt"] is not None
    deleted_version = del_data["version"]

    # 7. GET status reflects deleted enrollment
    after_del_get = http_client.get("/api/v1/me/face-enrollment", headers=headers)
    assert after_del_get.status_code == 200
    after_del_data = after_del_get.json()
    assert after_del_data["isEnrolled"] is False
    assert after_del_data["imageCount"] == 0
    assert after_del_data["version"] == deleted_version
