# Hadoop MapReduce WordCount con Python Streaming

Este proyecto implementa un job de Hadoop MapReduce usando Python Streaming para realizar conteo de palabras sobre archivos de texto.

## Archivos principales

- `mapper.py`: lee líneas de texto, tokeniza palabras y emite pares `(palabra, 1)`.
- `reducer.py`: recibe las palabras agrupadas y suma sus ocurrencias.
- `textos/`: carpeta con archivos de entrada de prueba.
- `tiempos_reducers.csv`: resultados de rendimiento usando diferentes cantidades de reducers.

## Ejecución general

1. Subir los archivos de texto a HDFS.
2. Ejecutar Hadoop Streaming usando `mapper.py` y `reducer.py`.
3. Recuperar los resultados desde HDFS.
4. Comparar tiempos con 1, 2 y 4 reducers.

## Autor

Luis Sánchez
