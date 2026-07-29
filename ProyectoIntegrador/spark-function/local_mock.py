"""Servidor de desarrollo que ejecuta spark-submit localmente y expone el mismo contrato."""

from __future__ import annotations

import json
import os
import subprocess
import threading
import uuid
from pathlib import Path

from flask import Flask, jsonify, request

app = Flask(__name__)
JOBS: dict[str, dict] = {}
SPARK_SCRIPT = Path(
    os.getenv("LOCAL_SPARK_SCRIPT", "../spark/jobs/hybrid_pipeline.py")
).resolve()


def execute(batch_id: str, payload: dict) -> None:
    JOBS[batch_id]["state"] = "RUNNING"
    command = [
        "spark-submit",
        str(SPARK_SCRIPT),
        "--input-uri",
        payload["input_uri"],
        "--output-uri",
        payload["output_uri"],
        "--repetitions",
        str(payload.get("repetitions", 3)),
    ]
    completed = subprocess.run(command, text=True, capture_output=True)
    JOBS[batch_id].update(
        {
            "state": "SUCCEEDED" if completed.returncode == 0 else "FAILED",
            "stdout": completed.stdout[-4000:],
            "stderr": completed.stderr[-4000:],
        }
    )


@app.post("/")
def root():
    payload = request.get_json(force=True)
    action = payload.get("action", "submit")
    if action == "submit":
        batch_id = f"local-{uuid.uuid4().hex[:10]}"
        JOBS[batch_id] = {
            "batch_id": batch_id,
            "state": "PENDING",
            "output_uri": payload["output_uri"],
        }
        threading.Thread(
            target=execute,
            args=(batch_id, payload),
            daemon=True,
        ).start()
        return jsonify(JOBS[batch_id]), 202
    if action == "status":
        return jsonify(JOBS.get(payload.get("batch_id"), {"state": "NOT_FOUND"}))
    return jsonify({"error": "acción no válida"}), 400


if __name__ == "__main__":
    app.run(port=8082)
