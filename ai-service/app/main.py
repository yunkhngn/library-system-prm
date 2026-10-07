import uuid
from datetime import datetime, timezone
from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.api.v1.enrollment import router as enrollment_router
from app.api.v1.health import router as health_router
from app.api.v1.recognition import router as recognition_router
from app.core.security import AiApiException
from app.models.schemas import ApiError, FieldError

app = FastAPI(
    title="Library AI Recognition Service",
    description="Backend-to-AI internal microservice for face recognition and liveness",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(AiApiException)
async def ai_api_exception_handler(request: Request, exc: AiApiException):
    trace_id = request.headers.get("x-trace-id", str(uuid.uuid4()))
    api_error = exc.to_api_error(trace_id=trace_id)
    return JSONResponse(
        status_code=exc.status_code,
        content=api_error.model_dump(),
    )


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    trace_id = request.headers.get("x-trace-id", str(uuid.uuid4()))
    field_errors = []
    for err in exc.errors():
        field_name = ".".join(str(loc) for loc in err.get("loc", []) if loc != "body")
        field_errors.append(
            FieldError(field=field_name or "body", message=err.get("msg", "Invalid field"))
        )

    now_iso = datetime.now(timezone.utc).astimezone().isoformat()
    api_error = ApiError(
        code="VALIDATION_ERROR",
        message="Request validation failed",
        fieldErrors=field_errors,
        traceId=trace_id,
        timestamp=now_iso,
        fallbackRecommended=False,
    )
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=api_error.model_dump(),
    )


@app.exception_handler(StarletteHTTPException)
async def http_exception_handler(request: Request, exc: StarletteHTTPException):
    trace_id = request.headers.get("x-trace-id", str(uuid.uuid4()))
    now_iso = datetime.now(timezone.utc).astimezone().isoformat()
    
    code = "INVALID_REQUEST"
    if exc.status_code == 404:
        code = "RESOURCE_NOT_FOUND"
    elif exc.status_code == 405:
        code = "INVALID_REQUEST"
    elif exc.status_code == 413:
        code = "PAYLOAD_TOO_LARGE"
    elif exc.status_code == 401:
        code = "INVALID_SERVICE_KEY"

    api_error = ApiError(
        code=code,
        message=str(exc.detail),
        fieldErrors=[],
        traceId=trace_id,
        timestamp=now_iso,
        fallbackRecommended=False,
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=api_error.model_dump(),
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    trace_id = request.headers.get("x-trace-id", str(uuid.uuid4()))
    now_iso = datetime.now(timezone.utc).astimezone().isoformat()
    api_error = ApiError(
        code="INTERNAL_ERROR",
        message=f"An unexpected internal error occurred: {str(exc)}",
        fieldErrors=[],
        traceId=trace_id,
        timestamp=now_iso,
        fallbackRecommended=False,
    )
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content=api_error.model_dump(),
    )


app.include_router(health_router)
app.include_router(enrollment_router)
app.include_router(recognition_router)
