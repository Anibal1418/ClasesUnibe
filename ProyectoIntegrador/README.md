# Aplicación Híbrida Big Data en Entorno Serverless

Proyecto integrador de Programación Paralela y Distribuida con CUDA, OpenMP, Apache Spark, modelo de actores y servicios serverless de Google Cloud.

## 1. Arquitectura seleccionada

- **Preprocesamiento:** Cloud Run con una GPU NVIDIA L4. El contenedor expone `POST /normalize`, carga una biblioteca C++ mediante `ctypes` y ejecuta normalización z-score con CUDA. El mismo binario contiene una ruta OpenMP para comparación CPU/GPU.
- **Persistencia:** Cloud Storage conserva el JSONL normalizado, la salida de Spark y la respuesta final.
- **Procesamiento distribuido:** una Cloud Run Function envía un batch de Managed Service for Apache Spark. El job ejecuta el mismo cálculo con RDD y DataFrame, alterna el orden de ejecución, usa la mediana de varias repeticiones y calcula `RDD_ms / DataFrame_ms`.
- **Orquestación:** Apache Pekko Typed, equivalente abierto de Akka, ejecuta cinco actores: validación, despacho GPU, envío Spark, análisis de resultados y construcción de respuesta. Los actores de E/S aplican reintentos con backoff, y el supervisor reinicia actores ante excepciones inesperadas.
- **API final:** Cloud Run publica `POST /process`, `GET /health` y `GET /results/{jobId}`.

## 2. Estructura

```text
gpu-service/             CUDA, OpenMP, FastAPI y contenedores
spark/jobs/              Job PySpark con pipelines RDD y DataFrame
spark-function/          Función HTTP que envía y consulta batches Spark
actor-orchestrator/      Sistema de actores Pekko Typed y endpoint final
infra/                   Despliegue, IAM y limpieza en Google Cloud
scripts/                 Validación y benchmark CPU reproducible
data/                    Peticiones de ejemplo
docs/                    Diagramas y figuras del informe
metrics/                 Mediciones locales verificadas
```

## 3. Ejecución local

- Python 3.12 o compatible
- `g++` con soporte OpenMP
- Docker, opcional
- Java 21 y Maven 3.9 para compilar el orquestador
- Apache Spark para ejecutar el batch local

## 4. Validación rápida del código

Desde la raíz:

```bash
make validate
```

La validación comprueba que existan los entregables, que el código contenga kernels CUDA, directivas OpenMP, ambos pipelines Spark, cálculo de speedup, supervisión y reintentos.

## 5. Probar el preprocesador sin GPU

La biblioteca local conserva exactamente el contrato nativo, pero devuelve que CUDA no está disponible.

```bash
cd gpu-service
make cpu-lib
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
NORMALIZER_LIBRARY=build/libnormalizer.so pytest -q
```

Levantar el endpoint local:

```bash
NORMALIZER_LIBRARY=build/libnormalizer.so \
LOCAL_DATA_DIR=../runtime-data \
uvicorn app:app --host 0.0.0.0 --port 8081
```

Probarlo:

```bash
curl -X POST http://127.0.0.1:8081/normalize \
  -H 'Content-Type: application/json' \
  -d '{"values":[12,15.5,11,22.3,19.7],"engine":"cpu","persist":true}'
```

También puede usarse Docker:

```bash
docker compose up --build gpu-service
```

## 6. Benchmark OpenMP reproducible

```bash
cd gpu-service
make cpu-lib
cd ..
make cpu-benchmark
```

Se generan:

- `metrics/cpu_omp_1_thread.json`
- `metrics/cpu_omp_4_threads.json`

El tiempo nativo excluye serialización HTTP y escritura en almacenamiento. 
El servicio también informa `service_wall_ms`, que sí incorpora el costo completo de la petición.

## 7. Ejecutar Spark localmente

Primero se necesita un JSONL producido por el preprocesador. Después:

```bash
spark-submit spark/jobs/hybrid_pipeline.py \
  --input-uri runtime-data/preprocessed/JOB_ID/values.jsonl \
  --output-uri runtime-data/spark-results/JOB_ID \
  --repetitions 3
```

## 8. Compilar el sistema de actores

```bash
cd actor-orchestrator
mvn clean package
```

El JAR ejecutable se genera en:

```text
target/hybrid-actor-orchestrator-1.0.0.jar
```

Variables principales:

```bash
export GPU_SERVICE_URL=http://127.0.0.1:8081
export SPARK_FUNCTION_URL=http://127.0.0.1:8082
export LOCAL_DATA_DIR=../runtime-data
java -jar target/hybrid-actor-orchestrator-1.0.0.jar
```

El mock local de la función Spark requiere `spark-submit`:

```bash
cd spark-function
pip install flask
LOCAL_SPARK_SCRIPT=../spark/jobs/hybrid_pipeline.py python local_mock.py
```

## 9. Despliegue en Google Cloud

Ejecutar desde `infra/`:

```bash
export PROJECT_ID='mi-proyecto'
export REGION='us-central1'
export DATA_BUCKET='mi-proyecto-hybrid-bigdata'

./iam_setup.sh
./deploy_gcp.sh
```

## 10. API

### `POST /process`

```json
{
  "values": [12.0, 15.5, 11.0, 22.3, 19.7],
  "engine": "both",
  "sparkRepetitions": 3
}
```

### `GET /results/{jobId}`

Recupera el resultado persistido, incluso si el cliente perdió la respuesta HTTP inicial.

### `GET /health`

Confirma que el orquestador y el ActorSystem están activos.

## 11. Cálculo de rendimiento

```text
speedup GPU frente a CPU = tiempo OpenMP / tiempo CUDA
speedup DataFrame frente a RDD = mediana RDD / mediana DataFrame
tiempo total serverless = respuesta final - recepción de la petición
```

## 12. Tolerancia a fallos

- La validación impide lanzar recursos costosos con datos inválidos.
- Los actores de GPU y Spark reintentan respuestas transitorias con backoff exponencial.
- El supervisor reinicia actores de E/S ante excepciones no controladas.
- El actor de resultados consulta el batch hasta `SUCCEEDED`, `FAILED`, `CANCELLED` o timeout.
- Cloud Storage desacopla las etapas y conserva resultados durables.
- Cada petición usa un `jobId` para logs, rutas y recuperación.
- Los reintentos de creación de batch generan un identificador único.

## 13. Limpieza

```bash
cd infra
export PROJECT_ID='mi-proyecto'
export REGION='us-central1'
./cleanup_gcp.sh
```

## 14. Fuentes técnicas principales

- Cloud Run GPU: https://cloud.google.com/run/docs/configuring/services/gpu
- Managed Service for Apache Spark: https://cloud.google.com/dataproc-serverless/docs/overview
- Batches Spark: https://cloud.google.com/dataproc-serverless/docs/quickstarts/spark-batch
- Cloud Run functions: https://cloud.google.com/run/docs/deploy-functions
- Apache Pekko Typed: https://pekko.apache.org/docs/pekko/current/typed/actors.html
- Supervisión Pekko: https://pekko.apache.org/docs/pekko/current/typed/fault-tolerance.html
- CUDA C++ Programming Guide: https://docs.nvidia.com/cuda/cuda-c-programming-guide/
