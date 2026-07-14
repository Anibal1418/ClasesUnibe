#include <mpi.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define TOTAL_ITERATIONS 20
#define CHECKPOINT_INTERVAL 5
#define FAILURE_ITERATION 12
#define FAILURE_RANK 1
#define VECTOR_SIZE 10000
#define MANIFEST "checkpoint.commit"
#define FAILURE_MARKER "failure_once.flag"

typedef struct {
    int rank;
    int processes;
    int next_iteration;
    double partial_sum;
} State;

static void checkpoint_name(char *name, size_t size, int rank)
{
    snprintf(name, size, "checkpoint_rank_%d.bin", rank);
}

static int has_argument(int argc, char **argv, const char *value)
{
    for (int i = 1; i < argc; i++)
        if (strcmp(argv[i], value) == 0) return 1;
    return 0;
}

static double compute_vector_sum(int rank, int iteration)
{
    double sum = 0.0;
    for (int i = 0; i < VECTOR_SIZE; i++) {
        double a = (rank + 1) * 0.5 + i * 0.001;
        double b = (iteration + 1) * 0.25 + i * 0.002;
        sum += a + b;
    }
    return sum;
}

static int save_state(const State *state)
{
    char name[64];
    checkpoint_name(name, sizeof(name), state->rank);
    FILE *file = fopen(name, "wb");
    if (file == NULL) return 0;
    int ok = fwrite(state, sizeof(State), 1, file) == 1;
    if (fclose(file) != 0) ok = 0;
    return ok;
}

static int load_state(State *state, int rank, int processes,
                      int committed_iteration)
{
    char name[64];
    checkpoint_name(name, sizeof(name), rank);
    FILE *file = fopen(name, "rb");
    if (file == NULL) return 0;
    int ok = fread(state, sizeof(State), 1, file) == 1;
    fclose(file);
    return ok && state->rank == rank && state->processes == processes &&
           state->next_iteration == committed_iteration;
}

static int read_manifest(int *iteration, int *processes)
{
    FILE *file = fopen(MANIFEST, "r");
    if (file == NULL) return 0;
    int ok = fscanf(file, "%d %d", iteration, processes) == 2;
    fclose(file);
    return ok;
}

static int write_manifest(int iteration, int processes)
{
    FILE *file = fopen(MANIFEST, "w");
    if (file == NULL) return 0;
    int ok = fprintf(file, "%d %d\n", iteration, processes) > 0;
    if (fclose(file) != 0) ok = 0;
    return ok;
}

static void coordinated_checkpoint(const State *state, int rank)
{
    MPI_Barrier(MPI_COMM_WORLD);
    int local_ok = save_state(state);
    int global_ok = 0;
    MPI_Allreduce(&local_ok, &global_ok, 1, MPI_INT, MPI_MIN,
                  MPI_COMM_WORLD);
    if (!global_ok) {
        if (rank == 0) fprintf(stderr, "Error guardando checkpoints locales.\n");
        MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
    }

    MPI_Barrier(MPI_COMM_WORLD);
    int manifest_ok = rank == 0
        ? write_manifest(state->next_iteration, state->processes) : 1;
    MPI_Bcast(&manifest_ok, 1, MPI_INT, 0, MPI_COMM_WORLD);
    if (!manifest_ok) MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);

    MPI_Barrier(MPI_COMM_WORLD);
    printf("[Rango %d] Checkpoint coordinado: iteracion %d, suma %.3f\n",
           rank, state->next_iteration, state->partial_sum);
    fflush(stdout);
}

static void clean_previous_files(int processes)
{
    remove(MANIFEST);
    remove(FAILURE_MARKER);
    for (int rank = 0; rank < processes; rank++) {
        char name[64];
        checkpoint_name(name, sizeof(name), rank);
        remove(name);
    }
}

int main(int argc, char **argv)
{
    MPI_Init(&argc, &argv);

    int rank, processes;
    MPI_Comm_rank(MPI_COMM_WORLD, &rank);
    MPI_Comm_size(MPI_COMM_WORLD, &processes);

    if (processes < 3) {
        if (rank == 0) fprintf(stderr, "Se requieren al menos 3 procesos MPI.\n");
        MPI_Finalize();
        return EXIT_FAILURE;
    }

    int reset = has_argument(argc, argv, "--reset");
    int no_fail = has_argument(argc, argv, "--no-fail");
    if (reset && rank == 0) {
        clean_previous_files(processes);
        printf("Ejecucion nueva: archivos anteriores eliminados.\n");
        fflush(stdout);
    }
    MPI_Barrier(MPI_COMM_WORLD);

    int committed_iteration = 0, saved_processes = 0, manifest_exists = 0;
    if (rank == 0)
        manifest_exists = read_manifest(&committed_iteration, &saved_processes);
    MPI_Bcast(&manifest_exists, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Bcast(&committed_iteration, 1, MPI_INT, 0, MPI_COMM_WORLD);
    MPI_Bcast(&saved_processes, 1, MPI_INT, 0, MPI_COMM_WORLD);

    State state = {rank, processes, 0, 0.0};
    if (manifest_exists) {
        int local_ok = saved_processes == processes &&
                       load_state(&state, rank, processes, committed_iteration);
        int global_ok = 0;
        MPI_Allreduce(&local_ok, &global_ok, 1, MPI_INT, MPI_MIN,
                      MPI_COMM_WORLD);
        if (!global_ok) {
            if (rank == 0) fprintf(stderr, "Checkpoint global inconsistente.\n");
            MPI_Abort(MPI_COMM_WORLD, EXIT_FAILURE);
        }
        printf("[Rango %d] Rollback: continua desde iteracion %d, suma %.3f\n",
               rank, state.next_iteration, state.partial_sum);
        fflush(stdout);
    } else {
        if (rank == 0) printf("No existe checkpoint. Inicio desde cero.\n");
        coordinated_checkpoint(&state, rank);
    }

    for (int iteration = state.next_iteration;
         iteration < TOTAL_ITERATIONS; iteration++) {
        state.partial_sum += compute_vector_sum(rank, iteration);
        state.next_iteration = iteration + 1;

        if (state.next_iteration % CHECKPOINT_INTERVAL == 0)
            coordinated_checkpoint(&state, rank);

        int failed_before = access(FAILURE_MARKER, F_OK) == 0;
        if (!no_fail && !failed_before && rank == FAILURE_RANK &&
            state.next_iteration == FAILURE_ITERATION) {
            FILE *marker = fopen(FAILURE_MARKER, "w");
            if (marker != NULL) {
                fprintf(marker, "Fallo del rango %d en iteracion %d\n",
                        rank, state.next_iteration);
                fclose(marker);
            }
            fprintf(stderr, "[Rango %d] FALLO SIMULADO en iteracion %d.\n",
                    rank, state.next_iteration);
            fflush(stderr);
            exit(EXIT_FAILURE);
        }
    }

    double global_sum = 0.0;
    MPI_Reduce(&state.partial_sum, &global_sum, 1, MPI_DOUBLE,
               MPI_SUM, 0, MPI_COMM_WORLD);
    if (rank == 0) {
        printf("Ejecucion recuperada y completada.\n");
        printf("Resultado global: %.3f\n", global_sum);
        printf("Checkpoint final: iteracion %d\n", state.next_iteration);
    }

    MPI_Finalize();
    return EXIT_SUCCESS;
}
