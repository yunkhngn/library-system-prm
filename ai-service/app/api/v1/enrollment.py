from typing import List
from fastapi import APIRouter, Depends, File, UploadFile, status
from fastapi.concurrency import run_in_threadpool
from app.core.security import verify_service_key, AiApiException
from app.core.model_registry import model_registry
from app.core.settings import mock_mode as is_mock_mode, settings
from app.models.schemas import InternalEmbeddingResult
from app.services.image_decoder import validate_and_decode_image

router = APIRouter(prefix="/api/v1", tags=["Enrollment"])


@router.post(
    "/embeddings",
    response_model=InternalEmbeddingResult,
    dependencies=[Depends(verify_service_key)],
    summary="extractEmbeddings",
)
async def extract_embeddings(
    images: List[UploadFile] = File(...),
):
    if not images or len(images) < settings.min_images_count or len(images) > settings.max_images_count:
        raise AiApiException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            code="IMAGE_INVALID",
            message=f"Enrollment requires between {settings.min_images_count} and {settings.max_images_count} images (received {len(images) if images else 0})",
        )

    mock_mode = is_mock_mode()

    if not model_registry.is_ready():
        raise AiApiException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            code="MODEL_NOT_READY",
            message="Face embedding models are not ready for inference",
            fallback_recommended=True,
        )

    total_bytes = 0
    decoded_images = []

    for img_file in images:
        content = await img_file.read()
        total_bytes += len(content)
        if total_bytes > settings.max_total_image_bytes:
            raise AiApiException(
                status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                code="PAYLOAD_TOO_LARGE",
                message=f"Total upload size exceeds {settings.max_total_image_bytes} bytes limit",
            )
        validate_and_decode_image(content, filename=img_file.filename or "image")
        decoded_images.append(content)

    from app.services.embedding_service import extract_face_embeddings
    embeddings = await run_in_threadpool(extract_face_embeddings, decoded_images, mock_mode)

    return InternalEmbeddingResult(
        embeddings=embeddings,
        dimension=512,
        modelId=model_registry.reported_model_id,
        modelVersion=settings.face_model_version,
        simulated=mock_mode,
    )
