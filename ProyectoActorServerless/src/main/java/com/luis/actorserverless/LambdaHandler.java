package com.luis.actorserverless;

import akka.actor.typed.ActorSystem;
import akka.actor.typed.javadsl.AskPattern;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.CompletionStage;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;

/**
 * Adaptador serverless. API Gateway entrega un evento Map y el handler devuelve
 * una respuesta compatible con Lambda proxy integration.
 */
public final class LambdaHandler
        implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    /** Serializador compartido entre invocaciones del mismo entorno caliente. */
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /** Tiempo máximo permitido para que los actores contesten. */
    private static final Duration ASK_TIMEOUT = Duration.ofSeconds(2);

    /**
     * ActorSystem reutilizable. AWS puede conservar el entorno después de una invocación,
     * por lo que no se crea un sistema nuevo para cada petición.
     */
    private static final ActorSystem<SupervisorActor.Command> ACTOR_SYSTEM =
            ActorSystem.create(
                    SupervisorActor.create(readWorkerCount()),
                    "serverless-actor-system"
            );

    /** Procesa un evento de API Gateway o una invocación directa equivalente. */
    @Override
    public Map<String, Object> handleRequest(
            Map<String, Object> event,
            Context context
    ) {
        // Usa el identificador de AWS cuando existe y un UUID en pruebas locales.
        String requestId = context != null
                ? context.getAwsRequestId()
                : UUID.randomUUID().toString();

        try {
            // Convierte el cuerpo HTTP en el contrato TaskRequest.
            TaskRequest task = readTask(event);

            // Valida la operación antes de enviar el mensaje.
            if (task.normalizedOperation().isBlank()) {
                return httpResponse(400, Map.of(
                        "requestId", requestId,
                        "status", "error",
                        "error", "Debe indicar operation"
                ));
            }

            // ask crea una referencia temporal y devuelve CompletionStage.
            CompletionStage<SupervisorActor.TaskResult> pendingResult = AskPattern.ask(
                    ACTOR_SYSTEM,
                    replyTo -> new SupervisorActor.ProcessTask(
                            requestId,
                            task,
                            replyTo
                    ),
                    ASK_TIMEOUT,
                    ACTOR_SYSTEM.scheduler()
            );

            // API Gateway necesita una respuesta HTTP, por eso se espera con límite estricto.
            SupervisorActor.TaskResult actorResult = pendingResult
                    .toCompletableFuture()
                    .get(2500, TimeUnit.MILLISECONDS);

            // Una validación del worker se comunica como solicitud inválida.
            if (!actorResult.success()) {
                return httpResponse(400, Map.of(
                        "requestId", actorResult.requestId(),
                        "worker", actorResult.worker(),
                        "status", "error",
                        "error", actorResult.error()
                ));
            }

            // Respuesta exitosa con trazabilidad del worker que procesó el mensaje.
            return httpResponse(200, Map.of(
                    "requestId", actorResult.requestId(),
                    "worker", actorResult.worker(),
                    "status", "ok",
                    "result", actorResult.result()
            ));

        } catch (TimeoutException exception) {
            // El fallo intencional reinicia al worker, pero el mensaje original se pierde.
            return httpResponse(500, Map.of(
                    "requestId", requestId,
                    "status", "error",
                    "error", "El worker falló o excedió el tiempo de respuesta; fue reiniciado"
            ));
        } catch (Exception exception) {
            // Evita filtrar detalles internos al cliente HTTP.
            return httpResponse(400, Map.of(
                    "requestId", requestId,
                    "status", "error",
                    "error", "Solicitud JSON inválida: " + exception.getMessage()
            ));
        }
    }

    /** Extrae el cuerpo de API Gateway o acepta un objeto directo en pruebas. */
    private static TaskRequest readTask(Map<String, Object> event)
            throws JsonProcessingException {
        // Obtiene la propiedad body usada por la integración proxy.
        Object body = event.get("body");

        // Cuando body es texto, Jackson interpreta el JSON contenido.
        if (body instanceof String bodyText) {
            return MAPPER.readValue(bodyText, TaskRequest.class);
        }

        // Cuando body ya es un objeto, lo convierte directamente.
        if (body instanceof Map<?, ?> bodyMap) {
            return MAPPER.convertValue(bodyMap, TaskRequest.class);
        }

        // Permite invocar la Lambda directamente con operation en la raíz.
        return MAPPER.convertValue(event, TaskRequest.class);
    }

    /** Construye el contrato obligatorio de una respuesta proxy de API Gateway. */
    private static Map<String, Object> httpResponse(
            int statusCode,
            Map<String, Object> payload
    ) {
        try {
            // LinkedHashMap conserva un orden legible durante las pruebas.
            Map<String, Object> response = new LinkedHashMap<>();

            // Código HTTP devuelto al cliente.
            response.put("statusCode", statusCode);

            // Informa que el body contiene JSON.
            response.put("headers", Map.of("Content-Type", "application/json"));

            // API Gateway espera el cuerpo serializado como String.
            response.put("body", MAPPER.writeValueAsString(payload));

            // El contenido no utiliza codificación Base64.
            response.put("isBase64Encoded", false);

            return response;
        } catch (JsonProcessingException exception) {
            // Esta ruta solo ocurre si el payload no puede serializarse.
            throw new IllegalStateException("No se pudo serializar la respuesta", exception);
        }
    }

    /** Lee la cantidad de workers desde una variable de entorno. */
    private static int readWorkerCount() {
        // Valor por defecto apropiado para el ejercicio.
        String configuredValue = System.getenv().getOrDefault("WORKER_COUNT", "3");

        try {
            // Convierte el valor configurado a entero.
            return Integer.parseInt(configuredValue);
        } catch (NumberFormatException exception) {
            // Mantiene el servicio operativo si la variable contiene un valor inválido.
            return 3;
        }
    }
}
