"""Genera un arreglo reproducible para pruebas de carga."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--size", type=int, default=100000)
    parser.add_argument("--output", default="data/generated_request.json")
    args = parser.parse_args()

    generator = random.Random(2026)
    values = [generator.gauss(100.0, 15.0) for _ in range(args.size)]
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps({"values": values, "engine": "both", "sparkRepetitions": 3}),
        encoding="utf-8",
    )
    print(f"Dataset generado: {args.size:,} valores en {output}")


if __name__ == "__main__":
    main()
