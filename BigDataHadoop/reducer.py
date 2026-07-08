#!/usr/bin/env python3
import sys

palabra_actual = None
conteo_actual = 0


def emitir(palabra, conteo):
    #Imprime el resultado acumulado para una palabra.
    if palabra is not None:
        print(f"{palabra}\t{conteo}")


for linea in sys.stdin:
    linea = linea.strip()

    if not linea:
        continue

    try:
        palabra, conteo = linea.split("\t", 1)
        conteo = int(conteo)
    except ValueError:
        continue

    if palabra_actual == palabra:
        conteo_actual += conteo
    else:
        emitir(palabra_actual, conteo_actual)
        palabra_actual = palabra
        conteo_actual = conteo

emitir(palabra_actual, conteo_actual)
