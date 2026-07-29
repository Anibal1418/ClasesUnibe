"""Benchmark reproducible del backend OpenMP disponible sin GPU."""

from __future__ import annotations

import argparse
import ctypes
import json
import random
import statistics
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--library", required=True)
    parser.add_argument("--sizes", default="10000,100000,1000000")
    parser.add_argument("--repetitions", type=int, default=5)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    library = ctypes.CDLL(args.library)
    pointer = ctypes.POINTER(ctypes.c_double)
    library.normalize_cpu_omp.argtypes = [
        pointer,
        ctypes.c_size_t,
        pointer,
        pointer,
        pointer,
        pointer,
    ]
    library.normalize_cpu_omp.restype = ctypes.c_int

    generator = random.Random(2026)
    rows = []

    for size in [int(item) for item in args.sizes.split(",")]:
        values = [generator.gauss(100.0, 15.0) for _ in range(size)]
        array_type = ctypes.c_double * size
        input_array = array_type(*values)
        output_array = array_type()
        runs = []

        for _ in range(args.repetitions):
            mean = ctypes.c_double()
            std = ctypes.c_double()
            elapsed = ctypes.c_double()
            code = library.normalize_cpu_omp(
                input_array,
                size,
                output_array,
                ctypes.byref(mean),
                ctypes.byref(std),
                ctypes.byref(elapsed),
            )
            if code != 0:
                raise RuntimeError(f"Código nativo {code}")
            runs.append(elapsed.value)

        rows.append(
            {
                "size": size,
                "median_ms": statistics.median(runs),
                "minimum_ms": min(runs),
                "maximum_ms": max(runs),
                "runs_ms": runs,
            }
        )

    Path(args.output).write_text(
        json.dumps(rows, indent=2),
        encoding="utf-8",
    )
    print(json.dumps(rows, indent=2))


if __name__ == "__main__":
    main()
