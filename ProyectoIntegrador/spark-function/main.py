"""Cloud Run Function que envía y consulta batches de Managed Service for Spark."""

from __future__ import annotations

import json
import os
import re
import uuid

import functions_framework
from flask import Request, jsonify
from google.api_core.client_options import ClientOptions
from google.cloud import dataproc_v1

PROJECT_ID = os.getenv("PROJECT_ID", "")
REGION = os.getenv("REGION", "us-central1")
SPARK_SCRIPT_URI = os.getenv("SPARK_SCRIPT_URI", "")
SPARK_RUNTIME_VERSION = os.getenv("SPARK_RUNTIME_VERSION", "2.3")
SPARK_SERVICE_ACCOUNT = os.getenv("SPARK_SERVICE_ACCOUNT", "")


def client() -> dataproc_v1.BatchControllerClient:
    return dataproc_v1.BatchControllerClient(
        client_options=ClientOptions(
            api_endpoint=f"{REGION}-dataproc.googleapis.com:443"
        )
    )


def safe_batch_id(job_id: str) -> str:
    cleaned = re.sub(r"[^a-z0-9-]", "-", job_id.lower()).strip("-")
    cleaned = cleaned[:45] or "hybrid"
    return f"{cleaned}-{uuid.uuid4().hex[:8]}"


def submit(payload: dict) -> tuple[dict, int]:
    required = ["input_uri", "output_uri"]
    missing = [name for name in required if not payload.get(name)]
    if missing:
        return {"error": f"Faltan campos: {', '.join(missing)}"}, 400
    if not PROJECT_ID or not SPARK_SCRIPT_URI:
        return {
            "error": "PROJECT_ID y SPARK_SCRIPT_URI deben configurarse"
        }, 500

    job_id = payload.get("job_id", "hybrid")
    repetitions = max(1, int(payload.get("repetitions", 3)))
    batch_id = safe_batch_id(job_id)

    batch = dataproc_v1.Batch()
    batch.pyspark_batch.main_python_file_uri = SPARK_SCRIPT_URI
    batch.pyspark_batch.args = [
        "--input-uri",
        payload["input_uri"],
        "--output-uri",
        payload["output_uri"],
        "--repetitions",
        str(repetitions),
    ]
    batch.runtime_config.version = SPARK_RUNTIME_VERSION

    if SPARK_SERVICE_ACCOUNT:
        batch.environment_config.execution_config.service_account = (
            SPARK_SERVICE_ACCOUNT
        )

    parent = f"projects/{PROJECT_ID}/locations/{REGION}"
    operation = client().create_batch(
        request=dataproc_v1.CreateBatchRequest(
            parent=parent,
            batch=batch,
            batch_id=batch_id,
        )
    )

    return {
        "status": "submitted",
        "job_id": job_id,
        "batch_id": batch_id,
        "operation_name": operation.operation.name,
        "output_uri": payload["output_uri"],
    }, 202


def status(payload: dict) -> tuple[dict, int]:
    batch_id = payload.get("batch_id")
    if not batch_id:
        return {"error": "Debe indicar batch_id"}, 400

    name = f"projects/{PROJECT_ID}/locations/{REGION}/batches/{batch_id}"
    batch = client().get_batch(name=name)
    state = dataproc_v1.Batch.State(batch.state).name

    return {
        "batch_id": batch_id,
        "state": state,
        "state_message": batch.state_message,
        "create_time": batch.create_time.isoformat() if batch.create_time else None,
        "runtime_info": {
            "approximate_usage": str(batch.runtime_info.approximate_usage),
            "current_usage": str(batch.runtime_info.current_usage),
        },
        "output_uri": payload.get("output_uri"),
    }, 200


@functions_framework.http
def spark_submit(request: Request):
    if request.method != "POST":
        return jsonify({"error": "Utilice POST"}), 405

    payload = request.get_json(silent=True) or {}
    action = str(payload.get("action", "submit")).lower()

    try:
        if action == "submit":
            body, code = submit(payload)
        elif action == "status":
            body, code = status(payload)
        else:
            body, code = {"error": f"Acción no válida: {action}"}, 400
        return jsonify(body), code
    except Exception as exception:
        print(
            json.dumps(
                {
                    "severity": "ERROR",
                    "stage": "spark-function",
                    "action": action,
                    "error": str(exception),
                }
            )
        )
        return jsonify({"error": str(exception), "action": action}), 500
