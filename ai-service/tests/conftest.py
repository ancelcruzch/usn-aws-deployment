import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture
def client():
    """Cliente HTTP contra la app FastAPI, sin levantar un servidor real."""
    return TestClient(main.app)


@pytest.fixture(autouse=True)
def reset_stats():
    """Las estadísticas viven en memoria: se reinician para aislar cada test."""
    for key in main.stats:
        main.stats[key] = 0
    yield
