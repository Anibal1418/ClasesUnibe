"""Validación estática de archivos obligatorios y contratos principales."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "gpu-service/src/normalizer.cu",
    "gpu-service/src/normalizer_cpu.cpp",
    "gpu-service/app.py",
    "spark/jobs/hybrid_pipeline.py",
    "spark-function/main.py",
    "actor-orchestrator/pom.xml",
    "actor-orchestrator/src/main/java/com/luis/hybrid/actors/OrchestratorActor.java",
    "actor-orchestrator/src/main/java/com/luis/hybrid/actors/ValidationActor.java",
    "actor-orchestrator/src/main/java/com/luis/hybrid/actors/GpuStageActor.java",
    "actor-orchestrator/src/main/java/com/luis/hybrid/actors/SparkSubmissionActor.java",
    "actor-orchestrator/src/main/java/com/luis/hybrid/actors/ResultAnalysisActor.java",
    "actor-orchestrator/src/main/java/com/luis/hybrid/actors/ResponseActor.java",
    "infra/deploy_gcp.sh",
    "README.md",
]

missing = [path for path in REQUIRED if not (ROOT / path).exists()]
if missing:
    raise SystemExit("Faltan archivos:\n" + "\n".join(missing))

checks = {
    "CUDA kernel": (ROOT / "gpu-service/src/normalizer.cu", "__global__"),
    "OpenMP": (ROOT / "gpu-service/src/normalizer.cu", "#pragma omp"),
    "RDD": (ROOT / "spark/jobs/hybrid_pipeline.py", "spark.sparkContext.textFile"),
    "DataFrame": (ROOT / "spark/jobs/hybrid_pipeline.py", "spark.read.json"),
    "Speedup": (ROOT / "spark/jobs/hybrid_pipeline.py", "speedup_dataframe_vs_rdd"),
    "Supervision": (ROOT / "actor-orchestrator/src/main/java/com/luis/hybrid/actors/OrchestratorActor.java", "restartWithBackoff"),
    "Retries": (ROOT / "actor-orchestrator/src/main/java/com/luis/hybrid/actors/GpuStageActor.java", "scheduleOnce"),
}

for name, (path, token) in checks.items():
    if token not in path.read_text(encoding="utf-8"):
        raise SystemExit(f"Validación fallida: {name}")
    print(f"{name}: OK")

print("Estructura del proyecto: OK")
