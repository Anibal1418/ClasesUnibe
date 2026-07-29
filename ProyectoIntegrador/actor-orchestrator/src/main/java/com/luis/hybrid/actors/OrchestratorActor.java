package com.luis.hybrid.actors;

import com.fasterxml.jackson.databind.JsonNode;
import com.luis.hybrid.model.ProcessingRequest;
import com.luis.hybrid.model.ServiceConfig;
import com.luis.hybrid.model.WorkflowResponse;
import com.luis.hybrid.storage.JobStore;
import org.apache.pekko.actor.typed.ActorRef;
import org.apache.pekko.actor.typed.Behavior;
import org.apache.pekko.actor.typed.SupervisorStrategy;
import org.apache.pekko.actor.typed.javadsl.AbstractBehavior;
import org.apache.pekko.actor.typed.javadsl.ActorContext;
import org.apache.pekko.actor.typed.javadsl.Behaviors;
import org.apache.pekko.actor.typed.javadsl.Receive;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

/** Actor supervisor que encadena validación, GPU, Spark, análisis y respuesta. */
public final class OrchestratorActor extends AbstractBehavior<OrchestratorActor.Command> {
    public interface Command {}

    public record Start(
            ProcessingRequest request,
            ActorRef<WorkflowResponse> replyTo
    ) implements Command {}

    private record ValidationFinished(
            String jobId,
            ValidationActor.Result result,
            Throwable error
    ) implements Command {}
    private record GpuFinished(
            String jobId,
            GpuStageActor.Result result,
            Throwable error
    ) implements Command {}
    private record SparkSubmitted(
            String jobId,
            SparkSubmissionActor.Result result,
            Throwable error
    ) implements Command {}
    private record ResultsCollected(
            String jobId,
            ResultAnalysisActor.Result result,
            Throwable error
    ) implements Command {}
    private record ResponseBuilt(
            String jobId,
            ResponseActor.Result result,
            Throwable error
    ) implements Command {}

    private static final class WorkflowState {
        private final ProcessingRequest request;
        private final ActorRef<WorkflowResponse> replyTo;
        private final long startedNanos;
        private JsonNode gpuPayload;
        private String outputUri;
        private String batchId;
        private JsonNode sparkStatus;
        private JsonNode sparkMetrics;

        private WorkflowState(ProcessingRequest request, ActorRef<WorkflowResponse> replyTo) {
            this.request = request;
            this.replyTo = replyTo;
            this.startedNanos = System.nanoTime();
        }
    }

    private final ServiceConfig config;
    private final JobStore store;
    private final ActorRef<ValidationActor.Command> validator;
    private final ActorRef<GpuStageActor.Command> gpuStage;
    private final ActorRef<SparkSubmissionActor.Command> sparkStage;
    private final ActorRef<ResultAnalysisActor.Command> resultStage;
    private final ActorRef<ResponseActor.Command> responseStage;
    private final Map<String, WorkflowState> workflows = new HashMap<>();

    public static Behavior<Command> create(ServiceConfig config, JobStore store) {
        return Behaviors.setup(context -> new OrchestratorActor(context, config, store));
    }

    private OrchestratorActor(
            ActorContext<Command> context,
            ServiceConfig config,
            JobStore store
    ) {
        super(context);
        this.config = config;
        this.store = store;
        this.validator = context.spawn(ValidationActor.create(), "validation-stage");

        this.gpuStage = context.spawn(
                Behaviors.supervise(GpuStageActor.create(config))
                        .onFailure(
                                Exception.class,
                                SupervisorStrategy.restartWithBackoff(
                                        Duration.ofSeconds(1),
                                        Duration.ofSeconds(10),
                                        0.20
                                ).withMaxRestarts(5)
                        ),
                "gpu-stage"
        );

        this.sparkStage = context.spawn(
                Behaviors.supervise(SparkSubmissionActor.create(config))
                        .onFailure(
                                Exception.class,
                                SupervisorStrategy.restartWithBackoff(
                                        Duration.ofSeconds(1),
                                        Duration.ofSeconds(15),
                                        0.20
                                ).withMaxRestarts(5)
                        ),
                "spark-submit-stage"
        );

        this.resultStage = context.spawn(
                Behaviors.supervise(ResultAnalysisActor.create(config, store))
                        .onFailure(
                                Exception.class,
                                SupervisorStrategy.restartWithBackoff(
                                        Duration.ofSeconds(2),
                                        Duration.ofSeconds(20),
                                        0.20
                                ).withMaxRestarts(5)
                        ),
                "result-analysis-stage"
        );
        this.responseStage = context.spawn(ResponseActor.create(store), "response-stage");
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Start.class, this::onStart)
                .onMessage(ValidationFinished.class, this::onValidationFinished)
                .onMessage(GpuFinished.class, this::onGpuFinished)
                .onMessage(SparkSubmitted.class, this::onSparkSubmitted)
                .onMessage(ResultsCollected.class, this::onResultsCollected)
                .onMessage(ResponseBuilt.class, this::onResponseBuilt)
                .build();
    }

    private Behavior<Command> onStart(Start message) {
        String jobId = UUID.randomUUID().toString().replace("-", "");
        workflows.put(jobId, new WorkflowState(message.request(), message.replyTo()));
        getContext().getLog().info("job={} stage=orchestrator event=start", jobId);

        getContext().ask(
                ValidationActor.Result.class,
                validator,
                Duration.ofSeconds(5),
                replyTo -> new ValidationActor.Validate(
                        message.request(),
                        config.maxInputValues(),
                        replyTo
                ),
                (result, error) -> new ValidationFinished(jobId, result, error)
        );
        return this;
    }

    private Behavior<Command> onValidationFinished(ValidationFinished message) {
        WorkflowState state = workflows.get(message.jobId());
        if (state == null) {
            return this;
        }
        if (message.error() != null) {
            return fail(message.jobId(), "Falló la validación: " + message.error().getMessage());
        }
        if (message.result() instanceof ValidationActor.Invalid invalid) {
            return fail(message.jobId(), invalid.error());
        }

        getContext().ask(
                GpuStageActor.Result.class,
                gpuStage,
                Duration.ofMinutes(10),
                replyTo -> new GpuStageActor.Normalize(
                        message.jobId(),
                        state.request,
                        replyTo
                ),
                (result, error) -> new GpuFinished(message.jobId(), result, error)
        );
        return this;
    }

    private Behavior<Command> onGpuFinished(GpuFinished message) {
        WorkflowState state = workflows.get(message.jobId());
        if (state == null) {
            return this;
        }
        if (message.error() != null) {
            return fail(message.jobId(), "Falló el preprocesamiento: " + message.error().getMessage());
        }
        if (message.result() instanceof GpuStageActor.Failed failed) {
            return fail(message.jobId(), failed.error());
        }

        GpuStageActor.Completed completed = (GpuStageActor.Completed) message.result();
        state.gpuPayload = completed.payload();
        String inputUri = completed.payload().path("input_uri").asText();
        if (inputUri.isBlank()) {
            return fail(message.jobId(), "El microservicio GPU no devolvió input_uri");
        }
        state.outputUri = store.resultUri(message.jobId());

        getContext().ask(
                SparkSubmissionActor.Result.class,
                sparkStage,
                Duration.ofMinutes(3),
                replyTo -> new SparkSubmissionActor.Submit(
                        message.jobId(),
                        inputUri,
                        state.outputUri,
                        state.request.safeRepetitions(),
                        replyTo
                ),
                (result, error) -> new SparkSubmitted(message.jobId(), result, error)
        );
        return this;
    }

    private Behavior<Command> onSparkSubmitted(SparkSubmitted message) {
        WorkflowState state = workflows.get(message.jobId());
        if (state == null) {
            return this;
        }
        if (message.error() != null) {
            return fail(message.jobId(), "Falló el envío de Spark: " + message.error().getMessage());
        }
        if (message.result() instanceof SparkSubmissionActor.Failed failed) {
            return fail(message.jobId(), failed.error());
        }

        SparkSubmissionActor.Submitted submitted = (SparkSubmissionActor.Submitted) message.result();
        state.batchId = submitted.batchId();

        getContext().ask(
                ResultAnalysisActor.Result.class,
                resultStage,
                Duration.ofMinutes(50),
                replyTo -> new ResultAnalysisActor.Collect(
                        message.jobId(),
                        submitted.batchId(),
                        submitted.outputUri(),
                        replyTo
                ),
                (result, error) -> new ResultsCollected(message.jobId(), result, error)
        );
        return this;
    }

    private Behavior<Command> onResultsCollected(ResultsCollected message) {
        WorkflowState state = workflows.get(message.jobId());
        if (state == null) {
            return this;
        }
        if (message.error() != null) {
            return fail(message.jobId(), "Falló la recolección: " + message.error().getMessage());
        }
        if (message.result() instanceof ResultAnalysisActor.Failed failed) {
            return fail(message.jobId(), failed.error());
        }

        ResultAnalysisActor.Completed completed = (ResultAnalysisActor.Completed) message.result();
        state.sparkMetrics = completed.metrics();
        state.sparkStatus = completed.finalStatus();
        double totalMs = (System.nanoTime() - state.startedNanos) / 1_000_000.0;

        getContext().ask(
                ResponseActor.Result.class,
                responseStage,
                Duration.ofSeconds(30),
                replyTo -> new ResponseActor.Build(
                        message.jobId(),
                        state.gpuPayload,
                        state.sparkMetrics,
                        state.sparkStatus,
                        totalMs,
                        replyTo
                ),
                (result, error) -> new ResponseBuilt(message.jobId(), result, error)
        );
        return this;
    }

    private Behavior<Command> onResponseBuilt(ResponseBuilt message) {
        WorkflowState state = workflows.remove(message.jobId());
        if (state == null) {
            return this;
        }
        if (message.error() != null) {
            state.replyTo.tell(WorkflowResponse.failure(
                    message.jobId(),
                    "No se pudo construir la respuesta: " + message.error().getMessage()
            ));
            return this;
        }
        if (message.result() instanceof ResponseActor.Failed failed) {
            state.replyTo.tell(WorkflowResponse.failure(message.jobId(), failed.error()));
            return this;
        }
        ResponseActor.Completed completed = (ResponseActor.Completed) message.result();
        state.replyTo.tell(WorkflowResponse.success(message.jobId(), completed.payload()));
        return this;
    }

    private Behavior<Command> fail(String jobId, String error) {
        WorkflowState state = workflows.remove(jobId);
        if (state != null) {
            getContext().getLog().error("job={} stage=orchestrator event=failed error={}", jobId, error);
            state.replyTo.tell(WorkflowResponse.failure(jobId, error));
        }
        return this;
    }
}
