package com.luis.hybrid.actors;

import com.luis.hybrid.model.ProcessingRequest;
import org.apache.pekko.actor.typed.ActorRef;
import org.apache.pekko.actor.typed.Behavior;
import org.apache.pekko.actor.typed.javadsl.AbstractBehavior;
import org.apache.pekko.actor.typed.javadsl.ActorContext;
import org.apache.pekko.actor.typed.javadsl.Behaviors;
import org.apache.pekko.actor.typed.javadsl.Receive;

import java.util.Set;

/** Actor sin estado que valida el contrato antes de consumir recursos GPU o Spark. */
public final class ValidationActor extends AbstractBehavior<ValidationActor.Command> {
    public interface Command {}
    public interface Result {}

    public record Validate(
            ProcessingRequest request,
            int maximumValues,
            ActorRef<Result> replyTo
    ) implements Command {}

    public record Valid(ProcessingRequest request) implements Result {}
    public record Invalid(String error) implements Result {}

    public static Behavior<Command> create() {
        return Behaviors.setup(ValidationActor::new);
    }

    private ValidationActor(ActorContext<Command> context) {
        super(context);
    }

    @Override
    public Receive<Command> createReceive() {
        return newReceiveBuilder()
                .onMessage(Validate.class, this::onValidate)
                .build();
    }

    private Behavior<Command> onValidate(Validate message) {
        ProcessingRequest request = message.request();
        if (request == null || request.values() == null || request.values().isEmpty()) {
            message.replyTo().tell(new Invalid("Debe enviar un arreglo values no vacío"));
            return this;
        }
        if (request.values().size() > message.maximumValues()) {
            message.replyTo().tell(new Invalid(
                    "El arreglo excede el máximo de " + message.maximumValues() + " valores"
            ));
            return this;
        }
        if (request.values().stream().anyMatch(value -> value == null || !Double.isFinite(value))) {
            message.replyTo().tell(new Invalid("Todos los valores deben ser numéricos y finitos"));
            return this;
        }
        if (!Set.of("cpu", "gpu", "both").contains(request.safeEngine())) {
            message.replyTo().tell(new Invalid("engine debe ser cpu, gpu o both"));
            return this;
        }
        message.replyTo().tell(new Valid(request));
        return this;
    }
}
