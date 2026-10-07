import os
import uuid
from datetime import datetime, timezone
from typing import Optional, List
from fastapi import Header, HTTPException, status
from app.core.settings import settings
from app.models.schemas import FieldError, ApiError


class AiApiException(Exception):
    def __init__(
        self,
        status_code: int,
        code: str,
        message: str,
        field_errors: Optional[List[FieldError]] = None,
        fallback_recommended: bool = False,
    ):
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message
        self.field_errors = field_errors or []
        self.fallback_recommended = fallback_recommended

    def to_api_error(self, trace_id: Optional[str] = None) -> ApiError:
        now_iso = datetime.now(timezone.utc).astimezone().isoformat()
        return ApiError(
            code=self.code,
            message=self.message,
            fieldErrors=self.field_errors,
            traceId=trace_id or str(uuid.uuid4()),
            timestamp=now_iso,
            fallbackRecommended=self.fallback_recommended,
        )


async def verify_service_key(
    x_service_key: Optional[str] = Header(None, alias="X-Service-Key"),
) -> str:
    configured_key = os.getenv("AI_SERVICE_KEY", settings.service_api_key)
    if not x_service_key or x_service_key != configured_key:
        raise AiApiException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            code="INVALID_SERVICE_KEY",
            message="Missing or invalid X-Service-Key header",
        )
    return x_service_key
