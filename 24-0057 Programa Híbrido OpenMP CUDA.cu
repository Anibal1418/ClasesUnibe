#include <cstdio>
#include <cstdlib>
#include <cmath>
#include <cuda_runtime.h>
#include <omp.h>

// Macro para validar cada llamada a la API de CUDA.
#define CHECK_CUDA(call)                                                     \
    do {                                                                     \
        cudaError_t err = call;                                               \
        if (err != cudaSuccess) {                                             \
            fprintf(stderr, "Error CUDA en %s:%d: %s\n",                     \
                    __FILE__, __LINE__, cudaGetErrorString(err));             \
            exit(EXIT_FAILURE);                                               \
        }                                                                    \
    } while (0)

// Kernel CUDA: cada hilo calcula una posición del vector C.
__global__ void add_vectors(const float *A, const float *B, float *C, int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i < N) {
        C[i] = A[i] + B[i];
    }
}

// Versión CPU paralela: OpenMP distribuye el bucle entre varios hilos.
void add_vectors_openmp(const float *A, const float *B, float *C, int N) {
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < N; i++) {
        C[i] = A[i] + B[i];
    }
}

// Inicialización reproducible de los vectores de entrada.
void inicializar_vectores(float *A, float *B, int N) {
    #pragma omp parallel for schedule(static)
    for (int i = 0; i < N; i++) {
        A[i] = static_cast<float>(i) * 0.5f;
        B[i] = static_cast<float>(i) * 2.0f;
    }
}

// Compara el resultado CPU contra el resultado GPU.
bool verificar_resultados(const float *cpu, const float *gpu, int N) {
    const float tolerancia = 1e-5f;

    for (int i = 0; i < N; i++) {
        if (fabs(cpu[i] - gpu[i]) > tolerancia) {
            printf("Diferencia detectada en i=%d: CPU=%f, GPU=%f\n",
                   i, cpu[i], gpu[i]);
            return false;
        }
    }

    return true;
}

int main() {
    // N = 1M = 1,048,576 elementos.
    const int N = 1 << 20;
    const size_t bytes = N * sizeof(float);

    // Configuración del kernel CUDA.
    const int threads_per_block = 256;
    const int blocks_per_grid = (N + threads_per_block - 1) / threads_per_block;
    
    printf("Elementos del vector: %d\n", N);
    printf("Tamaño por vector: %.2f MB\n", bytes / (1024.0 * 1024.0));
    printf("Configuración CUDA: %d bloques x %d hilos\n\n",
           blocks_per_grid, threads_per_block);

    // Reserva de memoria en el host, es decir, en la CPU.
    float *h_A = static_cast<float*>(malloc(bytes));
    float *h_B = static_cast<float*>(malloc(bytes));
    float *h_C_cpu = static_cast<float*>(malloc(bytes));
    float *h_C_gpu = static_cast<float*>(malloc(bytes));

    if (h_A == nullptr || h_B == nullptr || h_C_cpu == nullptr || h_C_gpu == nullptr) {
        fprintf(stderr, "Error reservando memoria en CPU.\n");
        return EXIT_FAILURE;
    }

    inicializar_vectores(h_A, h_B, N);

    // Medición de la versión CPU con OpenMP.
    double cpu_inicio = omp_get_wtime();
    add_vectors_openmp(h_A, h_B, h_C_cpu, N);
    double cpu_fin = omp_get_wtime();
    double tiempo_cpu = cpu_fin - cpu_inicio;

    // Punteros para la memoria del dispositivo GPU.
    float *d_A = nullptr;
    float *d_B = nullptr;
    float *d_C = nullptr;

    // Medición total GPU: reserva, copias, kernel y recuperación.
    double gpu_inicio = omp_get_wtime();

    CHECK_CUDA(cudaMalloc(reinterpret_cast<void**>(&d_A), bytes));
    CHECK_CUDA(cudaMalloc(reinterpret_cast<void**>(&d_B), bytes));
    CHECK_CUDA(cudaMalloc(reinterpret_cast<void**>(&d_C), bytes));

    CHECK_CUDA(cudaMemcpy(d_A, h_A, bytes, cudaMemcpyHostToDevice));
    CHECK_CUDA(cudaMemcpy(d_B, h_B, bytes, cudaMemcpyHostToDevice));

    add_vectors<<<blocks_per_grid, threads_per_block>>>(d_A, d_B, d_C, N);
    CHECK_CUDA(cudaGetLastError());
    CHECK_CUDA(cudaDeviceSynchronize());

    CHECK_CUDA(cudaMemcpy(h_C_gpu, d_C, bytes, cudaMemcpyDeviceToHost));

    double gpu_fin = omp_get_wtime();
    double tiempo_gpu = gpu_fin - gpu_inicio;

    bool correcto = verificar_resultados(h_C_cpu, h_C_gpu, N);
    double speedup = tiempo_cpu / tiempo_gpu;

    printf("Tiempo CPU OpenMP: %.6f segundos\n", tiempo_cpu);
    printf("Tiempo GPU CUDA total: %.6f segundos\n", tiempo_gpu);
    printf("Speedup CPU/GPU: %.3f\n", speedup);
    printf("Verificación: %s\n", correcto ? "CORRECTA" : "INCORRECTA");

    CHECK_CUDA(cudaFree(d_A));
    CHECK_CUDA(cudaFree(d_B));
    CHECK_CUDA(cudaFree(d_C));

    free(h_A);
    free(h_B);
    free(h_C_cpu);
    free(h_C_gpu);

    return correcto ? EXIT_SUCCESS : EXIT_FAILURE;
}
