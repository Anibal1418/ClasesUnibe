package com.luis.actorserverless;

import com.fasterxml.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.Map;

/**
 * Ejecuta el handler sin AWS para validar mensajes, respuestas y reinicio.
 */
public final class LocalDemo {

    /** ObjectMapper únicamente para imprimir la respuesta de forma legible. */
    private static final ObjectMapper MAPPER = new ObjectMapper();

    /** Punto de entrada de la demostración local. */
    public static void main(String[] args) throws Exception {
        // Crea el mismo handler usado por AWS Lambda.
        LambdaHandler handler = new LambdaHandler();

        // Envía una suma válida al worker cero.
        invoke(handler, Map.of(
                "operation", "sum",
                "numbers", List.of(4, 7, 10)
        ));

        // Provoca un fallo intencional en el worker uno.
        invoke(handler, Map.of(
                "operation", "fail"
        ));

        // Continúa procesando en otro worker mientras el fallido se reinicia.
        invoke(handler, Map.of(
                "operation", "uppercase",
                "text", "modelo de actores"
        ));

        // Completa la vuelta de round-robin.
        invoke(handler, Map.of(
                "operation", "reverse",
                "text", "serverless"
        ));

        // Esta petición vuelve al worker uno y demuestra que fue reiniciado.
        invoke(handler, Map.of(
                "operation", "sum",
                "numbers", List.of(20, 22)
        ));

        // Finaliza explícitamente el ActorSystem en la aplicación local.
        // En AWS Lambda no se termina para permitir reutilización del entorno.
        System.exit(0);
    }

    /** Envuelve el objeto como body de API Gateway e imprime la respuesta. */
    private static void invoke(
            LambdaHandler handler,
            Map<String, Object> task
    ) throws Exception {
        // Serializa el cuerpo de la petición HTTP.
        String body = MAPPER.writeValueAsString(task);

        // Simula el evento mínimo de API Gateway.
        Map<String, Object> event = Map.of("body", body);

        // Ejecuta el handler sin Context de AWS.
        Map<String, Object> response = handler.handleRequest(event, null);

        // Imprime una separación visual.
        System.out.println("--------------------------------------------------");

        // Muestra la petición enviada.
        System.out.println("REQUEST  " + body);

        // Muestra la respuesta formateada.
        System.out.println("RESPONSE " + MAPPER.writerWithDefaultPrettyPrinter()
                .writeValueAsString(response));
    }
}
