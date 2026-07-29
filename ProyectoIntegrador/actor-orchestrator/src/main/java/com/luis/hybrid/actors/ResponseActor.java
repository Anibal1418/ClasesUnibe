package com.luis.hybrid.actors;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.luis.hybrid.storage.JobStore;
import org.apache.pekko.actor.typed.ActorRef;
import org.apache.pekko.actor.typed.Behavior;
import org.apache.pekko.actor.typed.javadsl.AbstractBehavior;
import org.apache.pekko.actor.typed.javadsl.ActorContext;
import org.apache.pekko.actor.typed.javadsl.Behaviors;
import org.apache.pekko.actor.typed.javadsl.Receive;

/** Actor final que integra métricas, persiste el resultado y construye la respuesta HTTP. */
public final class ResponseActor extends AbstractBehavior<ResponseActor.Command> {
    public interface Command {}
    public interface Result {}

    public record Build(
            String jobId,
            JsonNode gpuPayload,
            JsonNode sparkMetrics,
            JsonNode sparkStatus,
            double totalElapsedMs,
            ActorRef<Result> replyTo
    ) implements Command {}

    public record Completed(JsonNode payload) implements Result {}
    public record Failed(String error) implements Result {}

    private static final ObjectMapper MAPPER = new ObjectMapper();
    private final JobStore store;

    public static Behavior<Command> create(JobStore store) {
        return Behaviors.setup(context -> new ResponseActor(context, store));
    }

    private ResponseActor(ActorContext<Command> context, JobStore store) {
        super(context);
        this.store = store;
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Build.class, this::onBuild)
                .build();
    }

    private Behavior<Command> onBuild(Build message) {
        try {
            ObjectNode payload = MAPPER.createObjectNode();
            payload.put("job_id", message.jobId());
            payload.put("status", "completed");
            payload.set("preprocessing", message.gpuPayload());
            payload.set("spark", message.sparkMetrics());
            payload.set("spark_batch", message.sparkStatus());
            payload.put("total_serverless_ms", message.totalElapsedMs());

            JsonNode benchmark = message.gpuPayload().path("benchmark");
            ObjectNode summary = payload.putObject("performance_summary");
            summary.set("gpu_vs_cpu_speedup", benchmark.get("speedup_gpu_vs_cpu"));
            summary.set(
                    "dataframe_vs_rdd_speedup",
                    message.sparkMetrics().get("speedup_dataframe_vs_rdd")
            );
            summary.put("total_serverless_ms", message.totalElapsedMs());

            store.writeFinal(message.jobId(), payload);
            message.replyTo().tell(new Completed(payload));
        } catch (Exception exception) {
            message.replyTo().tell(new Failed(exception.getMessage()));
        }
        return this;
    }
}
