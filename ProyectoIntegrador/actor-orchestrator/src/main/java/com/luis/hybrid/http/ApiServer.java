package com.luis.hybrid.http;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.luis.hybrid.actors.OrchestratorActor;
import com.luis.hybrid.model.ProcessingRequest;
import com.luis.hybrid.model.WorkflowResponse;
import com.luis.hybrid.storage.JobStore;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import org.apache.pekko.actor.typed.ActorSystem;
import org.apache.pekko.actor.typed.javadsl.AskPattern;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;

/** Servidor HTTP mínimo, sin estado compartido mutable con los actores. */
public final class ApiServer {
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private ApiServer() {}

    public static HttpServer start(
            ActorSystem<OrchestratorActor.Command> system,
            JobStore store,
            int port
    ) throws IOException {
        HttpServer server = HttpServer.create(new InetSocketAddress(port), 0);
        server.setExecutor(Executors.newVirtualThreadPerTaskExecutor());

        server.createContext("/health", exchange -> {
            if (!"GET".equalsIgnoreCase(exchange.getRequestMethod())) {
                send(exchange, 405, error("Utilice GET"));
                return;
            }
            ObjectNode payload = MAPPER.createObjectNode();
            payload.put("status", "ok");
            payload.put("actor_system", system.name());
            send(exchange, 200, payload);
        });

        server.createContext("/process", exchange -> {
            if (!"POST".equalsIgnoreCase(exchange.getRequestMethod())) {
                send(exchange, 405, error("Utilice POST"));
                return;
            }

            try {
                ProcessingRequest request = MAPPER.readValue(
                        exchange.getRequestBody(),
                        ProcessingRequest.class
                );

                WorkflowResponse response = AskPattern.ask(
                        system,
                        (org.apache.pekko.actor.typed.ActorRef<WorkflowResponse> replyTo) ->
                                new OrchestratorActor.Start(request, replyTo),
                        Duration.ofMinutes(55),
                        system.scheduler()
                ).toCompletableFuture().get(56, TimeUnit.MINUTES);

                int status = "completed".equals(response.status()) ? 200 : 500;
                send(exchange, status, MAPPER.valueToTree(response));
            } catch (Exception exception) {
                send(exchange, 400, error("Solicitud inválida: " + exception.getMessage()));
            }
        });

        server.createContext("/results", exchange -> {
            if (!"GET".equalsIgnoreCase(exchange.getRequestMethod())) {
                send(exchange, 405, error("Utilice GET"));
                return;
            }
            String path = exchange.getRequestURI().getPath();
            String prefix = "/results/";
            if (!path.startsWith(prefix) || path.length() <= prefix.length()) {
                send(exchange, 400, error("Utilice /results/{jobId}"));
                return;
            }
            String jobId = path.substring(prefix.length());
            JsonNode result = store.readFinal(jobId);
            if (result == null) {
                send(exchange, 404, error("Resultado no encontrado"));
                return;
            }
            send(exchange, 200, result);
        });

        server.start();
        return server;
    }

    private static ObjectNode error(String message) {
        ObjectNode payload = MAPPER.createObjectNode();
        payload.put("status", "error");
        payload.put("error", message);
        return payload;
    }

    private static void send(HttpExchange exchange, int status, JsonNode payload)
            throws IOException {
        byte[] body = MAPPER.writerWithDefaultPrettyPrinter()
                .writeValueAsString(payload)
                .getBytes(StandardCharsets.UTF_8);
        exchange.getResponseHeaders().set("Content-Type", "application/json; charset=utf-8");
        exchange.sendResponseHeaders(status, body.length);
        exchange.getResponseBody().write(body);
        exchange.close();
    }
}
