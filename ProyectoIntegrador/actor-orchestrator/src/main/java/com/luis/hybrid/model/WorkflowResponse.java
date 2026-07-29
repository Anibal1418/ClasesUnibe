package com.luis.hybrid.model;

import com.fasterxml.jackson.databind.JsonNode;

/** Respuesta final o error controlado del flujo actor. */
public record WorkflowResponse(
        String jobId,
        String status,
        JsonNode result,
        String error
) {
    public static WorkflowResponse success(String jobId, JsonNode result) {
        return new WorkflowResponse(jobId, "completed", result, null);
    }

    public static WorkflowResponse failure(String jobId, String error) {
        return new WorkflowResponse(jobId, "failed", null, error);
    }
}
