#include "normalizer.h"

#include <cuda_runtime.h>
#include <omp.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <limits>

namespace {
constexpr int THREADS_PER_BLOCK = 256;
constexpr double EPSILON = 1.0e-12;

// Kernel de reducción: cada bloque acumula suma y suma de cuadrados en memoria compartida.
__global__ void reduce_moments_kernel(
    const double* input,
    std::size_t size,
    double* global_sum,
    double* global_sum_squares
) {
    __shared__ double partial_sum[THREADS_PER_BLOCK];
    __shared__ double partial_sum_squares[THREADS_PER_BLOCK];

    const int local_id = threadIdx.x;
    const std::size_t global_id = blockIdx.x * blockDim.x + threadIdx.x;
    const std::size_t stride = blockDim.x * gridDim.x;

    double thread_sum = 0.0;
    double thread_sum_squares = 0.0;

    for (std::size_t index = global_id; index < size; index += stride) {
        const double value = input[index];
        thread_sum += value;
        thread_sum_squares += value * value;
    }

    partial_sum[local_id] = thread_sum;
    partial_sum_squares[local_id] = thread_sum_squares;
    __syncthreads();

    for (int offset = blockDim.x / 2; offset > 0; offset /= 2) {
        if (local_id < offset) {
            partial_sum[local_id] += partial_sum[local_id + offset];
            partial_sum_squares[local_id] += partial_sum_squares[local_id + offset];
        }
        __syncthreads();
    }

    if (local_id == 0) {
        atomicAdd(global_sum, partial_sum[0]);
        atomicAdd(global_sum_squares, partial_sum_squares[0]);
    }
}

// Kernel independiente para aplicar la transformación z-score a cada posición.
__global__ void normalize_kernel(
    const double* input,
    std::size_t size,
    double mean,
    double standard_deviation,
    double* output
) {
    const std::size_t global_id = blockIdx.x * blockDim.x + threadIdx.x;
    const std::size_t stride = blockDim.x * gridDim.x;

    for (std::size_t index = global_id; index < size; index += stride) {
        output[index] = (input[index] - mean) / standard_deviation;
    }
}

int blocks_for(std::size_t size) {
    const std::size_t required = (size + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    return static_cast<int>(std::min<std::size_t>(required, 1024));
}

int check_cuda(cudaError_t result) {
    return result == cudaSuccess ? 0 : static_cast<int>(result);
}
}  // namespace

extern "C" int cuda_device_available() {
    int count = 0;
    const cudaError_t result = cudaGetDeviceCount(&count);
    return result == cudaSuccess && count > 0 ? 1 : 0;
}

extern "C" int normalize_cpu_omp(
    const double* input,
    std::size_t size,
    double* output,
    double* mean,
    double* standard_deviation,
    double* elapsed_ms
) {
    if (input == nullptr || output == nullptr || mean == nullptr ||
        standard_deviation == nullptr || elapsed_ms == nullptr || size == 0) {
        return 1;
    }

    const auto start = std::chrono::steady_clock::now();

    double sum = 0.0;
    double sum_squares = 0.0;

    // OpenMP divide la reducción entre los hilos disponibles.
    #pragma omp parallel for reduction(+ : sum, sum_squares) schedule(static)
    for (std::size_t index = 0; index < size; ++index) {
        const double value = input[index];
        sum += value;
        sum_squares += value * value;
    }

    *mean = sum / static_cast<double>(size);
    const double variance = std::max(
        0.0,
        sum_squares / static_cast<double>(size) - (*mean) * (*mean)
    );
    *standard_deviation = std::sqrt(variance);

    if (*standard_deviation < EPSILON) {
        *standard_deviation = 1.0;
    }

    // Cada posición puede normalizarse de forma independiente.
    #pragma omp parallel for schedule(static)
    for (std::size_t index = 0; index < size; ++index) {
        output[index] = (input[index] - *mean) / *standard_deviation;
    }

    const auto end = std::chrono::steady_clock::now();
    *elapsed_ms = std::chrono::duration<double, std::milli>(end - start).count();
    return 0;
}

extern "C" int normalize_gpu_cuda(
    const double* input,
    std::size_t size,
    double* output,
    double* mean,
    double* standard_deviation,
    double* elapsed_ms
) {
    if (input == nullptr || output == nullptr || mean == nullptr ||
        standard_deviation == nullptr || elapsed_ms == nullptr || size == 0) {
        return 1;
    }

    if (cuda_device_available() == 0) {
        return 100;
    }

    double* device_input = nullptr;
    double* device_output = nullptr;
    double* device_sum = nullptr;
    double* device_sum_squares = nullptr;
    cudaEvent_t start_event = nullptr;
    cudaEvent_t end_event = nullptr;

    const std::size_t bytes = size * sizeof(double);

    if (check_cuda(cudaMalloc(&device_input, bytes)) != 0 ||
        check_cuda(cudaMalloc(&device_output, bytes)) != 0 ||
        check_cuda(cudaMalloc(&device_sum, sizeof(double))) != 0 ||
        check_cuda(cudaMalloc(&device_sum_squares, sizeof(double))) != 0) {
        cudaFree(device_input);
        cudaFree(device_output);
        cudaFree(device_sum);
        cudaFree(device_sum_squares);
        return 2;
    }

    cudaEventCreate(&start_event);
    cudaEventCreate(&end_event);
    cudaEventRecord(start_event);

    cudaMemset(device_sum, 0, sizeof(double));
    cudaMemset(device_sum_squares, 0, sizeof(double));
    cudaMemcpy(device_input, input, bytes, cudaMemcpyHostToDevice);

    const int blocks = blocks_for(size);
    reduce_moments_kernel<<<blocks, THREADS_PER_BLOCK>>>(
        device_input,
        size,
        device_sum,
        device_sum_squares
    );

    double sum = 0.0;
    double sum_squares = 0.0;
    cudaMemcpy(&sum, device_sum, sizeof(double), cudaMemcpyDeviceToHost);
    cudaMemcpy(&sum_squares, device_sum_squares, sizeof(double), cudaMemcpyDeviceToHost);

    *mean = sum / static_cast<double>(size);
    const double variance = std::max(
        0.0,
        sum_squares / static_cast<double>(size) - (*mean) * (*mean)
    );
    *standard_deviation = std::sqrt(variance);

    if (*standard_deviation < EPSILON) {
        *standard_deviation = 1.0;
    }

    normalize_kernel<<<blocks, THREADS_PER_BLOCK>>>(
        device_input,
        size,
        *mean,
        *standard_deviation,
        device_output
    );

    cudaMemcpy(output, device_output, bytes, cudaMemcpyDeviceToHost);
    cudaEventRecord(end_event);
    cudaEventSynchronize(end_event);

    float milliseconds = 0.0F;
    cudaEventElapsedTime(&milliseconds, start_event, end_event);
    *elapsed_ms = static_cast<double>(milliseconds);

    const cudaError_t kernel_status = cudaGetLastError();

    cudaEventDestroy(start_event);
    cudaEventDestroy(end_event);
    cudaFree(device_input);
    cudaFree(device_output);
    cudaFree(device_sum);
    cudaFree(device_sum_squares);

    return kernel_status == cudaSuccess ? 0 : static_cast<int>(kernel_status);
}
