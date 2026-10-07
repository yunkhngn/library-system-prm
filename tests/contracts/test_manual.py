import uuid
import httpx
import pytest


def test_visitor_crud_and_no_name_merging(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]

    unique_name = f"Guest Test {uuid.uuid4().hex[:6]}"
    res1 = http_client.post(
        "/api/v1/visitors",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"fullName": unique_name},
    )
    assert res1.status_code == 201
    assert "Location" in res1.headers
    v1 = res1.json()
    assert v1["referenceCode"].startswith("GUEST-")
    assert v1["fullName"] == unique_name

    # Create second visitor with identical name
    res2 = http_client.post(
        "/api/v1/visitors",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"fullName": unique_name},
    )
    assert res2.status_code == 201
    v2 = res2.json()
    assert v2["referenceCode"].startswith("GUEST-")
    assert v2["referenceCode"] != v1["referenceCode"], "Distinct visitors with same name must have different codes"
    assert v2["id"] != v1["id"]

    # Search visitors
    list_res = http_client.get(
        "/api/v1/visitors",
        headers={"Authorization": f"Bearer {admin_token}"},
        params={"q": unique_name},
    )
    assert list_res.status_code == 200
    items = list_res.json()["items"]
    assert len(items) >= 2

    # Get single visitor
    get_res = http_client.get(
        f"/api/v1/visitors/{v1['id']}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert get_res.status_code == 200
    assert get_res.json()["referenceCode"] == v1["referenceCode"]


def test_manual_access_visitor_checkin_checkout(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]

    # Create visitor
    v_res = http_client.post(
        "/api/v1/visitors",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"fullName": f"Manual Visitor {uuid.uuid4().hex[:6]}"},
    )
    assert v_res.status_code == 201
    visitor_id = v_res.json()["id"]

    # Check in visitor manually
    key1 = str(uuid.uuid4())
    in_res1 = http_client.post(
        "/api/v1/access/manual",
        headers={"Authorization": f"Bearer {admin_token}", "Idempotency-Key": key1},
        json={"visitorId": visitor_id, "action": "CHECK_IN", "reason": "Guest visit entry"},
    )
    assert in_res1.status_code == 200
    in_data = in_res1.json()
    assert in_data["action"] == "CHECK_IN"
    assert in_data["subject"]["kind"] == "VISITOR"
    assert in_data["method"] == "MANUAL"

    # Replay with same key -> identical result
    in_res2 = http_client.post(
        "/api/v1/access/manual",
        headers={"Authorization": f"Bearer {admin_token}", "Idempotency-Key": key1},
        json={"visitorId": visitor_id, "action": "CHECK_IN", "reason": "Guest visit entry"},
    )
    assert in_res2.status_code == 200
    assert in_res1.json() == in_res2.json()

    # Second check-in with new key -> 409 ALREADY_INSIDE
    dup_res = http_client.post(
        "/api/v1/access/manual",
        headers={"Authorization": f"Bearer {admin_token}", "Idempotency-Key": str(uuid.uuid4())},
        json={"visitorId": visitor_id, "action": "CHECK_IN", "reason": "Another checkin"},
    )
    assert dup_res.status_code == 409
    assert dup_res.json()["code"] == "ALREADY_INSIDE"

    # Check out visitor
    key2 = str(uuid.uuid4())
    out_res = http_client.post(
        "/api/v1/access/manual",
        headers={"Authorization": f"Bearer {admin_token}", "Idempotency-Key": key2},
        json={"visitorId": visitor_id, "action": "CHECK_OUT", "reason": "Guest departure"},
    )
    assert out_res.status_code == 200
    assert out_res.json()["action"] == "CHECK_OUT"

    # Repeat check-out -> 409 NOT_INSIDE
    dup_out = http_client.post(
        "/api/v1/access/manual",
        headers={"Authorization": f"Bearer {admin_token}", "Idempotency-Key": str(uuid.uuid4())},
        json={"visitorId": visitor_id, "action": "CHECK_OUT", "reason": "Repeat checkout"},
    )
    assert dup_out.status_code == 409
    assert dup_out.json()["code"] == "NOT_INSIDE"


def test_occupancy_endpoints_role_and_privacy(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_res.json()["accessToken"]

    stu_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    stu_token = stu_res.json()["accessToken"]

    # Student cannot access /occupancy
    forbidden_res = http_client.get(
        "/api/v1/occupancy",
        headers={"Authorization": f"Bearer {stu_token}"},
    )
    assert forbidden_res.status_code == 403

    # Admin can access /occupancy
    occ_res = http_client.get(
        "/api/v1/occupancy",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert occ_res.status_code == 200
    occ = occ_res.json()
    assert "count" in occ
    assert "maxCapacity" in occ
    assert "revision" in occ

    # People list omits email
    people_res = http_client.get(
        "/api/v1/occupancy/people",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert people_res.status_code == 200
    people_body = people_res.text
    assert "email" not in people_body, "Occupancy endpoints must not leak user emails"


def test_student_presence_and_history(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_res.json()["accessToken"]

    stu_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "SV001", "password": seed_password},
    )
    stu_token = stu_res.json()["accessToken"]

    # Student status
    status_res = http_client.get(
        "/api/v1/me/access-status",
        headers={"Authorization": f"Bearer {stu_token}"},
    )
    assert status_res.status_code == 200
    status_data = status_res.json()
    assert "isInside" in status_data
    assert "asOf" in status_data

    # Student personal history
    hist_res = http_client.get(
        "/api/v1/me/access-history",
        headers={"Authorization": f"Bearer {stu_token}"},
    )
    assert hist_res.status_code == 200
    assert "items" in hist_res.json()

    # Admin access-history validation
    val_err = http_client.get(
        "/api/v1/access-history",
        headers={"Authorization": f"Bearer {admin_token}"},
        params={"userId": str(uuid.uuid4()), "visitorId": str(uuid.uuid4())},
    )
    assert val_err.status_code == 422
    assert val_err.json()["code"] == "VALIDATION_ERROR"

    # Time range validation
    range_err = http_client.get(
        "/api/v1/access-history",
        headers={"Authorization": f"Bearer {admin_token}"},
        params={"from": "2026-10-07T10:00:00Z", "to": "2026-10-06T10:00:00Z"},
    )
    assert range_err.status_code == 422
    assert range_err.json()["code"] == "INVALID_TIME_RANGE"
