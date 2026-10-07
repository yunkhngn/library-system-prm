import os
from typing import List, Dict, Any, Optional


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


class CandidateRepository:
    def __init__(self):
        self._mock_candidates: List[Candidate] = []

    def set_mock_candidates(self, candidates: List[Candidate]):
        self._mock_candidates = list(candidates)

    def load_active_candidates(self) -> List[Candidate]:
        """
        Loads active enrolled students from ai_face_candidates read-only view.
        Falls back to in-memory mock candidates when testing without database connection.
        """
        mock_mode = os.getenv("AI_MOCK_MODE", "true").lower() in ("true", "1", "yes")
        db_url = os.getenv("AI_DATABASE_URL") or os.getenv("DATABASE_URL")

        if not db_url or mock_mode:
            return list(self._mock_candidates)

        try:
            import psycopg2
            from psycopg2.extras import RealDictCursor
            conn = psycopg2.connect(db_url)
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    """
                    SELECT user_id, consent_id, biometric_version, embedding, model_id, model_version
                    FROM ai_face_candidates
                    """
                )
                rows = cur.fetchall()
            conn.close()

            candidates = []
            for r in rows:
                raw_emb = r["embedding"]
                if isinstance(raw_emb, str):
                    clean = raw_emb.strip("[]").split(",")
                    emb = [float(x.strip()) for x in clean if x.strip()]
                elif isinstance(raw_emb, (list, tuple)):
                    emb = [float(x) for x in raw_emb]
                else:
                    emb = []

                candidates.append(
                    Candidate(
                        user_id=str(r["user_id"]),
                        consent_id=str(r["consent_id"]),
                        biometric_version=int(r["biometric_version"]),
                        embedding=emb,
                        model_id=str(r["model_id"]),
                        model_version=str(r["model_version"]),
                    )
                )
            return candidates
        except Exception:
            return list(self._mock_candidates)


candidate_repository = CandidateRepository()
