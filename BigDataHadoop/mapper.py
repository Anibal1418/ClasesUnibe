#!/usr/bin/env python3
import re
import sys
import unicodedata

PATRON_PALABRA = re.compile(r"[a-zA-ZñÑáéíóúÁÉÍÓÚüÜ]+", re.UNICODE)


def normalizar(texto: str) -> str:
    #Convierte el texto a minusculas y elimina acentos para unificar palabras.
    texto = texto.lower()
    texto = unicodedata.normalize("NFD", texto)
    texto = "".join(caracter for caracter in texto if unicodedata.category(caracter) != "Mn")
    return texto


for linea in sys.stdin:
    linea = normalizar(linea)
    palabras = PATRON_PALABRA.findall(linea)

    for palabra in palabras:
        print(f"{palabra}\t1")
