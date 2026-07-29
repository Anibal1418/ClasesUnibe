#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT_ID:?Defina PROJECT_ID}"
REGION="${REGION:-us-central1}"
BUCKET="${DATA_BUCKET:-${PROJECT_ID}-hybrid-bigdata}"

gcloud run services delete "${GPU_SERVICE:-gpu-normalizer}" --region "$REGION" --quiet || true
gcloud run services delete "${ORCHESTRATOR_SERVICE:-hybrid-actor-orchestrator}" --region "$REGION" --quiet || true
gcloud functions delete "${SPARK_FUNCTION:-spark-submit-function}" --gen2 --region "$REGION" --quiet || true
gcloud storage rm --recursive "gs://${BUCKET}" || true
