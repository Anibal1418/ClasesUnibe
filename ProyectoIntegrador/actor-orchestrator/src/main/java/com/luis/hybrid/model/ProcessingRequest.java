package com.luis.hybrid.model;

import java.util.List;

/** Petición completa recibida por el endpoint principal. */
public record ProcessingRequest(
        List<Double> values,
        String engine,
        Integer sparkRepetitions
) {
    public String safeEngine() {
        return engine == null || engine.isBlank() ? "both" : engine.trim().toLowerCase();
    }

    public int safeRepetitions() {
        return sparkRepetitions == null ? 3 : Math.max(1, sparkRepetitions);
    }
}
