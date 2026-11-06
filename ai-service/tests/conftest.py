import pytest

from app.core.model_registry import model_registry


@pytest.fixture
def install_models():
    """Install fake models into the shared registry for the duration of one test."""

    def _install(analyzer, session):
        model_registry.install(session, analyzer)

    yield _install
    model_registry.install(None, None)
