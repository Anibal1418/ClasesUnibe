#include "normalizer.h"

#include <omp.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>

namespace {
constexpr double EPSILON = 1.0e-12;
}

extern "C" int cuda_device_available() {
    // Esta biblioteca se usa únicamente para pruebas locales sin CUDA.
    return 0;
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

    #pragma omp parallel for schedule(static)
    for (std::size_t index = 0; index < size; ++index) {
        output[index] = (input[index] - *mean) / *standard_deviation;
    }

    const auto end = std::chrono::steady_clock::now();
    *elapsed_ms = std::chrono::duration<double, std::milli>(end - start).count();
    return 0;
}

extern "C" int normalize_gpu_cuda(
    const double*,
    std::size_t,
    double*,
    double*,
    double*,
    double*
) {
    // Código 100: backend CUDA no disponible en el host local.
    return 100;
}
