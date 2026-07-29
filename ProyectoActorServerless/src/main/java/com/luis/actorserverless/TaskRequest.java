package com.luis.actorserverless;

import java.util.List;

/**
 * Representa el trabajo recibido desde el endpoint HTTP.
 *
 * @param operation operación solicitada: sum, uppercase, reverse o fail
 * @param numbers números utilizados por la operación sum
 * @param text texto utilizado por uppercase y reverse
 */
public record TaskRequest(
        String operation,
        List<Double> numbers,
        String text
) {
    /**
     * Normaliza la operación para que el resto del sistema no dependa
     * de mayúsculas, minúsculas o espacios accidentales.
     */
    public String normalizedOperation() {
        // Cuando la operación no existe se devuelve una cadena vacía.
        if (operation == null) {
            return "";
        }

        // trim elimina espacios y toLowerCase unifica el protocolo.
        return operation.trim().toLowerCase();
    }
}
