import os
import re
import shutil
import time
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from pyspark.sql import SparkSession
from pyspark.sql import functions as F

BASE = Path("/content/spark_wordcount")
DATASET = BASE / "dataset_100mb.txt"
RDD_OUT = BASE / "salida_rdd"
DF_OUT = BASE / "salida_dataframe_parquet"
CHART = BASE / "comparacion_tiempos.png"
RESULTS_CSV = BASE / "resultados_rendimiento.csv"

BASE.mkdir(parents=True, exist_ok=True)

def generar_dataset_texto(ruta: Path, objetivo_mb: int = 105) -> None:
    """Genera un texto reproducible de al menos objetivo_mb."""
    if ruta.exists() and ruta.stat().st_size >= objetivo_mb * 1024 * 1024:
        print(f"Dataset existente: {ruta.stat().st_size / 1024**2:.2f} MB")
        return

    parrafo = (
        "Apache Spark procesa datos distribuidos mediante particiones y ejecución paralela. "
        "Los RDD ofrecen control de bajo nivel mientras los DataFrames aportan estructura, "
        "expresividad y optimización mediante Catalyst. Big Data requiere escalabilidad, "
        "tolerancia a fallos, procesamiento eficiente y análisis reproducible. "
        "Python PySpark permite ejecutar transformaciones y acciones sobre grandes volúmenes. "
        "El conteo de palabras es un ejemplo clásico para comparar APIs distribuidas. "
    )

    bloque = ((parrafo + "\n") * 2500).encode("utf-8")
    objetivo = objetivo_mb * 1024 * 1024

    with ruta.open("wb") as archivo:
        while archivo.tell() < objetivo:
            archivo.write(bloque)

    print(f"Dataset generado: {ruta.stat().st_size / 1024**2:.2f} MB")

def limpiar_salida(ruta: Path) -> None:
    if ruta.exists():
        shutil.rmtree(ruta)

def normalizar_linea(linea: str):
    return re.findall(r"[a-záéíóúüñ0-9]+", linea.lower())

generar_dataset_texto(DATASET, objetivo_mb=105)

spark = (
    SparkSession.builder
    .appName("ComparacionWordCountRDDDataFrame")
    .master("local[*]")
    .config("spark.sql.shuffle.partitions", "8")
    .getOrCreate()
)
sc = spark.sparkContext
sc.setLogLevel("WARN")

print("Versión de Spark:", spark.version)
print("Aplicación:", sc.appName)
print("Paralelismo predeterminado:", sc.defaultParallelism)

# Calentamiento para reducir el costo del arranque en la comparación.
spark.range(100_000).count()

# -----------------------------
# Word Count con RDD
# -----------------------------
limpiar_salida(RDD_OUT)

inicio_rdd = time.perf_counter()

lineas_rdd = sc.textFile(str(DATASET))
conteo_rdd = (
    lineas_rdd
    .flatMap(normalizar_linea)
    .filter(lambda palabra: palabra != "")
    .map(lambda palabra: (palabra, 1))
    .reduceByKey(lambda a, b: a + b)
    .sortBy(lambda par: (-par[1], par[0]))
)

total_palabras_rdd = conteo_rdd.map(lambda par: par[1]).sum()
vocabulario_rdd = conteo_rdd.count()
top_rdd = conteo_rdd.take(20)
conteo_rdd.map(lambda par: f"{par[0]}\t{par[1]}").saveAsTextFile(str(RDD_OUT))

tiempo_rdd = time.perf_counter() - inicio_rdd

print(f"RDD - tiempo: {tiempo_rdd:.4f} s")
print(f"RDD - palabras totales: {int(total_palabras_rdd):,}")
print(f"RDD - palabras distintas: {vocabulario_rdd:,}")
print("RDD - top 20:")
for palabra, cantidad in top_rdd:
    print(f"{palabra:20s} {cantidad:,}")

# -----------------------------
# Word Count con DataFrame
# -----------------------------
limpiar_salida(DF_OUT)

inicio_df = time.perf_counter()

lineas_df = spark.read.text(str(DATASET))

palabras_df = (
    lineas_df
    .select(
        F.explode(
            F.split(
                F.lower(
                    F.regexp_replace(F.col("value"), r"[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9]+", " ")
                ),
                r"\s+"
            )
        ).alias("palabra")
    )
    .filter(F.col("palabra") != "")
)

conteo_df = (
    palabras_df
    .groupBy("palabra")
    .count()
    .orderBy(F.desc("count"), F.asc("palabra"))
)

total_palabras_df = palabras_df.count()
vocabulario_df = conteo_df.count()
top_df = conteo_df.limit(20).toPandas()
conteo_df.write.mode("overwrite").parquet(str(DF_OUT))

tiempo_df = time.perf_counter() - inicio_df

print(f"DataFrame - tiempo: {tiempo_df:.4f} s")
print(f"DataFrame - palabras totales: {total_palabras_df:,}")
print(f"DataFrame - palabras distintas: {vocabulario_df:,}")
print("DataFrame - top 20:")
display(top_df)

# -----------------------------
# Validación y rendimiento
# -----------------------------
assert int(total_palabras_rdd) == int(total_palabras_df), "Los totales no coinciden."
assert int(vocabulario_rdd) == int(vocabulario_df), "El vocabulario no coincide."
assert dict(top_rdd) == dict(zip(top_df["palabra"], top_df["count"])), "El top 20 no coincide."

speedup_df = tiempo_rdd / tiempo_df
metodo_mas_rapido = "DataFrame" if tiempo_df < tiempo_rdd else "RDD"

resultados = pd.DataFrame({
    "Método": ["RDD", "DataFrame"],
    "Tiempo_segundos": [tiempo_rdd, tiempo_df],
    "Palabras_totales": [int(total_palabras_rdd), int(total_palabras_df)],
    "Palabras_distintas": [int(vocabulario_rdd), int(vocabulario_df)]
})
resultados.to_csv(RESULTS_CSV, index=False)

print("\nComparación:")
print(f"Speedup relativo RDD/DataFrame: {speedup_df:.4f}x")
print(f"Método más rápido en esta ejecución: {metodo_mas_rapido}")

plt.figure(figsize=(8, 5))
plt.bar(resultados["Método"], resultados["Tiempo_segundos"])
plt.ylabel("Tiempo de ejecución, segundos")
plt.title("Word Count: RDD frente a DataFrame")
for i, valor in enumerate(resultados["Tiempo_segundos"]):
    plt.text(i, valor, f"{valor:.2f} s", ha="center", va="bottom")
plt.tight_layout()
plt.savefig(CHART, dpi=180, bbox_inches="tight")
plt.show()

print("\nPlan físico del DataFrame:")
conteo_df.explain(mode="formatted")