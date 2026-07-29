package com.luis.hybrid.actors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.luis.hybrid.clients.HttpJsonClient;
import com.luis.hybrid.model.ProcessingRequest;
import com.luis.hybrid.model.ServiceConfig;
import org.apache.pekko.actor.typed.ActorRef;
import org.apache.pekko.actor.typed.Behavior;
import org.apache.pekko.actor.typed.javadsl.AbstractBehavior;
import org.apache.pekko.actor.typed.javadsl.ActorContext;
import org.apache.pekko.actor.typed.javadsl.Behaviors;
import org.apache.pekko.actor.typed.javadsl.Receive;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

/** Actor que despacha la etapa CUDA/OpenMP y reintenta fallos HTTP transitorios. */
public final class GpuStageActor extends AbstractBehavior<GpuStageActor.Command> {
    public interface Command {}
    public interface Result {}

    public record Normalize(
            String jobId,
            ProcessingRequest request,
            ActorRef<Result> replyTo
    ) implements Command {}

    public record Completed(JsonNode payload) implements Result {}
    public record Failed(String error) implements Result {}

    private record Attempt(String jobId, int number) implements Command {}
    private record HttpCompleted(
            String jobId,
            int attempt,
            HttpJsonClient.HttpResult response,
            Throwable error
    ) implements Command {}

    private record Pending(
            ProcessingRequest request,
            ActorRef<Result> replyTo
    ) {}

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final ServiceConfig config;
    private final HttpJsonClient http;
    private final Map<String, Pending> pending = new HashMap<>();

    public static Behavior<Command> create(ServiceConfig config) {
        return Behaviors.setup(context -> new GpuStageActor(context, config));
    }

    private GpuStageActor(ActorContext<Command> context, ServiceConfig config) {
        super(context);
        this.config = config;
        this.http = new HttpJsonClient();
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Normalize.class, this::onNormalize)
                .onMessage(Attempt.class, this::onAttempt)
                .onMessage(HttpCompleted.class, this::onHttpCompleted)
                .build();
    }

    private Behavior<Command> onNormalize(Normalize message) {
        pending.put(message.jobId(), new Pending(message.request(), message.replyTo()));
        getContext().getSelf().tell(new Attempt(message.jobId(), 0));
        return this;
    }

    private Behavior<Command> onAttempt(Attempt message) {
        Pending work = pending.get(message.jobId());
        if (work == null) {
            return this;
        }

        ObjectNode payload = MAPPER.createObjectNode();
        payload.set("values", MAPPER.valueToTree(work.request().values()));
        payload.put("engine", work.request().safeEngine());
        payload.put("persist", true);
        payload.put("job_id", message.jobId());

        getContext().getLog().info(
                "job={} stage=gpu-dispatch attempt={} event=request",
                message.jobId(),
                message.number()
        );

        getContext().pipeToSelf(
                http.post(config.gpuServiceUrl() + "/normalize", payload),
                (response, error) -> new HttpCompleted(
                        message.jobId(),
                        message.number(),
                        response,
                        error
                )
        );
        return this;
    }

    private Behavior<Command> onHttpCompleted(HttpCompleted message) {
        Pending work = pending.get(message.jobId());
        if (work == null) {
            return this;
        }

        if (message.error() == null && message.response() != null && message.response().successful()) {
            pending.remove(message.jobId());
            work.replyTo().tell(new Completed(message.response().body()));
            return this;
        }

        if (message.attempt() < config.maxHttpRetries()) {
            int nextAttempt = message.attempt() + 1;
            long delayMillis = 500L * (1L << Math.min(nextAttempt, 6));
            getContext().getLog().warn(
                    "job={} stage=gpu-dispatch attempt={} event=retry delay_ms={}",
                    message.jobId(),
                    nextAttempt,
                    delayMillis
            );
            getContext().scheduleOnce(
                    Duration.ofMillis(delayMillis),
                    getContext().getSelf(),
                    new Attempt(message.jobId(), nextAttempt)
            );
            return this;
        }

        pending.remove(message.jobId());
        String error = message.error() != null
                ? message.error().getMessage()
                : message.response().body().toString();
        work.replyTo().tell(new Failed("La etapa GPU/OpenMP falló: " + error));
        return this;
    }
}
