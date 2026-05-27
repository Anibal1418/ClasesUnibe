#include <stdio.h>
#include <mpi.h>

int main(int argc, char *argv[]) {
    int rank;
    int size;
    int valor;
    const int etiqueta = 0;
    MPI_Status estado;

    MPI_Init(&argc, &argv);

    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &size);

    if (size < 2) {
        if (rank == 0) {
            printf("Error: este programa necesita al menos 2 procesos.\n");
            printf("Ejecute con: mpirun -np 2 ./mpi_punto_a_punto\n");
        }
        MPI_Finalize();
        return 0;
    }

    if (rank == 0) {
        valor = 100;
        MPI_Send(&valor, 1, MPI_INT, 1, etiqueta, MPI_COMM_WORLD);
        printf("Proceso %d envio el valor %d al proceso 1.\n", rank, valor);
    } else if (rank == 1) {
        MPI_Recv(&valor, 1, MPI_INT, 0, etiqueta, MPI_COMM_WORLD, &estado);
        printf("Proceso %d recibio el valor %d desde el proceso %d.\n",
               rank, valor, estado.MPI_SOURCE);
    } else {
        printf("Proceso %d no participa en este envio directo.\n", rank);
    }

    MPI_Finalize();
    return 0;
}
