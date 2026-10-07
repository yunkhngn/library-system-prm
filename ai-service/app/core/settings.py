import os
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    port: int = 8001
    host: str = "0.0.0.0"
    service_api_key: str = "dev-internal-service-key-change-in-prod"
    ai_mock_mode: bool = True
    ai_models_ready: bool = False
    
    face_model_id: str = "arcface-512-r100"
    face_model_version: str = "arcface-512-v1"
    liveness_model_version: str = "anti-spoof-v1"
    
    max_image_size_bytes: int = 5 * 1024 * 1024        # 5 MB per image
    max_total_image_bytes: int = 25 * 1024 * 1024     # 25 MB total
    max_image_megapixels: int = 16 * 1000 * 1000      # 16 MP max
    max_video_size_bytes: int = 10 * 1024 * 1024      # 10 MB per video clip
    
    min_images_count: int = 3
    max_images_count: int = 5
    
    timezone: str = "Asia/Ho_Chi_Minh"

    model_config = SettingsConfigDict(
        env_prefix="AI_",
        env_file=".env",
        extra="ignore"
    )


settings = Settings()
