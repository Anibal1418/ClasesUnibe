import importlib
import math
import os
from pathlib import Path

from fastapi.testclient import TestClient


def load_app():
    project_dir = Path(__file__).resolve().parents[1]
    os.environ["NORMALIZER_LIBRARY"] = str(
        project_dir / "build" / "libnormalizer.so"
    )
    os.environ["LOCAL_DATA_DIR"] = str(project_dir / "build" / "test-data")
    module = importlib.import_module("app")
    return module.app


def test_cpu_normalization_has_zero_mean_and_unit_std():
    client = TestClient(load_app())
    response = client.post(
        "/normalize",
        json={"values": [1, 2, 3, 4, 5], "engine": "cpu", "persist": False},
    )
    assert response.status_code == 200
    payload = response.json()
    preview = payload["preview"]
    mean = sum(preview) / len(preview)
    variance = sum((value - mean) ** 2 for value in preview) / len(preview)
    assert abs(mean) < 1e-12
    assert math.isclose(math.sqrt(variance), 1.0, rel_tol=1e-10)


def test_rejects_non_finite_values():
    client = TestClient(load_app())
    response = client.post(
        "/normalize",
        json={"values": [1.0, "NaN"], "engine": "cpu"},
    )
    assert response.status_code == 422
