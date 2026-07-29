#!/usr/bin/env bash
set -euo pipefail
: "${PROJECT_ID:?Defina PROJECT_ID}"

# Cuenta dedicada al envío y ejecución de batches Spark.
SERVICE_ACCOUNT_NAME="${SERVICE_ACCOUNT_NAME:-hybrid-spark-runtime}"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts describe "$SERVICE_ACCOUNT" >/dev/null 2>&1 || \
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="Hybrid Big Data Spark Runtime"

for role in roles/dataproc.worker roles/storage.objectAdmin roles/logging.logWriter; do
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:${SERVICE_ACCOUNT}" \
    --role="$role" >/dev/null
done

printf 'Cuenta preparada: %s\n' "$SERVICE_ACCOUNT"
printf 'Configure SPARK_SERVICE_ACCOUNT=%s al desplegar la función.\n' "$SERVICE_ACCOUNT"
