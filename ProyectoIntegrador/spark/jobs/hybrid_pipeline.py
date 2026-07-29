"""Pipelines comparables de Apache Spark con RDD y DataFrame."""

from __future__ import annotations

import argparse
import json
import statistics
import time
from typing import Any

from pyspark.sql import Row, SparkSession, functions as F


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input-uri", required=True)
    parser.add_argument("--output-uri", required=True)
    parser.add_argument("--repetitions", type=int, default=3)
    return parser.parse_args()


def rdd_pipeline(spark: SparkSession, input_uri: str) -> dict[str, Any]:
    """Lee JSONL como texto, convierte cada registro y agrega en una sola acción."""

    started = time.perf_counter()

    values = (
        spark.sparkContext.textFile(input_uri)
        .map(json.loads)
        .map(lambda record: float(record["normalized"]))
    )

    # El acumulador contiene count, sum, sumSquares, min, max y countAbsGt1.
    zero = (0, 0.0, 0.0, float("inf"), float("-inf"), 0)

    def sequence(accumulator, value):
        count, total, squares, minimum, maximum, outside = accumulator
        return (
            count + 1,
            total + value,
            squares + value * value,
            min(minimum, value),
            max(maximum, value),
            outside + (1 if abs(value) > 1.0 else 0),
        )

    def combine(left, right):
        return (
            left[0] + right[0],
            left[1] + right[1],
            left[2] + right[2],
            min(left[3], right[3]),
            max(left[4], right[4]),
            left[5] + right[5],
        )

    count, total, squares, minimum, maximum, outside = values.aggregate(
        zero,
        sequence,
        combine,
    )

    mean = total / count
    variance = max(0.0, squares / count - mean * mean)
    elapsed_ms = (time.perf_counter() - started) * 1000.0

    return {
        "count": count,
        "mean": mean,
        "standard_deviation": variance**0.5,
        "minimum": minimum,
        "maximum": maximum,
        "absolute_greater_than_one": outside,
        "elapsed_ms": elapsed_ms,
    }


def dataframe_pipeline(spark: SparkSession, input_uri: str) -> dict[str, Any]:
    """Ejecuta la misma agregación mediante expresiones optimizables por Spark SQL."""

    started = time.perf_counter()
    frame = spark.read.json(input_uri).select(
        F.col("normalized").cast("double").alias("normalized")
    )

    row = (
        frame.agg(
            F.count("*").alias("count"),
            F.avg("normalized").alias("mean"),
            F.stddev_pop("normalized").alias("standard_deviation"),
            F.min("normalized").alias("minimum"),
            F.max("normalized").alias("maximum"),
            F.sum(
                F.when(F.abs(F.col("normalized")) > 1.0, 1).otherwise(0)
            ).alias("absolute_greater_than_one"),
        )
        .first()
        .asDict()
    )

    row["elapsed_ms"] = (time.perf_counter() - started) * 1000.0
    return row


def comparable(result: dict[str, Any]) -> dict[str, float]:
    return {
        key: float(result[key])
        for key in (
            "count",
            "mean",
            "standard_deviation",
            "minimum",
            "maximum",
            "absolute_greater_than_one",
        )
    }


def main() -> None:
    args = parse_arguments()
    repetitions = max(1, args.repetitions)

    spark = (
        SparkSession.builder.appName("HybridBigDataRDDvsDataFrame")
        .config("spark.sql.adaptive.enabled", "true")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")

    rdd_runs: list[dict[str, Any]] = []
    dataframe_runs: list[dict[str, Any]] = []

    # Alternar el orden reduce el sesgo provocado por calentamiento y cachés del sistema.
    for repetition in range(repetitions):
        spark.catalog.clearCache()
        if repetition % 2 == 0:
            rdd_runs.append(rdd_pipeline(spark, args.input_uri))
            dataframe_runs.append(dataframe_pipeline(spark, args.input_uri))
        else:
            dataframe_runs.append(dataframe_pipeline(spark, args.input_uri))
            rdd_runs.append(rdd_pipeline(spark, args.input_uri))

    rdd_median = statistics.median(run["elapsed_ms"] for run in rdd_runs)
    dataframe_median = statistics.median(
        run["elapsed_ms"] for run in dataframe_runs
    )

    # Los pipelines deben producir las mismas estadísticas salvo diferencias numéricas menores.
    rdd_reference = comparable(rdd_runs[-1])
    dataframe_reference = comparable(dataframe_runs[-1])
    maximum_metric_difference = max(
        abs(rdd_reference[key] - dataframe_reference[key])
        for key in rdd_reference
    )

    result = {
        "input_uri": args.input_uri,
        "repetitions": repetitions,
        "rdd": {
            "median_ms": rdd_median,
            "runs_ms": [run["elapsed_ms"] for run in rdd_runs],
            "statistics": rdd_reference,
        },
        "dataframe": {
            "median_ms": dataframe_median,
            "runs_ms": [run["elapsed_ms"] for run in dataframe_runs],
            "statistics": dataframe_reference,
        },
        "speedup_dataframe_vs_rdd": (
            rdd_median / dataframe_median if dataframe_median > 0 else None
        ),
        "maximum_metric_difference": maximum_metric_difference,
    }

    payload = json.dumps(result, separators=(",", ":"), sort_keys=True)

    # Un único part file simplifica la recolección posterior por el actor de resultados.
    spark.createDataFrame([Row(payload=payload)]).select("payload").coalesce(1).write.mode(
        "overwrite"
    ).text(f"{args.output_uri.rstrip('/')}/result")

    print("HYBRID_RESULT=" + payload)
    spark.stop()


if __name__ == "__main__":
    main()
