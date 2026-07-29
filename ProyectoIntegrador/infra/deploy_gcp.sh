#!/usr/bin/env bash
set -euo pipefail

# Variables obligatorias.
: "${PROJECT_ID:?Defina PROJECT_ID}"
REGION="${REGION:-us-central1}"
BUCKET="${DATA_BUCKET:-${PROJECT_ID}-hybrid-bigdata}"
REPOSITORY="${REPOSITORY:-hybrid-bigdata}"
GPU_SERVICE="${GPU_SERVICE:-gpu-normalizer}"
SPARK_FUNCTION="${SPARK_FUNCTION:-spark-submit-function}"
ORCHESTRATOR_SERVICE="${ORCHESTRATOR_SERVICE:-hybrid-actor-orchestrator}"
RUNTIME_VERSION="${SPARK_RUNTIME_VERSION:-2.3}"

GPU_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/gpu-normalizer:latest"
ACTOR_IMAGE="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/actor-orchestrator:latest"
SPARK_SCRIPT_URI="gs://${BUCKET}/code/hybrid_pipeline.py"

printf 'Proyecto: %s\nRegión: %s\nBucket: %s\n' "$PROJECT_ID" "$REGION" "$BUCKET"
gcloud config set project "$PROJECT_ID"

gcloud services enable \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  artifactregistry.googleapis.com \
  dataproc.googleapis.com \
  cloudfunctions.googleapis.com \
  storage.googleapis.com

# Repositorio y bucket idempotentes.
gcloud artifacts repositories describe "$REPOSITORY" --location "$REGION" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "$REPOSITORY" \
    --repository-format=docker --location "$REGION"

gcloud storage buckets describe "gs://${BUCKET}" >/dev/null 2>&1 || \
  gcloud storage buckets create "gs://${BUCKET}" --location "$REGION" --uniform-bucket-level-access

gcloud storage cp ../spark/jobs/hybrid_pipeline.py "$SPARK_SCRIPT_URI"

# Compilación de imágenes mediante Cloud Build.
gcloud builds submit ../gpu-service --tag "$GPU_IMAGE"
gcloud builds submit ../actor-orchestrator --tag "$ACTOR_IMAGE"

# GPU L4: 4 vCPU y 16 GiB son mínimos; concurrencia 1 evita competir por la GPU.
gcloud run deploy "$GPU_SERVICE" \
  --image "$GPU_IMAGE" \
  --region "$REGION" \
  --gpu 1 \
  --gpu-type nvidia-l4 \
  --cpu 4 \
  --memory 16Gi \
  --no-cpu-throttling \
  --concurrency 1 \
  --max-instances 3 \
  --timeout 300 \
  --set-env-vars "DATA_BUCKET=${BUCKET},MAX_INPUT_VALUES=2000000" \
  --allow-unauthenticated

GPU_URL="$(gcloud run services describe "$GPU_SERVICE" --region "$REGION" --format='value(status.url)')"

# Función HTTP que usa la API de batches de Managed Service for Apache Spark.
gcloud functions deploy "$SPARK_FUNCTION" \
  --gen2 \
  --runtime python312 \
  --region "$REGION" \
  --source ../spark-function \
  --entry-point spark_submit \
  --trigger-http \
  --timeout 300 \
  --memory 1Gi \
  --set-env-vars "PROJECT_ID=${PROJECT_ID},REGION=${REGION},SPARK_SCRIPT_URI=${SPARK_SCRIPT_URI},SPARK_RUNTIME_VERSION=${RUNTIME_VERSION}" \
  --allow-unauthenticated

SPARK_URL="$(gcloud functions describe "$SPARK_FUNCTION" --gen2 --region "$REGION" --format='value(serviceConfig.uri)')"

# El endpoint puede esperar el batch hasta 60 minutos, mientras los actores trabajan asíncronamente.
gcloud run deploy "$ORCHESTRATOR_SERVICE" \
  --image "$ACTOR_IMAGE" \
  --region "$REGION" \
  --cpu 2 \
  --memory 2Gi \
  --concurrency 20 \
  --timeout 3600 \
  --max-instances 10 \
  --set-env-vars "GPU_SERVICE_URL=${GPU_URL},SPARK_FUNCTION_URL=${SPARK_URL},DATA_BUCKET=${BUCKET},MAX_INPUT_VALUES=2000000" \
  --allow-unauthenticated

ORCHESTRATOR_URL="$(gcloud run services describe "$ORCHESTRATOR_SERVICE" --region "$REGION" --format='value(status.url)')"

cat <<SUMMARY

Despliegue completado.
GPU service:       ${GPU_URL}
Spark function:   ${SPARK_URL}
Orchestrator API: ${ORCHESTRATOR_URL}

Prueba:
curl -X POST "${ORCHESTRATOR_URL}/process" \\
  -H 'Content-Type: application/json' \\
  --data-binary @../data/sample_request.json
SUMMARY
