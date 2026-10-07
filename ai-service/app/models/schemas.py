from typing import List, Optional, Literal
from pydantic import BaseModel, Field, field_validator


class FieldError(BaseModel):
    field: str
    message: str


class ApiError(BaseModel):
    code: str
    message: str
    fieldErrors: List[FieldError] = Field(default_factory=list)
    traceId: str
    timestamp: str
    fallbackRecommended: bool = False


class AiHealth(BaseModel):
    status: Literal["ok"] = "ok"
    service: Literal["ai-service"] = "ai-service"


class AiReadiness(BaseModel):
    status: Literal["READY", "NOT_READY"]
    ready: Optional[bool] = None
    mode: Literal["MOCK", "REAL"]
    modelId: Optional[str] = None
    modelVersion: Optional[str] = None
    livenessModelVersion: Optional[str] = None
    simulated: bool
    reason: Optional[str] = None

    def model_post_init(self, __context):
        if self.ready is None:
            self.ready = (self.status == "READY")


class ChallengeInstruction(BaseModel):
    action: Literal["BLINK", "TURN_LEFT", "TURN_RIGHT"]
    order: int = Field(..., ge=1, le=2)


class InternalEmbeddingResult(BaseModel):
    embeddings: List[List[float]]
    dimension: int = 512
    modelId: str
    modelVersion: str
    simulated: bool


class InternalRecognitionResult(BaseModel):
    matched: bool
    userId: Optional[str] = None
    biometricVersion: Optional[int] = None
    consentId: Optional[str] = None
    cosineDistance: Optional[float] = None
    distanceGap: Optional[float] = None
    livenessPassed: bool
    livenessScore: float
    modelId: str
    modelVersion: str
    livenessModelVersion: str
    simulated: bool
    outcome: Literal["MATCHED", "NO_MATCH", "LIVENESS_FAILED"]
