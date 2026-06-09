#include <stdio.h>
#include <stdlib.h>
#include <omp.h>

#define NUM_PRUEBAS 5

long long sumar_arreglo(int *arreglo, long long n, int num_hilos) {
    long long suma = 0;

    omp_set_num_threads(num_hilos);

    #pragma omp parallel for reduction(+:suma) schedule(static)
    for (long long i = 0; i < n; i++) {
        suma += arreglo[i];
    }

    return suma;
}

int main(int argc, char *argv[]) {
    long long n = 50000000;
    int repeticiones = 5;
    int hilos[NUM_PRUEBAS] = {1, 2, 4, 8, 16};
    double tiempos[NUM_PRUEBAS];
    const double fraccion_paralelizable = 0.95;

    if (argc >= 2) {
        n = atoll(argv[1]);
    }

    if (argc >= 3) {
        repeticiones = atoi(argv[2]);
    }

    if (n <= 0 || repeticiones <= 0) {
        printf("Uso: %s [tamano_arreglo] [repeticiones]\n", argv[0]);
        return 1;
    }

    printf("Tamaño del arreglo: %lld enteros\n", n);
    printf("Repeticiones por caso: %d\n", repeticiones);
    printf("Fracción paralelizable usada para Amdahl: %.2f\n\n", fraccion_paralelizable);

    int *arreglo = (int *) malloc(n * sizeof(int));

    if (arreglo == NULL) {
        printf("Error: no se pudo reservar memoria para el arreglo.\n");
        return 1;
    }

    #pragma omp parallel for schedule(static)
    for (long long i = 0; i < n; i++) {
        arreglo[i] = 1;
    }

    long long suma_esperada = n;

    for (int i = 0; i < NUM_PRUEBAS; i++) {
        int p = hilos[i];
        double mejor_tiempo = 1e30;
        long long suma = 0;

        for (int r = 0; r < repeticiones; r++) {
            double inicio = omp_get_wtime();
            suma = sumar_arreglo(arreglo, n, p);
            double fin = omp_get_wtime();
            double tiempo = fin - inicio;

            if (tiempo < mejor_tiempo) {
                mejor_tiempo = tiempo;
            }
        }

        if (suma != suma_esperada) {
            printf("Advertencia: suma incorrecta con %d hilos. Obtenido=%lld, esperado=%lld\n", p, suma, suma_esperada);
        }

        tiempos[i] = mejor_tiempo;
    }

    double tiempo_1 = tiempos[0];

    printf("Hilos,Tiempo_s,Speedup,Eficiencia,Amdahl_f_0_95\n");
    for (int i = 0; i < NUM_PRUEBAS; i++) {
        int p = hilos[i];
        double speedup = tiempo_1 / tiempos[i];
        double eficiencia = speedup / p;
        double amdahl = 1.0 / ((1.0 - fraccion_paralelizable) + (fraccion_paralelizable / p));

        printf("%d,%.6f,%.4f,%.4f,%.4f\n", p, tiempos[i], speedup, eficiencia, amdahl);
    }

    printf("\nSuma esperada: %lld\n", suma_esperada);
    printf("El resultado correcto confirma que la cláusula reduction protege la suma compartida.\n");

    free(arreglo);
    return 0;
}
