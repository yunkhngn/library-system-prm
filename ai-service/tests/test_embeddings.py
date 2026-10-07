import pytest
import numpy as np
from app.services.embedding_service import extract_face_embeddings
from app.core.security import AiApiException


def test_vector_dimensions_and_normalization():
    img1 = b"image_payload_person_1_a"
    img2 = b"image_payload_person_1_b"
    img3 = b"image_payload_person_1_c"

    embeddings = extract_face_embeddings([img1, img2, img3])
    assert len(embeddings) == 3

    for emb in embeddings:
        assert len(emb) == 512
        arr = np.array(emb, dtype=np.float32)
        assert np.all(np.isfinite(arr))
        assert not np.all(arr == 0)
        norm = np.linalg.norm(arr)
        assert pytest.approx(norm, rel=1e-4) == 1.0


def test_pairwise_consistency_same_identity():
    img1 = b"sample_face_student_001_pose1"
    img2 = b"sample_face_student_001_pose2"
    img3 = b"sample_face_student_001_pose3"

    embeddings = extract_face_embeddings([img1, img2, img3])
    e1, e2, e3 = [np.array(e) for e in embeddings]

    # Verify high pairwise similarity / small cosine distance
    d12 = 1.0 - float(np.dot(e1, e2))
    d13 = 1.0 - float(np.dot(e1, e3))
    d23 = 1.0 - float(np.dot(e2, e3))

    assert d12 < 0.20
    assert d13 < 0.20
    assert d23 < 0.20


def test_invalid_image_count_rejected():
    with pytest.raises(AiApiException) as exc_info1:
        extract_face_embeddings([b"img1", b"img2"])
    assert exc_info1.value.code == "IMAGE_INVALID"

    with pytest.raises(AiApiException) as exc_info2:
        extract_face_embeddings([b"1", b"2", b"3", b"4", b"5", b"6"])
    assert exc_info2.value.code == "IMAGE_INVALID"
