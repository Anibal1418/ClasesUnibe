package com.luis.hybrid.model;

import java.nio.file.Path;

/** Configuración externa para evitar valores de infraestructura dentro del código. */
public record ServiceConfig(
        String gpuServiceUrl,
        String sparkFunctionUrl,
        String dataBucket,
        Path localDataDir,
        int maxInputValues,
        int maxHttpRetries,
        int resultPollSeconds,
        int maxResultPolls
) {
    public static ServiceConfig fromEnvironment() {
        return new ServiceConfig(
                required("GPU_SERVICE_URL", "http://localhost:8081"),
                required("SPARK_FUNCTION_URL", "http://localhost:8082"),
                System.getenv().getOrDefault("DATA_BUCKET", "").trim(),
                Path.of(System.getenv().getOrDefault("LOCAL_DATA_DIR", "/tmp/hybrid-bigdata")),
                integer("MAX_INPUT_VALUES", 2_000_000),
                integer("MAX_HTTP_RETRIES", 3),
                integer("RESULT_POLL_SECONDS", 2),
                integer("MAX_RESULT_POLLS", 900)
        );
    }

    private static String required(String name, String fallback) {
        return System.getenv().getOrDefault(name, fallback).replaceAll("/+$", "");
    }

    private static int integer(String name, int fallback) {
        try {
            return Integer.parseInt(System.getenv().getOrDefault(name, String.valueOf(fallback)));
        } catch (NumberFormatException ignored) {
            return fallback;
        }
    }
}
