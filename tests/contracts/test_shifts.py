import uuid
import datetime
import httpx
import pytest

VN_TZ = datetime.timezone(datetime.timedelta(hours=7))


def test_shift_crud_and_overnight(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]
    headers = {"Authorization": f"Bearer {admin_token}"}

    now = datetime.datetime.now(VN_TZ).replace(microsecond=0)
    starts = (now + datetime.timedelta(days=2)).replace(hour=8, minute=0, second=0)
    ends = starts + datetime.timedelta(hours=8)

    # 1. Create shift
    shift_name = f"Morning Shift {uuid.uuid4().hex[:6]}"
    create_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={
            "name": shift_name,
            "startsAt": starts.isoformat(),
            "endsAt": ends.isoformat(),
        },
    )
    assert create_res.status_code == 201
    assert "Location" in create_res.headers
    shift = create_res.json()
    assert shift["name"] == shift_name
    assert shift["status"] == "ACTIVE"
    assert shift["version"] == 0
    assert shift["assignmentCount"] == 0
    assert shift["createdBy"]["code"] == "AD001"
    shift_id = shift["id"]

    # 2. Create overnight shift: 18:00 to 00:30 next day
    overnight_start = (now + datetime.timedelta(days=3)).replace(hour=18, minute=0, second=0)
    overnight_end = (now + datetime.timedelta(days=4)).replace(hour=0, minute=30, second=0)
    overnight_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={
            "name": "Overnight Shift",
            "startsAt": overnight_start.isoformat(),
            "endsAt": overnight_end.isoformat(),
        },
    )
    assert overnight_res.status_code == 201
    assert overnight_res.json()["name"] == "Overnight Shift"

    # 3. Reject endsAt <= startsAt
    bad_time_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={
            "name": "Bad Shift",
            "startsAt": ends.isoformat(),
            "endsAt": starts.isoformat(),
        },
    )
    assert bad_time_res.status_code == 422
    assert bad_time_res.json()["code"] == "INVALID_TIME_RANGE"

    # 4. Reject duration > 24 hours
    too_long_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={
            "name": "Too Long Shift",
            "startsAt": starts.isoformat(),
            "endsAt": (starts + datetime.timedelta(hours=25)).isoformat(),
        },
    )
    assert too_long_res.status_code == 422
    assert too_long_res.json()["code"] == "INVALID_TIME_RANGE"

    # 5. List shifts with q filter
    list_res = http_client.get(
        "/api/v1/shifts",
        headers=headers,
        params={"q": shift_name},
    )
    assert list_res.status_code == 200
    items = list_res.json()["items"]
    assert len(items) == 1
    assert items[0]["id"] == shift_id

    # 6. Read shift detail as Admin
    get_res = http_client.get(f"/api/v1/shifts/{shift_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["name"] == shift_name

    # 7. Patch shift name
    patch_res = http_client.patch(
        f"/api/v1/shifts/{shift_id}",
        headers=headers,
        json={
            "version": 0,
            "name": shift_name + " Updated",
        },
    )
    assert patch_res.status_code == 200
    assert patch_res.json()["name"] == shift_name + " Updated"
    assert patch_res.json()["version"] == 1


def test_shift_assignments_and_overlap_exclusion(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]
    headers = {"Authorization": f"Bearer {admin_token}"}

    # Get librarian LIB001 user ID
    users_res = http_client.get("/api/v1/users", headers=headers, params={"q": "LIB001"})
    assert users_res.status_code == 200
    lib_users = [u for u in users_res.json()["items"] if u["code"] == "LIB001"]
    assert len(lib_users) > 0
    lib1_id = lib_users[0]["id"]

    now = datetime.datetime.now(VN_TZ).replace(microsecond=0)
    day_offset = 10 + (int(uuid.uuid4().hex[:4], 16) % 100)
    s1_start = (now + datetime.timedelta(days=day_offset)).replace(hour=8, minute=0, second=0)
    s1_end = s1_start + datetime.timedelta(hours=6)  # 08:00 - 14:00

    shift1_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={"name": "Shift Slot 1", "startsAt": s1_start.isoformat(), "endsAt": s1_end.isoformat()},
    )
    assert shift1_res.status_code == 201
    shift1_id = shift1_res.json()["id"]

    # 1. Assign LIB001
    assign_res = http_client.post(
        f"/api/v1/shifts/{shift1_id}/assignments",
        headers=headers,
        json={"version": 0, "staffIds": [lib1_id]},
    )
    assert assign_res.status_code == 201
    assert "Location" in assign_res.headers
    batch = assign_res.json()
    assert batch["shift"]["version"] == 1
    assert batch["shift"]["assignmentCount"] == 1
    assert len(batch["assignments"]) == 1
    assert batch["assignments"][0]["staff"]["code"] == "LIB001"
    assignment1_id = batch["assignments"][0]["id"]

    # 2. Existing active assignment returns 409 ASSIGNMENT_EXISTS
    dup_assign_res = http_client.post(
        f"/api/v1/shifts/{shift1_id}/assignments",
        headers=headers,
        json={"version": 1, "staffIds": [lib1_id]},
    )
    assert dup_assign_res.status_code == 409
    assert dup_assign_res.json()["code"] == "ASSIGNMENT_EXISTS"

    # 3. Create overlapping Shift 2: 12:00 - 18:00 (overlaps with 08:00 - 14:00)
    s2_start = (now + datetime.timedelta(days=day_offset)).replace(hour=12, minute=0, second=0)
    s2_end = s2_start + datetime.timedelta(hours=6)
    shift2_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={"name": "Shift Slot 2 Overlap", "startsAt": s2_start.isoformat(), "endsAt": s2_end.isoformat()},
    )
    assert shift2_res.status_code == 201
    shift2_id = shift2_res.json()["id"]

    # Attempt assigning LIB001 to overlapping shift -> 409 SHIFT_OVERLAP
    overlap_res = http_client.post(
        f"/api/v1/shifts/{shift2_id}/assignments",
        headers=headers,
        json={"version": 0, "staffIds": [lib1_id]},
    )
    assert overlap_res.status_code == 409
    assert overlap_res.json()["code"] == "SHIFT_OVERLAP"

    # 4. Create Adjacent Shift 3: 14:00 - 20:00 (adjacent to 08:00 - 14:00)
    s3_start = s1_end  # exactly 14:00
    s3_end = s3_start + datetime.timedelta(hours=6)
    shift3_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={"name": "Shift Slot 3 Adjacent", "startsAt": s3_start.isoformat(), "endsAt": s3_end.isoformat()},
    )
    assert shift3_res.status_code == 201
    shift3_id = shift3_res.json()["id"]

    # Adjacent shift assignment MUST SUCCEED (half-open intervals do not overlap)
    adj_res = http_client.post(
        f"/api/v1/shifts/{shift3_id}/assignments",
        headers=headers,
        json={"version": 0, "staffIds": [lib1_id]},
    )
    assert adj_res.status_code == 201
    assert adj_res.json()["shift"]["assignmentCount"] == 1


def test_shift_atomic_replacement_and_cancel_cascade(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    assert admin_res.status_code == 200
    admin_token = admin_res.json()["accessToken"]
    headers = {"Authorization": f"Bearer {admin_token}"}

    users_res = http_client.get("/api/v1/users", headers=headers, params={"role": "LIBRARIAN"})
    assert users_res.status_code == 200
    librarians = users_res.json()["items"]
    lib1_id = librarians[0]["id"]

    if len(librarians) < 2:
        create_user_res = http_client.post(
            "/api/v1/users",
            headers=headers,
            json={
                "code": "LIB002",
                "email": "lib002@example.test",
                "fullName": "Librarian Two",
                "role": "LIBRARIAN",
                "password": seed_password,
            },
        )
        assert create_user_res.status_code == 201
        lib2_id = create_user_res.json()["id"]
    else:
        lib2_id = librarians[1]["id"]

    now = datetime.datetime.now(VN_TZ).replace(microsecond=0)
    day_offset = 150 + (int(uuid.uuid4().hex[:4], 16) % 100)
    starts = (now + datetime.timedelta(days=day_offset)).replace(hour=8, minute=0, second=0)
    ends = starts + datetime.timedelta(hours=8)

    shift_res = http_client.post(
        "/api/v1/shifts",
        headers=headers,
        json={"name": "Shift Atomic Test", "startsAt": starts.isoformat(), "endsAt": ends.isoformat()},
    )
    shift_id = shift_res.json()["id"]

    assign_res = http_client.post(
        f"/api/v1/shifts/{shift_id}/assignments",
        headers=headers,
        json={"version": 0, "staffIds": [lib1_id]},
    )
    assert assign_res.status_code == 201
    assignment_id = assign_res.json()["assignments"][0]["id"]

    # 1. Atomic replacement with LIB2
    replace_res = http_client.patch(
        f"/api/v1/shifts/{shift_id}/assignments/{assignment_id}",
        headers=headers,
        json={"version": 0, "staffId": lib2_id},
    )
    assert replace_res.status_code == 200
    batch = replace_res.json()
    assert batch["assignments"][0]["staff"]["id"] == lib2_id
    assert batch["assignments"][0]["version"] == 1

    # 2. Cancel shift cascades to assignments, preserves history
    cancel_res = http_client.post(
        f"/api/v1/shifts/{shift_id}/cancel",
        headers=headers,
        json={"version": 2, "reason": "Operational maintenance"},
    )
    assert cancel_res.status_code == 200
    assert cancel_res.json()["status"] == "CANCELLED"
    assert cancel_res.json()["cancellationReason"] == "Operational maintenance"

    # Assignments list shows CANCELLED
    assignments_res = http_client.get(
        f"/api/v1/shifts/{shift_id}/assignments",
        headers=headers,
        params={"status": "CANCELLED"},
    )
    assert assignments_res.status_code == 200
    assert len(assignments_res.json()["items"]) == 1
    assert assignments_res.json()["items"][0]["status"] == "CANCELLED"


def test_librarian_schedule_and_ownership(http_client: httpx.Client, seed_password: str):
    admin_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "AD001", "password": seed_password},
    )
    admin_token = admin_res.json()["accessToken"]

    lib_res = http_client.post(
        "/api/v1/auth/login",
        json={"identifier": "LIB001", "password": seed_password},
    )
    assert lib_res.status_code == 200
    lib_token = lib_res.json()["accessToken"]

    # Get LIB001 id
    me_res = http_client.get("/api/v1/me", headers={"Authorization": f"Bearer {lib_token}"})
    assert me_res.status_code == 200
    lib1_id = me_res.json()["id"]

    now = datetime.datetime.now(VN_TZ).replace(microsecond=0)
    day_offset = 300 + (int(uuid.uuid4().hex[:4], 16) % 100)
    starts = (now + datetime.timedelta(days=day_offset)).replace(hour=8, minute=0, second=0)
    ends = starts + datetime.timedelta(hours=6)

    # Admin creates shift without assignment
    s_res = http_client.post(
        "/api/v1/shifts",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"name": "Ownership Shift", "startsAt": starts.isoformat(), "endsAt": ends.isoformat()},
    )
    shift_id = s_res.json()["id"]

    # Librarian CANNOT read unassigned shift detail -> 404
    lib_get_res = http_client.get(
        f"/api/v1/shifts/{shift_id}",
        headers={"Authorization": f"Bearer {lib_token}"},
    )
    assert lib_get_res.status_code == 404

    # Admin assigns librarian
    assign_res = http_client.post(
        f"/api/v1/shifts/{shift_id}/assignments",
        headers={"Authorization": f"Bearer {admin_token}"},
        json={"version": 0, "staffIds": [lib1_id]},
    )
    assert assign_res.status_code == 201, f"Assignment failed: {assign_res.text}"

    # Now librarian CAN read shift detail
    lib_get_ok = http_client.get(
        f"/api/v1/shifts/{shift_id}",
        headers={"Authorization": f"Bearer {lib_token}"},
    )
    assert lib_get_ok.status_code == 200
    assert lib_get_ok.json()["id"] == shift_id

    # Librarian checks /api/v1/me/shifts
    my_shifts_res = http_client.get(
        "/api/v1/me/shifts",
        headers={"Authorization": f"Bearer {lib_token}"},
        params={
            "from": (starts - datetime.timedelta(days=1)).isoformat(),
            "to": (ends + datetime.timedelta(days=1)).isoformat(),
        },
    )
    assert my_shifts_res.status_code == 200
    my_shifts = my_shifts_res.json()
    assert len(my_shifts["items"]) >= 1
    found = any(item["shift"]["id"] == shift_id for item in my_shifts["items"])
    assert found, "Librarian must see assigned shift in /me/shifts"
