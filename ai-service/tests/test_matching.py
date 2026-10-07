import pytest
import numpy as np
from app.repositories.candidates import Candidate
from app.services.matching_service import match_face_embedding


def make_normalized_vector(seed: int) -> list[float]:
    rng = np.random.RandomState(seed)
    v = rng.randn(512).astype(np.float32)
    v /= np.linalg.norm(v)
    return v.tolist()


def test_match_single_person_success():
    vec_user_a = make_normalized_vector(10)
    # Probe is slightly perturbed version of user A (cosine similarity ~ 0.95, distance ~ 0.05)
    noise = np.random.RandomState(99).randn(512).astype(np.float32)
    noise /= np.linalg.norm(noise)
    probe_arr = 0.95 * np.array(vec_user_a) + 0.05 * noise
    probe_arr /= np.linalg.norm(probe_arr)
    probe = probe_arr.tolist()

    vec_user_b = make_normalized_vector(20)

    cand_a = Candidate("user-a-uuid", "consent-a", 1, vec_user_a, "arcface", "v1")
    cand_b = Candidate("user-b-uuid", "consent-b", 1, vec_user_b, "arcface", "v1")

    res = match_face_embedding(probe, [cand_a, cand_b], max_cosine_distance=0.35, min_distance_gap=0.15)
    assert res.matched is True
    assert res.userId == "user-a-uuid"
    assert res.outcome == "MATCHED"
    assert res.cosineDistance < 0.20
    assert res.distanceGap > 0.30


def test_match_grouped_by_person_multi_images():
    base_a = np.array(make_normalized_vector(100))
    cand_a1 = Candidate("user-a", "consent-a", 1, base_a.tolist(), "arcface", "v1")
    
    n2 = np.random.randn(512).astype(np.float32)
    n2 /= np.linalg.norm(n2)
    cand_a2 = Candidate("user-a", "consent-a", 1, (0.98 * base_a + 0.02 * n2).tolist(), "arcface", "v1")

    n3 = np.random.randn(512).astype(np.float32)
    n3 /= np.linalg.norm(n3)
    cand_a3 = Candidate("user-a", "consent-a", 1, (0.97 * base_a + 0.03 * n3).tolist(), "arcface", "v1")

    base_b = np.array(make_normalized_vector(200))
    cand_b = Candidate("user-b", "consent-b", 1, base_b.tolist(), "arcface", "v1")

    probe = base_a.tolist()
    res = match_face_embedding(probe, [cand_a1, cand_a2, cand_a3, cand_b], max_cosine_distance=0.35, min_distance_gap=0.15)
    assert res.matched is True
    assert res.userId == "user-a"


def test_reject_ambiguous_ties():
    """When two different users have distances closer than min_distance_gap, match is rejected."""
    base_vec = np.array(make_normalized_vector(300))
    probe = base_vec.tolist()
    
    n_a = np.random.RandomState(1).randn(512).astype(np.float32)
    n_a /= np.linalg.norm(n_a)
    vec_a = (0.90 * base_vec + 0.10 * n_a).tolist()

    n_b = np.random.RandomState(2).randn(512).astype(np.float32)
    n_b /= np.linalg.norm(n_b)
    vec_b = (0.89 * base_vec + 0.11 * n_b).tolist()

    cand_a = Candidate("user-a", "consent-a", 1, vec_a, "arcface", "v1")
    cand_b = Candidate("user-b", "consent-b", 1, vec_b, "arcface", "v1")

    res = match_face_embedding(probe, [cand_a, cand_b], max_cosine_distance=0.50, min_distance_gap=0.20)
    assert res.matched is False
    assert res.outcome == "NO_MATCH"
    assert res.userId is None


def test_liveness_failure_prevents_match():
    vec = make_normalized_vector(400)
    cand = Candidate("user-a", "consent-a", 1, vec, "arcface", "v1")

    res = match_face_embedding(vec, [cand], liveness_passed=False, liveness_score=0.2)
    assert res.matched is False
    assert res.outcome == "LIVENESS_FAILED"
    assert res.userId is None
    assert res.livenessPassed is False


def test_empty_candidates_returns_no_match():
    probe = make_normalized_vector(500)
    res = match_face_embedding(probe, [])
    assert res.matched is False
    assert res.outcome == "NO_MATCH"
    assert res.userId is None
