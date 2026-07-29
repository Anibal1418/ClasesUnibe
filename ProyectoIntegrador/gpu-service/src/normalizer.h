#ifndef HYBRID_NORMALIZER_H
#define HYBRID_NORMALIZER_H

#include <cstddef>

// C ABI para que Python pueda cargar la biblioteca mediante ctypes.
extern "C" {

// Normaliza mediante OpenMP y devuelve 0 cuando la operación termina correctamente.
int normalize_cpu_omp(
    const double* input,
    std::size_t size,
    double* output,
    double* mean,
    double* standard_deviation,
    double* elapsed_ms
);

// Normaliza mediante CUDA y devuelve un código distinto de cero si no hay GPU disponible.
int normalize_gpu_cuda(
    const double* input,
    std::size_t size,
    double* output,
    double* mean,
    double* standard_deviation,
    double* elapsed_ms
);

// Informa si el runtime CUDA detecta al menos un dispositivo compatible.
int cuda_device_available();

}

#endif
