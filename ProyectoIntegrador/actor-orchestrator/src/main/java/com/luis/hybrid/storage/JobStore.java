package com.luis.hybrid.storage;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.google.cloud.storage.Blob;
import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

/** Persistencia durable de resultados finales y lectura de la salida de Spark. */
public final class JobStore {
    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final String bucket;
    private final Path localRoot;
    private final Storage storage;

    public JobStore(String bucket, Path localRoot) {
        this.bucket = bucket == null ? "" : bucket.trim();
        this.localRoot = localRoot;
        this.storage = this.bucket.isBlank() ? null : StorageOptions.getDefaultInstance().getService();
    }

    public String resultUri(String jobId) {
        if (!bucket.isBlank()) {
            return "gs://" + bucket + "/spark-results/" + jobId;
        }
        return localRoot.resolve("spark-results").resolve(jobId).toString();
    }

    public void writeFinal(String jobId, JsonNode payload) {
        try {
            byte[] bytes = MAPPER.writerWithDefaultPrettyPrinter().writeValueAsBytes(payload);
            if (!bucket.isBlank()) {
                storage.create(
                        BlobInfo.newBuilder(BlobId.of(bucket, "results/" + jobId + ".json"))
                                .setContentType("application/json")
                                .build(),
                        bytes
                );
                return;
            }
            Path destination = localRoot.resolve("results").resolve(jobId + ".json");
            Files.createDirectories(destination.getParent());
            Files.write(destination, bytes);
        } catch (Exception exception) {
            throw new IllegalStateException("No se pudo persistir el resultado", exception);
        }
    }

    public JsonNode readFinal(String jobId) {
        try {
            byte[] bytes;
            if (!bucket.isBlank()) {
                Blob blob = storage.get(BlobId.of(bucket, "results/" + jobId + ".json"));
                if (blob == null) {
                    return null;
                }
                bytes = blob.getContent();
            } else {
                Path source = localRoot.resolve("results").resolve(jobId + ".json");
                if (!Files.exists(source)) {
                    return null;
                }
                bytes = Files.readAllBytes(source);
            }
            return MAPPER.readTree(bytes);
        } catch (Exception exception) {
            throw new IllegalStateException("No se pudo leer el resultado", exception);
        }
    }

    public JsonNode readSparkResult(String outputUri) {
        try {
            if (outputUri.startsWith("gs://")) {
                String withoutScheme = outputUri.substring(5);
                int slash = withoutScheme.indexOf('/');
                String outputBucket = withoutScheme.substring(0, slash);
                String prefix = withoutScheme.substring(slash + 1).replaceAll("/+$", "") + "/result/part-";
                for (Blob blob : storage.list(outputBucket, Storage.BlobListOption.prefix(prefix)).iterateAll()) {
                    if (!blob.getName().endsWith(".crc")) {
                        String json = new String(blob.getContent(), StandardCharsets.UTF_8).trim();
                        return MAPPER.readTree(json);
                    }
                }
                throw new IllegalStateException("Spark no produjo un archivo part en " + outputUri);
            }

            Path resultDirectory = Path.of(outputUri).resolve("result");
            try (var files = Files.list(resultDirectory)) {
                Path part = files
                        .filter(path -> path.getFileName().toString().startsWith("part-"))
                        .findFirst()
                        .orElseThrow(() -> new IllegalStateException("No existe salida part de Spark"));
                return MAPPER.readTree(Files.readString(part).trim());
            }
        } catch (Exception exception) {
            throw new IllegalStateException("No se pudo leer la salida de Spark", exception);
        }
    }
}
