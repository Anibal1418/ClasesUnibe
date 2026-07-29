package com.luis.hybrid.actors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.luis.hybrid.clients.HttpJsonClient;
import com.luis.hybrid.model.ServiceConfig;
import com.luis.hybrid.storage.JobStore;
import org.apache.pekko.actor.typed.ActorRef;
import org.apache.pekko.actor.typed.Behavior;
import org.apache.pekko.actor.typed.javadsl.AbstractBehavior;
import org.apache.pekko.actor.typed.javadsl.ActorContext;
import org.apache.pekko.actor.typed.javadsl.Behaviors;
import org.apache.pekko.actor.typed.javadsl.Receive;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/** Actor que consulta el estado del batch y carga las métricas persistidas por Spark. */
public final class ResultAnalysisActor extends AbstractBehavior<ResultAnalysisActor.Command> {
    public interface Command {}
    public interface Result {}

    public record Collect(
            String jobId,
            String batchId,
            String outputUri,
            ActorRef<Result> replyTo
    ) implements Command {}

    public record Completed(JsonNode metrics, JsonNode finalStatus) implements Result {}
    public record Failed(String error) implements Result {}

    private record Poll(String jobId, int count) implements Command {}
    private record StatusCompleted(
            String jobId,
            int pollCount,
            HttpJsonClient.HttpResult response,
            Throwable error
    ) implements Command {}
    private record SparkResultLoaded(
            String jobId,
            JsonNode metrics,
            JsonNode status,
            Throwable error
    ) implements Command {}

    private record Pending(
            String batchId,
            String outputUri,
            ActorRef<Result> replyTo
    ) {}

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final ServiceConfig config;
    private final JobStore store;
    private final HttpJsonClient http = new HttpJsonClient();
    private final Map<String, Pending> pending = new HashMap<>();

    public static Behavior<Command> create(ServiceConfig config, JobStore store) {
        return Behaviors.setup(context -> new ResultAnalysisActor(context, config, store));
    }

    private ResultAnalysisActor(
            ActorContext<Command> context,
            ServiceConfig config,
            JobStore store
    ) {
        super(context);
        this.config = config;
        this.store = store;
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Collect.class, this::onCollect)
                .onMessage(Poll.class, this::onPoll)
                .onMessage(StatusCompleted.class, this::onStatusCompleted)
                .onMessage(SparkResultLoaded.class, this::onSparkResultLoaded)
                .build();
    }

    private Behavior<Command> onCollect(Collect message) {
        pending.put(
                message.jobId(),
                new Pending(message.batchId(), message.outputUri(), message.replyTo())
        );
        getContext().getSelf().tell(new Poll(message.jobId(), 0));
        return this;
    }

    private Behavior<Command> onPoll(Poll message) {
        Pending work = pending.get(message.jobId());
        if (work == null) {
            return this;
        }

        ObjectNode payload = MAPPER.createObjectNode();
        payload.put("action", "status");
        payload.put("batch_id", work.batchId());
        payload.put("output_uri", work.outputUri());

        getContext().pipeToSelf(
                http.post(config.sparkFunctionUrl(), payload),
                (response, error) -> new StatusCompleted(
                        message.jobId(),
                        message.count(),
                        response,
                        error
                )
        );
        return this;
    }

    private Behavior<Command> onStatusCompleted(StatusCompleted message) {
        Pending work = pending.get(message.jobId());
        if (work == null) {
            return this;
        }

        if (message.error() != null || message.response() == null || !message.response().successful()) {
            if (message.pollCount() < config.maxHttpRetries()) {
                scheduleNext(message.jobId(), message.pollCount() + 1);
                return this;
            }
            pending.remove(message.jobId());
            String error = message.error() != null
                    ? message.error().getMessage()
                    : String.valueOf(message.response() == null ? "sin respuesta" : message.response().body());
            work.replyTo().tell(new Failed("No se pudo consultar Spark: " + error));
            return this;
        }

        JsonNode status = message.response().body();
        String state = status.path("state").asText("UNKNOWN");
        getContext().getLog().info(
                "job={} stage=spark-result batch={} state={} poll={}",
                message.jobId(),
                work.batchId(),
                state,
                message.pollCount()
        );

        if ("SUCCEEDED".equals(state)) {
            CompletableFuture<JsonNode> loading = CompletableFuture.supplyAsync(
                    () -> store.readSparkResult(work.outputUri())
            );
            getContext().pipeToSelf(
                    loading,
                    (metrics, error) -> new SparkResultLoaded(
                            message.jobId(),
                            metrics,
                            status,
                            error
                    )
            );
            return this;
        }

        if ("FAILED".equals(state) || "CANCELLED".equals(state)) {
            pending.remove(message.jobId());
            work.replyTo().tell(new Failed(
                    "El batch Spark terminó en estado " + state + ": " + status.path("state_message").asText()
            ));
            return this;
        }

        if (message.pollCount() >= config.maxResultPolls()) {
            pending.remove(message.jobId());
            work.replyTo().tell(new Failed("Se agotó el tiempo de espera del batch Spark"));
            return this;
        }

        scheduleNext(message.jobId(), message.pollCount() + 1);
        return this;
    }

    private Behavior<Command> onSparkResultLoaded(SparkResultLoaded message) {
        Pending work = pending.remove(message.jobId());
        if (work == null) {
            return this;
        }
        if (message.error() != null) {
            work.replyTo().tell(new Failed(
                    "Spark terminó, pero no se pudo leer el resultado: " + message.error().getMessage()
            ));
            return this;
        }
        work.replyTo().tell(new Completed(message.metrics(), message.status()));
        return this;
    }

    private void scheduleNext(String jobId, int pollCount) {
        getContext().scheduleOnce(
                Duration.ofSeconds(config.resultPollSeconds()),
                getContext().getSelf(),
                new Poll(jobId, pollCount)
        );
    }
}
