package com.luis.actorserverless;

import akka.actor.typed.ActorRef;
import akka.actor.typed.Behavior;
import akka.actor.typed.PreRestart;
import akka.actor.typed.javadsl.AbstractBehavior;
import akka.actor.typed.javadsl.ActorContext;
import akka.actor.typed.javadsl.Behaviors;
import akka.actor.typed.javadsl.Receive;

/**
 * Actor worker aislado que procesa una tarea por mensaje.
 * El actor no comparte estado mutable con otros workers.
 */
public final class WorkerActor extends AbstractBehavior<WorkerActor.Command> {

    /** Protocolo base aceptado por el worker. */
    public interface Command {}

    /**
     * Mensaje de trabajo enviado por el supervisor.
     * replyTo indica a qué actor debe enviarse el resultado.
     */
    public record Work(
            String requestId,
            TaskRequest task,
            ActorRef<SupervisorActor.TaskResult> replyTo
    ) implements Command {}

    /** Identificador estable para facilitar la trazabilidad en los logs. */
    private final int workerId;

    /** Contador local que se reinicia cuando Akka reinicia este actor. */
    private int processedCount;

    /** Fábrica pública del comportamiento del worker. */
    public static Behavior<Command> create(int workerId) {
        // Behaviors.setup entrega el contexto cuando el actor comienza.
        return Behaviors.setup(context -> new WorkerActor(context, workerId));
    }

    /** Constructor privado para obligar a crear el actor mediante create. */
    private WorkerActor(ActorContext<Command> context, int workerId) {
        // Inicializa AbstractBehavior con el contexto administrado por Akka.
        super(context);

        // Guarda el identificador asignado por el supervisor.
        this.workerId = workerId;

        // El estado comienza en cero en cada creación o reinicio.
        this.processedCount = 0;

        // Registra que el actor está disponible.
        getContext().getLog().info("worker-{} iniciado; contador={}", workerId, processedCount);
    }

    /** Declara qué mensajes y señales procesa el actor. */
    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                // Work activa la lógica principal.
                .onMessage(Work.class, this::onWork)
                // PreRestart permite registrar la acción de supervisión.
                .onSignal(PreRestart.class, signal -> onPreRestart())
                .build();
    }

    /** Procesa una tarea sin bloquear ni acceder al estado de otro actor. */
    private Behavior<Command> onWork(Work message) {
        // Incrementa estado estrictamente local al actor.
        processedCount++;

        // Normaliza la operación recibida.
        String operation = message.task().normalizedOperation();

        // Registra la recepción del mensaje.
        getContext().getLog().info(
                "worker-{} procesa requestId={} operación={} contador={}",
                workerId,
                message.requestId(),
                operation,
                processedCount
        );

        // La operación fail simula una excepción no recuperable dentro del mensaje actual.
        if ("fail".equals(operation)) {
            getContext().getLog().error(
                    "worker-{} provoca fallo intencional requestId={}",
                    workerId,
                    message.requestId()
            );

            // La excepción será interceptada por la estrategia configurada en el supervisor.
            throw new IllegalStateException("Fallo intencional solicitado por la prueba");
        }

        // Calcula el resultado de acuerdo con el protocolo.
        Object result;

        switch (operation) {
            case "sum" -> {
                // Valida que exista por lo menos un número.
                if (message.task().numbers() == null || message.task().numbers().isEmpty()) {
                    message.replyTo().tell(SupervisorActor.TaskResult.failure(
                            message.requestId(),
                            workerName(),
                            "La operación sum requiere el arreglo numbers"
                    ));
                    return this;
                }

                // Suma los valores sin modificar la lista recibida.
                result = message.task().numbers()
                        .stream()
                        .mapToDouble(Double::doubleValue)
                        .sum();
            }
            case "uppercase" -> {
                // Valida el texto requerido.
                if (message.task().text() == null) {
                    message.replyTo().tell(SupervisorActor.TaskResult.failure(
                            message.requestId(),
                            workerName(),
                            "La operación uppercase requiere text"
                    ));
                    return this;
                }

                // Convierte el texto a mayúsculas.
                result = message.task().text().toUpperCase();
            }
            case "reverse" -> {
                // Valida el texto requerido.
                if (message.task().text() == null) {
                    message.replyTo().tell(SupervisorActor.TaskResult.failure(
                            message.requestId(),
                            workerName(),
                            "La operación reverse requiere text"
                    ));
                    return this;
                }

                // Invierte la cadena mediante StringBuilder.
                result = new StringBuilder(message.task().text()).reverse().toString();
            }
            default -> {
                // Responde de forma controlada cuando la operación no pertenece al protocolo.
                message.replyTo().tell(SupervisorActor.TaskResult.failure(
                        message.requestId(),
                        workerName(),
                        "Operación no válida: " + operation
                ));
                return this;
            }
        }

        // Envía el resultado al actor temporal creado por el patrón ask.
        message.replyTo().tell(SupervisorActor.TaskResult.success(
                message.requestId(),
                workerName(),
                result
        ));

        // Conserva el mismo comportamiento para el siguiente mensaje.
        return this;
    }

    /** Registra el reinicio. El mensaje que causó el fallo no se repite automáticamente. */
    private Behavior<Command> onPreRestart() {
        getContext().getLog().warn(
                "worker-{} será reiniciado; contador anterior={}",
                workerId,
                processedCount
        );
        return this;
    }

    /** Construye un nombre legible y estable. */
    private String workerName() {
        return "worker-" + workerId;
    }
}
