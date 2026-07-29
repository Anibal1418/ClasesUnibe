# Etapa de compilación: incluye nvcc y cabeceras CUDA.
FROM nvidia/cuda:12.2.2-devel-ubuntu22.04 AS native-build

RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY src/ ./src/
RUN mkdir -p /out && \
    nvcc -O3 -std=c++17 \
    -Xcompiler=-fopenmp -Xcompiler=-fPIC \
    -shared src/normalizer.cu \
    -o /out/libnormalizer.so

# Imagen de ejecución: conserva runtime CUDA, OpenMP y el servidor HTTP.
FROM nvidia/cuda:12.2.2-runtime-ubuntu22.04

ENV PYTHONUNBUFFERED=1 \
    NORMALIZER_LIBRARY=/opt/normalizer/libnormalizer.so \
    PORT=8080

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

COPY --from=native-build /out/libnormalizer.so /opt/normalizer/libnormalizer.so
COPY app.py .

CMD ["sh", "-c", "uvicorn app:app --host 0.0.0.0 --port ${PORT}"]
