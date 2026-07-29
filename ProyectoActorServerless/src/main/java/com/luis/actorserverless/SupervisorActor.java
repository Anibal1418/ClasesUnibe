package com.luis.actorserverless;

import akka.actor.typed.ActorRef;
import akka.actor.typed.Behavior;
import akka.actor.typed.SupervisorStrategy;
import akka.actor.typed.javadsl.AbstractBehavior;
import akka.actor.typed.javadsl.ActorContext;
import akka.actor.typed.javadsl.Behaviors;
import akka.actor.typed.javadsl.Receive;

import java.util.ArrayList;
import java.util.List;

/**
 * Actor supervisor que crea workers, distribuye tareas y define la política de reinicio.
 */
public final class SupervisorActor extends AbstractBehavior<SupervisorActor.Command> {

    /** Protocolo aceptado por el supervisor. */
    public interface Command {}

    /** Mensaje enviado por Lambda al supervisor mediante el patrón ask. */
    public record ProcessTask(
            String requestId,
            TaskRequest task,
            ActorRef<TaskResult> replyTo
    ) implements Command {}

    /** Resultado común enviado por un worker. */
    public record TaskResult(
            String requestId,
            String worker,
            boolean success,
            Object result,
            String error
    ) {
        /** Crea una respuesta exitosa. */
        public static TaskResult success(String requestId, String worker, Object result) {
            return new TaskResult(requestId, worker, true, result, null);
        }

        /** Crea una respuesta de validación o negocio fallida. */
        public static TaskResult failure(String requestId, String worker, String error) {
            return new TaskResult(requestId, worker, false, null, error);
        }
    }

    /** Referencias a los actores hijos administrados. */
    private final List<ActorRef<WorkerActor.Command>> workers;

    /** Índice utilizado para distribuir tareas en round-robin. */
    private int nextWorker;

    /** Fábrica del supervisor. */
    public static Behavior<Command> create(int workerCount) {
        return Behaviors.setup(context -> new SupervisorActor(context, workerCount));
    }

    /** Crea el grupo de workers y aplica la estrategia de reinicio. */
    private SupervisorActor(ActorContext<Command> context, int workerCount) {
        super(context);

        // Evita crear un supervisor sin capacidad de procesamiento.
        int safeWorkerCount = Math.max(1, workerCount);

        // Reserva la lista de referencias a actores.
        this.workers = new ArrayList<>(safeWorkerCount);

        // El primer mensaje se entrega al worker cero.
        this.nextWorker = 0;

        // Crea cada worker como hijo directo del supervisor.
        for (int workerId = 0; workerId < safeWorkerCount; workerId++) {
            // Envuelve el comportamiento con una estrategia de reinicio.
            Behavior<WorkerActor.Command> supervisedWorker = Behaviors
                    .supervise(WorkerActor.create(workerId))
                    .onFailure(
                            IllegalStateException.class,
                            SupervisorStrategy.restart()
                    );

            // context.spawn establece la relación padre-hijo.
            ActorRef<WorkerActor.Command> workerRef = context.spawn(
                    supervisedWorker,
                    "worker-" + workerId
            );

            // Conserva la referencia para despachar trabajo posteriormente.
            workers.add(workerRef);
        }

        context.getLog().info("Supervisor iniciado con {} workers", safeWorkerCount);
    }

    /** Declara el manejador del protocolo del supervisor. */
    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(ProcessTask.class, this::onProcessTask)
                .build();
    }

    /** Distribuye una tarea al siguiente worker sin ejecutar el trabajo directamente. */
    private Behavior<Command> onProcessTask(ProcessTask message) {
        // Selecciona el siguiente actor según round-robin.
        ActorRef<WorkerActor.Command> selectedWorker = workers.get(nextWorker);

        // Avanza el índice y vuelve a cero al llegar al final.
        nextWorker = (nextWorker + 1) % workers.size();

        // Envía el mensaje sin llamar métodos ni compartir memoria con el worker.
        selectedWorker.tell(new WorkerActor.Work(
                message.requestId(),
                message.task(),
                message.replyTo()
        ));

        // El supervisor queda disponible para recibir otra solicitud.
        return this;
    }
}
