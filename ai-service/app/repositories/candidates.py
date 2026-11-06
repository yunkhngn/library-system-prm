import logging
import os
from typing import List

from app.core.model_registry import model_registry
from app.core.security import AiApiException
from app.core.settings import mock_mode

logger = logging.getLogger("ai.candidates")


class Candidate:
    def __init__(
        self,
        user_id: str,
        consent_id: str,
        biometric_version: int,
        embedding: List[float],
        model_id: str,
        model_version: str,
    ):
        self.user_id = user_id
        self.consent_id = consent_id
        self.biometric_version = biometric_version
        self.embedding = embedding
        self.model_id = model_id
        self.model_version = model_version


def _parse_embedding(raw) -> List[float]:
    if isinstance(raw, str):
        return [float(x) for x in raw.strip("[]").split(",") if x.strip()]
    if isinstance(raw, (list, tuple)):
        return [float(x) for x in raw]
    return []


class CandidateRepository:
    def __init__(self):
        self._mock_candidates: List[Candidate] = []

    def set_mock_candidates(self, candidates: List[Candidate]):
        self._mock_candidates = list(candidates)

    def load_active_candidates(self) -> List[Candidate]:
        """
        Loads active enrolled students from the read-only ai_face_candidates view.

        In mock mode, in-memory candidates are used. In real mode a missing or failing database is a
        503 DB_UNAVAILABLE: silently returning "nobody is enrolled" would turn an outage into
        misleading NO_MATCH answers.
        """
        if mock_mode():
            return list(self._mock_candidates)

        db_url = os.getenv("AI_DATABASE_URL") or os.getenv("DATABASE_URL")
        if not db_url:
            raise AiApiException(
                status_code=503, code="DB_UNAVAILABLE", message="AI_DATABASE_URL is not configured", fallback_recommended=True
            )

        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor

            conn = psycopg2.connect(db_url, connect_timeout=5)
            try:
                with conn.cursor(cursor_factory=RealDictCursor) as cur:
                    # Only embeddings produced by the model in use: synthetic (mock) rows and rows from
                    # other models are not comparable and must never be matched.
                    cur.execute(
                        """
                        SELECT user_id, consent_id, biometric_version, embedding, model_id, model_version
                        FROM ai_face_candidates
                        WHERE model_id = %s
                        """,
                        (model_registry.model_id,),
                    )
                    rows = cur.fetchall()
            finally:
                conn.close()
        except Exception as exc:  # noqa: BLE001
            logger.error("candidate query failed: %s", exc)
            raise AiApiException(
                status_code=503, code="DB_UNAVAILABLE", message="Enrolled candidates could not be read", fallback_recommended=True
            ) from exc

        return [
            Candidate(
                user_id=str(r["user_id"]),
                consent_id=str(r["consent_id"]),
                biometric_version=int(r["biometric_version"]),
                embedding=_parse_embedding(r["embedding"]),
                model_id=str(r["model_id"]),
                model_version=str(r["model_version"]),
            )
            for r in rows
        ]


candidate_repository = CandidateRepository()


def load_active_candidates() -> List[Candidate]:
    return candidate_repository.load_active_candidates()
