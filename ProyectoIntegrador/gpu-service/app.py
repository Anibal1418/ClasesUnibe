"""Microservicio HTTP de normalización CUDA/OpenMP para Cloud Run con GPU."""

from __future__ import annotations

import ctypes
import json
import logging
import math
import os
import tempfile
import time
import uuid
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field, field_validator

try:
    from google.cloud import storage
except ImportError:  # Permite pruebas locales sin la biblioteca de Google Cloud.
    storage = None

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(message)s",
)
LOGGER = logging.getLogger("gpu-normalizer")

MAX_INPUT_VALUES = int(os.getenv("MAX_INPUT_VALUES", "2000000"))
LIBRARY_PATH = Path(
    os.getenv("NORMALIZER_LIBRARY", "/opt/normalizer/libnormalizer.so")
)
DATA_BUCKET = os.getenv("DATA_BUCKET", "").strip()
LOCAL_DATA_DIR = Path(os.getenv("LOCAL_DATA_DIR", "/tmp/hybrid-bigdata"))


class NormalizeRequest(BaseModel):
    """Contrato recibido por el endpoint de normalización."""

    values: list[float] = Field(min_length=1)
    engine: Literal["cpu", "gpu", "both"] = "both"
    persist: bool = True
    job_id: str | None = None

    @field_validator("values")
    @classmethod
    def validate_values(cls, values: list[float]) -> list[float]:
        if len(values) > MAX_INPUT_VALUES:
            raise ValueError(
                f"El arreglo excede el máximo de {MAX_INPUT_VALUES:,} valores"
            )
        if any(not math.isfinite(value) for value in values):
            raise ValueError("Todos los valores deben ser numéricos y finitos")
        return values


class NativeNormalizer:
    """Adaptador ctypes para la biblioteca C++/CUDA."""

    def __init__(self, library_path: Path) -> None:
        if not library_path.exists():
            raise RuntimeError(f"No existe la biblioteca nativa: {library_path}")

        self.library = ctypes.CDLL(str(library_path))
        pointer = ctypes.POINTER(ctypes.c_double)
        common_args = [
            pointer,
            ctypes.c_size_t,
            pointer,
            pointer,
            pointer,
            pointer,
        ]

        self.library.normalize_cpu_omp.argtypes = common_args
        self.library.normalize_cpu_omp.restype = ctypes.c_int
        self.library.normalize_gpu_cuda.argtypes = common_args
        self.library.normalize_gpu_cuda.restype = ctypes.c_int
        self.library.cuda_device_available.argtypes = []
        self.library.cuda_device_available.restype = ctypes.c_int

    def gpu_available(self) -> bool:
        return self.library.cuda_device_available() == 1

    def normalize(self, values: list[float], engine: str) -> dict:
        size = len(values)
        array_type = ctypes.c_double * size
        input_array = array_type(*values)
        output_array = array_type()
        mean = ctypes.c_double()
        standard_deviation = ctypes.c_double()
        elapsed_ms = ctypes.c_double()

        function = (
            self.library.normalize_gpu_cuda
            if engine == "gpu"
            else self.library.normalize_cpu_omp
        )
        code = function(
            input_array,
            size,
            output_array,
            ctypes.byref(mean),
            ctypes.byref(standard_deviation),
            ctypes.byref(elapsed_ms),
        )

        if code != 0:
            raise RuntimeError(f"Backend {engine} terminó con código {code}")

        return {
            "values": list(output_array),
            "mean": mean.value,
            "standard_deviation": standard_deviation.value,
            "elapsed_ms": elapsed_ms.value,
        }


NORMALIZER = NativeNormalizer(LIBRARY_PATH)
app = FastAPI(
    title="Hybrid Big Data GPU Normalizer",
    version="1.0.0",
    description="Normalización z-score con CUDA y OpenMP.",
)


def persist_jsonl(
    job_id: str,
    original: list[float],
    normalized: list[float],
) -> str:
    """Escribe un JSONL local o lo carga a Cloud Storage."""

    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        suffix=".jsonl",
        delete=False,
    ) as temporary:
        temp_path = Path(temporary.name)
        for index, (source, result) in enumerate(zip(original, normalized)):
            temporary.write(
                json.dumps(
                    {
                        "index": index,
                        "original": source,
                        "normalized": result,
                    },
                    separators=(",", ":"),
                )
                + "\n"
            )

    object_name = f"preprocessed/{job_id}/values.jsonl"

    try:
        if DATA_BUCKET:
            if storage is None:
                raise RuntimeError("google-cloud-storage no está instalado")
            client = storage.Client()
            bucket = client.bucket(DATA_BUCKET)
            blob = bucket.blob(object_name)
            blob.upload_from_filename(temp_path, content_type="application/x-ndjson")
            return f"gs://{DATA_BUCKET}/{object_name}"

        destination = LOCAL_DATA_DIR / object_name
        destination.parent.mkdir(parents=True, exist_ok=True)
        temp_path.replace(destination)
        return str(destination)
    finally:
        if temp_path.exists():
            temp_path.unlink(missing_ok=True)


@app.get("/health")
def health() -> dict:
    return {
        "status": "ok",
        "gpu_available": NORMALIZER.gpu_available(),
        "library": str(LIBRARY_PATH),
    }


@app.post("/normalize")
def normalize(request: NormalizeRequest) -> dict:
    job_id = request.job_id or uuid.uuid4().hex
    wall_start = time.perf_counter()

    LOGGER.info(
        "job=%s stage=gpu-preprocess event=start count=%d engine=%s",
        job_id,
        len(request.values),
        request.engine,
    )

    cpu_result = None
    gpu_result = None

    try:
        if request.engine in {"cpu", "both"}:
            cpu_result = NORMALIZER.normalize(request.values, "cpu")

        if request.engine in {"gpu", "both"}:
            if not NORMALIZER.gpu_available():
                if request.engine == "gpu":
                    raise HTTPException(
                        status_code=503,
                        detail="No se detectó una GPU CUDA en esta instancia",
                    )
            else:
                gpu_result = NORMALIZER.normalize(request.values, "gpu")

        selected = gpu_result or cpu_result
        if selected is None:
            raise RuntimeError("No se ejecutó ningún backend")

        maximum_difference = None
        if cpu_result and gpu_result:
            maximum_difference = max(
                abs(cpu_value - gpu_value)
                for cpu_value, gpu_value in zip(
                    cpu_result["values"],
                    gpu_result["values"],
                )
            )

        input_uri = None
        if request.persist:
            input_uri = persist_jsonl(
                job_id,
                request.values,
                selected["values"],
            )

        speedup = None
        if cpu_result and gpu_result and gpu_result["elapsed_ms"] > 0:
            speedup = cpu_result["elapsed_ms"] / gpu_result["elapsed_ms"]

        wall_ms = (time.perf_counter() - wall_start) * 1000.0
        response = {
            "job_id": job_id,
            "status": "preprocessed",
            "count": len(request.values),
            "engine_used": "gpu" if gpu_result else "cpu",
            "statistics": {
                "mean": selected["mean"],
                "standard_deviation": selected["standard_deviation"],
            },
            "benchmark": {
                "cpu_omp_ms": cpu_result["elapsed_ms"] if cpu_result else None,
                "gpu_cuda_ms": gpu_result["elapsed_ms"] if gpu_result else None,
                "speedup_gpu_vs_cpu": speedup,
                "maximum_backend_difference": maximum_difference,
                "service_wall_ms": wall_ms,
            },
            "input_uri": input_uri,
            "preview": selected["values"][:10],
        }

        LOGGER.info(
            "job=%s stage=gpu-preprocess event=success input_uri=%s wall_ms=%.3f",
            job_id,
            input_uri,
            wall_ms,
        )
        return response
    except HTTPException:
        raise
    except Exception as exception:
        LOGGER.exception("job=%s stage=gpu-preprocess event=failed", job_id)
        raise HTTPException(status_code=500, detail=str(exception)) from exception
