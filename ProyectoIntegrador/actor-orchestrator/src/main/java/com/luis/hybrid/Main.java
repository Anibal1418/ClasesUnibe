package com.luis.hybrid;

import com.luis.hybrid.actors.OrchestratorActor;
import com.luis.hybrid.http.ApiServer;
import com.luis.hybrid.model.ServiceConfig;
import com.luis.hybrid.storage.JobStore;
import org.apache.pekko.actor.typed.ActorSystem;

/** Punto de entrada del orquestador serverless basado en actores. */
public final class Main {
    private Main() {}

    public static void main(String[] args) throws Exception {
        ServiceConfig config = ServiceConfig.fromEnvironment();
        JobStore store = new JobStore(config.dataBucket(), config.localDataDir());
        ActorSystem<OrchestratorActor.Command> system = ActorSystem.create(
                OrchestratorActor.create(config, store),
                "hybrid-bigdata-actor-system"
        );

        int port = readPort();
        ApiServer.start(system, store, port);
        system.log().info("Orquestador iniciado en el puerto {}", port);

        Runtime.getRuntime().addShutdownHook(new Thread(system::terminate));
    }

    private static int readPort() {
        try {
            return Integer.parseInt(System.getenv().getOrDefault("PORT", "8080"));
        } catch (NumberFormatException ignored) {
            return 8080;
        }
    }
}
