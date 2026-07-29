package com.luis.hybrid.clients;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.concurrent.CompletionStage;

/** Cliente asíncrono común para los servicios serverless. */
public final class HttpJsonClient {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final HttpClient client;

    public record HttpResult(int statusCode, JsonNode body) {
        public boolean successful() {
            return statusCode >= 200 && statusCode < 300;
        }
    }

    public HttpJsonClient() {
        this.client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(20))
                .build();
    }

    public CompletionStage<HttpResult> post(String url, JsonNode payload) {
        try {
            HttpRequest request = HttpRequest.newBuilder(URI.create(url))
                    .timeout(Duration.ofMinutes(5))
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(MAPPER.writeValueAsString(payload)))
                    .build();

            return client.sendAsync(request, HttpResponse.BodyHandlers.ofString())
                    .thenApply(response -> new HttpResult(
                            response.statusCode(),
                            parseBody(response.body())
                    ));
        } catch (Exception exception) {
            return java.util.concurrent.CompletableFuture.failedStage(exception);
        }
    }

    private JsonNode parseBody(String body) {
        try {
            return MAPPER.readTree(body);
        } catch (Exception exception) {
            ObjectNode fallback = MAPPER.createObjectNode();
            fallback.put("raw_body", body);
            return fallback;
        }
    }
}
