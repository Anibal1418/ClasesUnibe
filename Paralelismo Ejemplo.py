"""
Ejemplo práctico de concurrencia y paralelismo con multiprocessing.

Este script compara el tiempo de ejecución de una tarea intensiva en CPU
de forma secuencial y en paralelo usando varios procesos.

Uso:
    python ejemplo_paralelismo.py
"""

from __future__ import annotations

import math
import time
from multiprocessing import Pool, cpu_count


def sumar_raices(rango: tuple[int, int]) -> float:
    """
    Calcula la suma de raíces cuadradas para un rango dado.
    """
    inicio, fin = rango
    acumulado = 0.0
    for i in range(inicio, fin):
        acumulado += math.sqrt(i)
    return acumulado


def dividir_trabajo(total: int, partes: int) -> list[tuple[int, int]]:
    """
    Divide un rango total en varias partes casi iguales.
    """
    tamano = total // partes
    rangos: list[tuple[int, int]] = []
    inicio = 1

    for indice in range(partes):
        fin = inicio + tamano
        if indice == partes - 1:
            fin = total + 1
        rangos.append((inicio, fin))
        inicio = fin

    return rangos


def ejecutar_secuencial(total: int, procesos: int) -> tuple[float, float]:
    """
    Ejecuta la tarea de forma secuencial.
    """
    rangos = dividir_trabajo(total, procesos)

    inicio_tiempo = time.perf_counter()
    resultado = sum(sumar_raices(rango) for rango in rangos)
    fin_tiempo = time.perf_counter()

    return resultado, fin_tiempo - inicio_tiempo


def ejecutar_paralelo(total: int, procesos: int) -> tuple[float, float]:
    """
    Ejecuta la tarea en paralelo usando multiprocessing.Pool.
    """
    rangos = dividir_trabajo(total, procesos)

    inicio_tiempo = time.perf_counter()
    with Pool(processes=procesos) as pool:
        resultados = pool.map(sumar_raices, rangos)
    resultado = sum(resultados)
    fin_tiempo = time.perf_counter()

    return resultado, fin_tiempo - inicio_tiempo


def main() -> None:
    total_numeros = 2_000_000
    procesos = min(4, cpu_count())

    print("=== Ejemplo de paralelismo con multiprocessing ===")
    print(f"Números a procesar: {total_numeros:,}")
    print(f"Procesos utilizados: {procesos}")
    print()

    resultado_secuencial, tiempo_secuencial = ejecutar_secuencial(total_numeros, procesos)
    resultado_paralelo, tiempo_paralelo = ejecutar_paralelo(total_numeros, procesos)

    print("Resultados")
    print(f"Suma secuencial: {resultado_secuencial:.4f}")
    print(f"Suma paralela:   {resultado_paralelo:.4f}")
    print()

    print("Tiempos")
    print(f"Tiempo secuencial: {tiempo_secuencial:.4f} segundos")
    print(f"Tiempo paralelo:   {tiempo_paralelo:.4f} segundos")

    if tiempo_paralelo > 0:
        speedup = tiempo_secuencial / tiempo_paralelo
        print(f"Aceleración aproximada: {speedup:.2f}x")

    print()
    print("Interpretación")
    print(
        "La versión paralela divide el trabajo en varios procesos que se ejecutan "
        "simultáneamente, aprovechando mejor varios núcleos del procesador."
    )


if __name__ == "__main__":
    main()
