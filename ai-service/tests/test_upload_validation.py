import io
import json
import uuid
import pytest
from PIL import Image
from httpx import AsyncClient, ASGITransport
from app.main import app
from app.core.settings import settings

VALID_KEY = settings.service_api_key
HEADERS = {"X-Service-Key": VALID_KEY}


@pytest.fixture(autouse=True)
def _mock_mode_by_default(monkeypatch):
    """These tests exercise upload validation, which is independent of the models.

    Mock mode keeps them runnable without model files; tests that need real mode switch it off."""
    monkeypatch.setenv("AI_MOCK_MODE", "true")


def create_image_bytes(width: int = 100, height: int = 100, fmt: str = "JPEG") -> bytes:
    buf = io.BytesIO()
    img = Image.new("RGB", (width, height), color="blue")
    img.save(buf, format=fmt)
    return buf.getvalue()


def create_mp4_bytes(size_bytes: int = 1024) -> bytes:
    # Minimal MP4 box header: size (4 bytes), 'ftyp' (4 bytes), major_brand 'isom' (4 bytes), minor_version (4 bytes)
    header = b"\x00\x00\x00\x20ftypisom\x00\x00\x02\x00isomiso2mp41"
    padding = b"\x00" * max(0, size_bytes - len(header))
    return header + padding


# ==============================================================================
# Enrollment (/api/v1/embeddings) Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_embeddings_service_key_validation():
    """Missing or invalid X-Service-Key returns 401 INVALID_SERVICE_KEY."""
    img_data = create_image_bytes()
    files = [("images", ("test1.jpg", img_data, "image/jpeg")) for _ in range(3)]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Missing header
        res1 = await ac.post("/api/v1/embeddings", files=files)
        assert res1.status_code == 401
        assert res1.json()["code"] == "INVALID_SERVICE_KEY"

        # Invalid header
        res2 = await ac.post("/api/v1/embeddings", files=files, headers={"X-Service-Key": "bad-key"})
        assert res2.status_code == 401
        assert res2.json()["code"] == "INVALID_SERVICE_KEY"


@pytest.mark.asyncio
async def test_embeddings_count_limits():
    """Enrollment strictly requires 3 to 5 images."""
    img_data = create_image_bytes()

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        # Too few: 2 images
        files_2 = [("images", (f"img_{i}.jpg", img_data, "image/jpeg")) for i in range(2)]
        res_few = await ac.post("/api/v1/embeddings", files=files_2, headers=HEADERS)
        assert res_few.status_code == 422
        assert res_few.json()["code"] == "IMAGE_INVALID"

        # Too many: 6 images
        files_6 = [("images", (f"img_{i}.jpg", img_data, "image/jpeg")) for i in range(6)]
        res_many = await ac.post("/api/v1/embeddings", files=files_6, headers=HEADERS)
        assert res_many.status_code == 422
        assert res_many.json()["code"] == "IMAGE_INVALID"


@pytest.mark.asyncio
async def test_embeddings_success_mock(monkeypatch):
    """Mock mode produces 512-d normalized embeddings with simulated=True."""
    monkeypatch.setenv("AI_MOCK_MODE", "true")
    img_data = create_image_bytes()
    files = [("images", (f"img_{i}.jpg", img_data, "image/jpeg")) for i in range(3)]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/embeddings", files=files, headers=HEADERS)

    assert res.status_code == 200
    data = res.json()
    assert data["dimension"] == 512
    assert data["simulated"] is True
    assert len(data["embeddings"]) == 3
    for emb in data["embeddings"]:
        assert len(emb) == 512
        # Verify finite float values
        assert all(isinstance(x, float) for x in emb)


@pytest.mark.asyncio
async def test_embeddings_fake_image():
    """Fake text file masquerading as image is rejected with 422 IMAGE_INVALID."""
    fake_data = b"This is a text string posing as image binary"
    valid_data = create_image_bytes()
    files = [
        ("images", ("test1.jpg", valid_data, "image/jpeg")),
        ("images", ("test2.jpg", valid_data, "image/jpeg")),
        ("images", ("fake.jpg", fake_data, "image/jpeg")),
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/embeddings", files=files, headers=HEADERS)

    assert res.status_code == 422
    assert res.json()["code"] == "IMAGE_INVALID"


@pytest.mark.asyncio
async def test_embeddings_unsupported_format():
    """Formats other than JPEG and PNG (e.g. GIF) are rejected."""
    gif_buf = io.BytesIO()
    Image.new("RGB", (50, 50), color="red").save(gif_buf, format="GIF")
    gif_data = gif_buf.getvalue()

    valid_data = create_image_bytes()
    files = [
        ("images", ("test1.jpg", valid_data, "image/jpeg")),
        ("images", ("test2.jpg", valid_data, "image/jpeg")),
        ("images", ("anim.gif", gif_data, "image/gif")),
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/embeddings", files=files, headers=HEADERS)

    assert res.status_code == 422
    assert res.json()["code"] == "IMAGE_INVALID"


@pytest.mark.asyncio
async def test_embeddings_oversized_image():
    """Image larger than 5 MB is rejected with 413 PAYLOAD_TOO_LARGE."""
    oversized_data = b"\xFF\xD8\xFF" + (b"\x00" * (6 * 1024 * 1024))
    valid_data = create_image_bytes()
    files = [
        ("images", ("test1.jpg", valid_data, "image/jpeg")),
        ("images", ("test2.jpg", valid_data, "image/jpeg")),
        ("images", ("large.jpg", oversized_data, "image/jpeg")),
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/embeddings", files=files, headers=HEADERS)

    assert res.status_code == 413
    assert res.json()["code"] == "PAYLOAD_TOO_LARGE"


@pytest.mark.asyncio
async def test_embeddings_image_bomb():
    """Image exceeding 16 megapixels is rejected with 422 IMAGE_INVALID."""
    # 4500 x 4000 = 18,000,000 pixels (> 16 MP limit)
    bomb_data = create_image_bytes(width=4500, height=4000, fmt="JPEG")
    valid_data = create_image_bytes()
    files = [
        ("images", ("test1.jpg", valid_data, "image/jpeg")),
        ("images", ("test2.jpg", valid_data, "image/jpeg")),
        ("images", ("bomb.jpg", bomb_data, "image/jpeg")),
    ]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/embeddings", files=files, headers=HEADERS)

    assert res.status_code == 422
    assert res.json()["code"] == "IMAGE_INVALID"


@pytest.mark.asyncio
async def test_embeddings_unready_model(monkeypatch):
    """In real mode with unready models, returns 503 MODEL_NOT_READY."""
    monkeypatch.setenv("AI_MOCK_MODE", "false")
    monkeypatch.setenv("AI_MODELS_READY", "false")
    img_data = create_image_bytes()
    files = [("images", (f"img_{i}.jpg", img_data, "image/jpeg")) for i in range(3)]

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/embeddings", files=files, headers=HEADERS)

    assert res.status_code == 503
    assert res.json()["code"] == "MODEL_NOT_READY"


# ==============================================================================
# Recognition (/api/v1/recognize) Tests
# ==============================================================================

@pytest.mark.asyncio
async def test_recognize_service_key_validation():
    """Missing or invalid X-Service-Key on /recognize returns 401 INVALID_SERVICE_KEY."""
    clip_data = create_mp4_bytes()
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": str(uuid.uuid4()),
        "challengeInstructions": json.dumps([
            {"action": "BLINK", "order": 1},
            {"action": "TURN_LEFT", "order": 2},
        ]),
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": 0.35,
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data)
        assert res.status_code == 401
        assert res.json()["code"] == "INVALID_SERVICE_KEY"


@pytest.mark.asyncio
async def test_recognize_invalid_challenge_id():
    """Invalid UUID for challengeId returns 422 CHALLENGE_INVALID."""
    clip_data = create_mp4_bytes()
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": "not-a-valid-uuid",
        "challengeInstructions": json.dumps([
            {"action": "BLINK", "order": 1},
            {"action": "TURN_LEFT", "order": 2},
        ]),
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": 0.35,
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data, headers=HEADERS)
    assert res.status_code == 422
    assert res.json()["code"] == "CHALLENGE_INVALID"


@pytest.mark.asyncio
async def test_recognize_invalid_instructions_json():
    """Malformed JSON in challengeInstructions returns 400 INVALID_JSON."""
    clip_data = create_mp4_bytes()
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": str(uuid.uuid4()),
        "challengeInstructions": "{invalid_json: true",
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": 0.35,
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data, headers=HEADERS)
    assert res.status_code == 400
    assert res.json()["code"] == "INVALID_JSON"


@pytest.mark.asyncio
async def test_recognize_invalid_instructions_count():
    """Challenge instructions must have exactly 2 actions; otherwise 422 CHALLENGE_INVALID."""
    clip_data = create_mp4_bytes()
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": str(uuid.uuid4()),
        "challengeInstructions": json.dumps([
            {"action": "BLINK", "order": 1}
        ]),
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": 0.35,
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data, headers=HEADERS)
    assert res.status_code == 422
    assert res.json()["code"] == "CHALLENGE_INVALID"


@pytest.mark.asyncio
async def test_recognize_invalid_video_container():
    """Non-MP4 video container (no ftyp box) returns 422 VIDEO_INVALID."""
    clip_data = b"This is just random text content not a video"
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": str(uuid.uuid4()),
        "challengeInstructions": json.dumps([
            {"action": "BLINK", "order": 1},
            {"action": "TURN_LEFT", "order": 2},
        ]),
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": 0.35,
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data, headers=HEADERS)
    assert res.status_code == 422
    assert res.json()["code"] == "VIDEO_INVALID"


@pytest.mark.asyncio
async def test_recognize_threshold_out_of_range():
    """Out-of-range thresholds return 422 VALIDATION_ERROR."""
    clip_data = create_mp4_bytes()
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": str(uuid.uuid4()),
        "challengeInstructions": json.dumps([
            {"action": "BLINK", "order": 1},
            {"action": "TURN_LEFT", "order": 2},
        ]),
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": -0.5,  # Invalid: negative
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data, headers=HEADERS)
    assert res.status_code == 422
    assert res.json()["code"] == "VALIDATION_ERROR"


@pytest.mark.asyncio
async def test_recognize_success_mock(monkeypatch):
    """Mock recognize returns simulated=True, outcome=NO_MATCH, matched=False."""
    monkeypatch.setenv("AI_MOCK_MODE", "true")
    clip_data = create_mp4_bytes()
    files = {"clip": ("test.mp4", clip_data, "video/mp4")}
    data = {
        "challengeId": str(uuid.uuid4()),
        "challengeInstructions": json.dumps([
            {"action": "BLINK", "order": 1},
            {"action": "TURN_LEFT", "order": 2},
        ]),
        "modelVersion": "arcface-512-v1",
        "maxCosineDistance": 0.35,
        "minDistanceGap": 0.15,
        "livenessMinScore": 0.90,
    }

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as ac:
        res = await ac.post("/api/v1/recognize", files=files, data=data, headers=HEADERS)
    assert res.status_code == 200
    res_data = res.json()
    assert res_data["simulated"] is True
    assert res_data["matched"] is False
    assert res_data["userId"] is None
    assert res_data["outcome"] == "NO_MATCH"
    assert res_data["livenessPassed"] is True
