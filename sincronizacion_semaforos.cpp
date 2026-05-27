#include <iostream>
#include <pthread.h>
#include <semaphore.h>
#include <vector>
#include <string>

const int NUM_HILOS = 5;
const int INCREMENTOS_POR_HILO = 1000;

int contador_compartido = 0;
sem_t semaforo;
bool modo_seguro = true;

void* incrementar(void* arg) {
    long id = reinterpret_cast<long>(arg);

    for (int i = 0; i < INCREMENTOS_POR_HILO; ++i) {
        if (modo_seguro) {
            // Seccion de entrada: el hilo espera permiso.
            sem_wait(&semaforo);

            // Seccion critica: solo un hilo puede modificar el contador.
            contador_compartido++;

            // Seccion de salida: el hilo libera el recurso compartido.
            sem_post(&semaforo);
        } else {
            // Modo sin sincronizacion. Puede producir condicion de carrera.
            contador_compartido++;
        }
    }

    std::cout << "Hilo " << id << " termino sus incrementos." << std::endl;
    return nullptr;
}

int main(int argc, char* argv[]) {
    if (argc > 1 && std::string(argv[1]) == "--unsafe") {
        modo_seguro = false;
        std::cout << "Modo: SIN sincronizacion. Resultado puede ser incorrecto.\n";
    } else {
        modo_seguro = true;
        std::cout << "Modo: CON sincronizacion usando semaforo POSIX.\n";
    }

    contador_compartido = 0;
    int esperado = NUM_HILOS * INCREMENTOS_POR_HILO;

    if (modo_seguro) {
        // Semaforo anonimo compartido entre hilos del mismo proceso.
        // pshared = 0 indica uso entre hilos; valor inicial = 1 lo hace binario.
        if (sem_init(&semaforo, 0, 1) != 0) {
            std::cerr << "Error al inicializar el semaforo." << std::endl;
            return 1;
        }
    }

    std::vector<pthread_t> hilos(NUM_HILOS);

    for (long i = 0; i < NUM_HILOS; ++i) {
        if (pthread_create(&hilos[i], nullptr, incrementar, reinterpret_cast<void*>(i + 1)) != 0) {
            std::cerr << "Error al crear el hilo " << i + 1 << std::endl;
            return 1;
        }
    }

    for (int i = 0; i < NUM_HILOS; ++i) {
        pthread_join(hilos[i], nullptr);
    }

    if (modo_seguro) {
        sem_destroy(&semaforo);
    }

    std::cout << "\nValor final del contador: " << contador_compartido << std::endl;
    std::cout << "Valor esperado: " << esperado << std::endl;

    if (contador_compartido == esperado) {
        std::cout << "Resultado correcto: no se perdieron incrementos." << std::endl;
    } else {
        std::cout << "Resultado incorrecto: hubo condicion de carrera." << std::endl;
    }

    return 0;
}
