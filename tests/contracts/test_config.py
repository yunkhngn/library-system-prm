import datetime
import httpx
import pytest

VN_TZ = datetime.timezone(datetime.timedelta(hours=7))


def test_system_config_crud_and_validation(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    lib_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "LIB001", "password": seed_password},
    )
    assert lib_res.status_code == 200
    lib_token = lib_res.json()["accessToken"]
    lib_headers = {"Authorization": f"Bearer {lib_token}"}

    # 1. Read config as Admin and Librarian
    cfg_res = http_client.get("/api/v1/system-config", headers=admin_headers)
    assert cfg_res.status_code == 200
    cfg = cfg_res.json()
    assert cfg["timezone"] == "Asia/Ho_Chi_Minh"
    assert "version" in cfg
    version = cfg["version"]

    lib_cfg_res = http_client.get("/api/v1/system-config", headers=lib_headers)
    assert lib_cfg_res.status_code == 200

    # 2. Librarian cannot update config -> 403
    lib_patch = http_client.patch(
        "/api/v1/system-config",
        headers=lib_headers,
        json={"version": version, "maxCapacity": 300},
    )
    assert lib_patch.status_code == 403

    # 3. Admin updates config successfully
    patch_res = http_client.patch(
        "/api/v1/system-config",
        headers=admin_headers,
        json={
            "version": version,
            "maxCapacity": 280,
            "nearCapacityRatio": 0.85,
            "scanCooldownSeconds": 15,
        },
    )
    assert patch_res.status_code == 200
    updated = patch_res.json()
    assert updated["maxCapacity"] == 280
    assert updated["nearCapacityRatio"] == 0.85
    assert updated["scanCooldownSeconds"] == 15
    assert updated["version"] == version + 1
    new_version = updated["version"]

    # 4. Stale version -> 409 VERSION_CONFLICT
    stale_res = http_client.patch(
        "/api/v1/system-config",
        headers=admin_headers,
        json={"version": version, "maxCapacity": 300},
    )
    assert stale_res.status_code == 409
    assert stale_res.json()["code"] == "VERSION_CONFLICT"

    # 5. Invalid capacity -> 422 VALIDATION_ERROR
    bad_cap_res = http_client.patch(
        "/api/v1/system-config",
        headers=admin_headers,
        json={"version": new_version, "maxCapacity": -10},
    )
    assert bad_cap_res.status_code == 422
    assert bad_cap_res.json()["code"] == "VALIDATION_ERROR"


def test_analytics_endpoints(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]
    headers = {"Authorization": f"Bearer {admin_token}"}

    now = datetime.datetime.now(VN_TZ).replace(microsecond=0)
    from_dt = now - datetime.timedelta(days=7)
    to_dt = now

    # 1. Access analytics with DAY bucket
    access_res = http_client.get(
        "/api/v1/analytics/access",
        headers=headers,
        params={"from": from_dt.isoformat(), "to": to_dt.isoformat(), "bucket": "DAY"},
    )
    assert access_res.status_code == 200
    access = access_res.json()
    assert access["timezone"] == "Asia/Ho_Chi_Minh"
    assert access["bucket"] == "DAY"
    assert "totalCheckIns" in access
    assert "totalCheckOuts" in access
    assert len(access["buckets"]) >= 7

    # 2. Access analytics with HOUR bucket
    hour_from = now - datetime.timedelta(days=1)
    hour_res = http_client.get(
        "/api/v1/analytics/access",
        headers=headers,
        params={"from": hour_from.isoformat(), "to": to_dt.isoformat(), "bucket": "HOUR"},
    )
    assert hour_res.status_code == 200
    assert hour_res.json()["bucket"] == "HOUR"
    assert len(hour_res.json()["buckets"]) >= 24

    # 3. Invalid time range (to <= from) -> 422
    bad_range = http_client.get(
        "/api/v1/analytics/access",
        headers=headers,
        params={"from": to_dt.isoformat(), "to": from_dt.isoformat()},
    )
    assert bad_range.status_code == 422
    assert bad_range.json()["code"] == "INVALID_TIME_RANGE"

    # 4. Recognition analytics
    recog_res = http_client.get(
        "/api/v1/analytics/recognition",
        headers=headers,
        params={"from": from_dt.isoformat(), "to": to_dt.isoformat()},
    )
    assert recog_res.status_code == 200
    recog = recog_res.json()
    assert "totalAttempts" in recog
    assert "matched" in recog
    assert "failed" in recog
    assert "outcomes" in recog
