package com.luis.hybrid.actors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.luis.hybrid.clients.HttpJsonClient;
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

/** Actor responsable de enviar el batch Spark serverless. */
public final class SparkSubmissionActor extends AbstractBehavior<SparkSubmissionActor.Command> {
    public interface Command {}
    public interface Result {}

    public record Submit(
            String jobId,
            String inputUri,
            String outputUri,
            int repetitions,
            ActorRef<Result> replyTo
    ) implements Command {}

    public record Submitted(String batchId, String outputUri, JsonNode payload) implements Result {}
    public record Failed(String error) implements Result {}

    private record Attempt(String jobId, int number) implements Command {}
    private record HttpCompleted(
            String jobId,
            int attempt,
            HttpJsonClient.HttpResult response,
            Throwable error
    ) implements Command {}

    private record Pending(
            String inputUri,
            String outputUri,
            int repetitions,
            ActorRef<Result> replyTo
    ) {}

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final ServiceConfig config;
    private final HttpJsonClient http = new HttpJsonClient();
    private final Map<String, Pending> pending = new HashMap<>();

    public static Behavior<Command> create(ServiceConfig config) {
        return Behaviors.setup(context -> new SparkSubmissionActor(context, config));
    }

    private SparkSubmissionActor(ActorContext<Command> context, ServiceConfig config) {
        super(context);
        this.config = config;
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Submit.class, this::onSubmit)
                .onMessage(Attempt.class, this::onAttempt)
                .onMessage(HttpCompleted.class, this::onHttpCompleted)
                .build();
    }

    private Behavior<Command> onSubmit(Submit message) {
        pending.put(
                message.jobId(),
                new Pending(
                        message.inputUri(),
                        message.outputUri(),
                        message.repetitions(),
                        message.replyTo()
                )
        );
        getContext().getSelf().tell(new Attempt(message.jobId(), 0));
        return this;
    }

    private Behavior<Command> onAttempt(Attempt message) {
        Pending work = pending.get(message.jobId());
        if (work == null) {
            return this;
        }

        ObjectNode payload = MAPPER.createObjectNode();
        payload.put("action", "submit");
        payload.put("job_id", message.jobId());
        payload.put("input_uri", work.inputUri());
        payload.put("output_uri", work.outputUri());
        payload.put("repetitions", work.repetitions());

        getContext().pipeToSelf(
                http.post(config.sparkFunctionUrl(), payload),
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
            JsonNode body = message.response().body();
            String batchId = body.path("batch_id").asText();
            if (!batchId.isBlank()) {
                pending.remove(message.jobId());
                work.replyTo().tell(new Submitted(batchId, work.outputUri(), body));
                return this;
            }
        }

        if (message.attempt() < config.maxHttpRetries()) {
            int nextAttempt = message.attempt() + 1;
            long delayMillis = 750L * (1L << Math.min(nextAttempt, 6));
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
                : String.valueOf(message.response() == null ? "sin respuesta" : message.response().body());
        work.replyTo().tell(new Failed("No se pudo enviar el batch Spark: " + error));
        return this;
    }
}
