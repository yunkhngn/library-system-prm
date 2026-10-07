import os
import pytest
import httpx

BACKEND_BASE_URL = os.environ.get("API_BASE_URL", "http://localhost:8082")
DEV_SEED_PASSWORD = os.environ.get("DEV_SEED_PASSWORD", "dev_secret_password_123")


@pytest.fixture(scope="session")
def base_url():
    return BACKEND_BASE_URL


@pytest.fixture(scope="session")
def seed_password():
    return DEV_SEED_PASSWORD


@pytest.fixture(scope="session")
def http_client():
    with httpx.Client(base_url=BACKEND_BASE_URL, timeout=15) as client:
        yield client
