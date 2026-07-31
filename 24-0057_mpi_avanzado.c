#include <mpi.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static uint32_t siguiente_aleatorio(uint32_t *estado) {
    *estado = (*estado * 1664525u) + 1013904223u;
    return *estado;
}

int main(int argc, char *argv[]) {
    int rank = 0;
    int num_procesos = 0;
    int n = 0;

    MPI_Init(&argc, &argv);
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &num_procesos);

    /* Solo el proceso raíz solicita la cantidad de valores por proceso. */
    if (rank == 0) {
        printf("Ingrese N, cantidad de valores por proceso: ");
        fflush(stdout);

        if (scanf("%d", &n) != 1 || n <= 0) {
            n = -1;
        }
    }

    /* Todos los procesos reciben el mismo N. */
    MPI_Bcast(&n, 1, MPI_INT, 0, MPI_COMM_WORLD);

    if (n <= 0) {
        if (rank == 0) {
            fprintf(stderr, "Error: N debe ser un entero positivo.\n");
        }
        MPI_Finalize();
        return EXIT_FAILURE;
    }

    /*
     * El proceso raíz prepara una semilla diferente para cada proceso,
     * después MPI_Scatter entrega una semilla a cada participante.
     */
    uint32_t *semillas = NULL;
    uint32_t semilla_local = 0;

    if (rank == 0) {
        semillas = malloc((size_t)num_procesos * sizeof(*semillas));
        if (semillas == NULL) {
            fprintf(stderr, "Error: no se pudo reservar memoria para las semillas.\n");
            MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
        }

        for (int i = 0; i < num_procesos; ++i) {
            semillas[i] = 2026u + (uint32_t)(7919u * (uint32_t)i);
        }
    }

    MPI_Scatter(
        semillas,
        1,
        MPI_UNSIGNED,
        &semilla_local,
        1,
        MPI_UNSIGNED,
        0,
        MPI_COMM_WORLD
    );

    free(semillas);

    /* Cada proceso genera N enteros entre 1 y 100 y calcula su suma parcial. */
    int *valores = malloc((size_t)n * sizeof(*valores));
    if (valores == NULL) {
        fprintf(stderr, "Proceso %d: no se pudo reservar memoria para los valores.\n", rank);
        MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    }

    long long suma_local = 0;

    for (int i = 0; i < n; ++i) {
        valores[i] = 1 + (int)(siguiente_aleatorio(&semilla_local) % 100u);
        suma_local += valores[i];
    }

    /*
     * MPI_Gather reúne las sumas parciales en el proceso raíz,
     * lo que permite mostrar y validar la contribución de cada proceso.
     */
    long long *sumas_parciales = NULL;

    if (rank == 0) {
        sumas_parciales = malloc((size_t)num_procesos * sizeof(*sumas_parciales));
        if (sumas_parciales == NULL) {
            fprintf(stderr, "Error: no se pudo reservar memoria para las sumas parciales.\n");
            MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
        }
    }

    MPI_Gather(
        &suma_local,
        1,
        MPI_LONG_LONG,
        sumas_parciales,
        1,
        MPI_LONG_LONG,
        0,
        MPI_COMM_WORLD
    );

    /* MPI_Reduce suma todas las contribuciones y deja el resultado en rank 0. */
    long long suma_total = 0;

    MPI_Reduce(
        &suma_local,
        &suma_total,
        1,
        MPI_LONG_LONG,
        MPI_SUM,
        0,
        MPI_COMM_WORLD
    );

    double promedio_total = 0.0;

    if (rank == 0) {
        long long verificacion = 0;

        for (int i = 0; i < num_procesos; ++i) {
            verificacion += sumas_parciales[i];
        }

        promedio_total = (double)suma_total / ((double)n * (double)num_procesos);

        printf("\nResumen en el proceso raíz\n");
        printf("Procesos: %d, valores por proceso: %d, valores totales: %d\n",
               num_procesos, n, n * num_procesos);
        printf("Suma obtenida con MPI_Reduce: %lld\n", suma_total);
        printf("Suma validada con MPI_Gather: %lld\n", verificacion);
        printf("Promedio total: %.4f\n\n", promedio_total);
    }

    free(sumas_parciales);

    /* El promedio calculado por rank 0 se distribuye a todos los procesos. */
    MPI_Bcast(&promedio_total, 1, MPI_DOUBLE, 0, MPI_COMM_WORLD);

    /*
     * Las barreras siguientes solo ordenan la impresión para que la salida sea legible,
     * no forman parte del cálculo del promedio.
     */
    for (int turno = 0; turno < num_procesos; ++turno) {
        MPI_Barrier(MPI_COMM_WORLD);

        if (rank == turno) {
            printf("Proceso %d: suma local = %lld, promedio recibido = %.4f\n",
                   rank, suma_local, promedio_total);
            fflush(stdout);
        }
    }

    MPI_Barrier(MPI_COMM_WORLD);

    free(valores);
    MPI_Finalize();
    return EXIT_SUCCESS;
}
