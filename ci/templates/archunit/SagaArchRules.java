package com.mystandards.archunit;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.core.domain.JavaMethod;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;

import java.util.Set;
import java.util.stream.Collectors;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * ArchUnit fitness functions for the Saga pattern.
 *
 * Standards reference: docs/SAGA_PATTERN.md
 *
 * Usage: import and annotate with @ArchTest in a @AnalyzeClasses test class.
 * See ci/templates/archunit/pom-fragment.xml for dependency snippet.
 *
 * Conventions assumed:
 *   - Saga handlers are annotated with @SagaHandler
 *   - Saga orchestrators live in packages matching *.saga.*
 *   - State store dependency is typed SagaStateStore (or any type whose name ends in StateStore)
 *   - Compensation methods follow naming: on*Failed, compensate*, rollback*
 *   - Message broker clients are typed *MessagePublisher, *EventBus, *KafkaProducer, *RabbitTemplate
 */
public final class SagaArchRules {

    private SagaArchRules() {}

    // ── Rule 1: Every @SagaHandler class must declare at least one compensation method ──────────

    /**
     * Every class containing @SagaHandler-annotated methods must declare at least one method
     * named on*Failed, compensate*, or rollback*. Ensures compensation logic is never omitted.
     *
     * Rationale: docs/SAGA_PATTERN.md §Compensating Transactions —
     *   "Compensating actions must be idempotent and reliable."
     */
    public static ArchRule sagaHandlersMustHaveCompensation() {
        return classes()
            .that(new AnnotatedWithSagaHandlerPredicate())
            .should(new HaveCompensationMethodCondition())
            .because("Every saga handler class must declare at least one compensation method " +
                     "(on*Failed, compensate*, or rollback*). " +
                     "See docs/SAGA_PATTERN.md §Compensating Transactions.");
    }

    // ── Rule 2: @SagaHandler methods must be @Transactional ────────────────────────────────────

    /**
     * Methods annotated @SagaHandler must also be annotated @Transactional (or declared on a
     * class annotated @Transactional). Ensures each saga step runs in a local transaction.
     *
     * Rationale: docs/SAGA_PATTERN.md — each step is a local transaction; without @Transactional,
     * partial writes may occur within a step.
     */
    public static ArchRule sagaHandlerMethodsMustBeTransactional() {
        return classes()
            .that(new AnnotatedWithSagaHandlerPredicate())
            .should(new SagaHandlerMethodsAreTransactionalCondition())
            .because("@SagaHandler methods must be @Transactional. " +
                     "See docs/SAGA_PATTERN.md §Implementation.");
    }

    // ── Rule 3: Saga orchestrators must depend on a SagaStateStore ─────────────────────────────

    /**
     * Classes in *.saga.* packages must have a field of type *StateStore. Ensures saga state is
     * persisted and sagas survive restarts.
     *
     * Rationale: docs/SAGA_PATTERN.md §Saga State Store —
     *   "Persist saga state so it survives restarts."
     */
    public static ArchRule sagaOrchestratorsMustUsePersistentStateStore() {
        return classes()
            .that().resideInAPackage("..saga..")
            .and().haveSimpleNameEndingWith("Orchestrator")
            .should(new DependOnStateStoreCondition())
            .because("Saga orchestrators must inject a SagaStateStore to survive restarts. " +
                     "See docs/SAGA_PATTERN.md §Saga State Store.");
    }

    // ── Rule 4: Saga classes must not call message broker directly — use outbox ─────────────────

    /**
     * Classes in *.saga.* must not depend directly on broker client types
     * (*MessagePublisher, *EventBus, *KafkaProducer, *RabbitTemplate, *SqsClient).
     * All event publishing must go through the outbox table.
     *
     * Rationale: docs/OUTBOX_PATTERN.md §Philosophy — outbox guarantees at-least-once delivery
     * atomically with the business write; direct broker calls break this guarantee.
     */
    public static ArchRule sagasMustNotCallBrokerDirectly() {
        return noClasses()
            .that().resideInAPackage("..saga..")
            .should().dependOnClassesThat(new BrokerClientPredicate())
            .because("Saga classes must publish events via the outbox table, not directly to the broker. " +
                     "See docs/OUTBOX_PATTERN.md and docs/SAGA_PATTERN.md.");
    }

    // ── Rule 5: *.saga.* must not depend on *.controller.* ─────────────────────────────────────

    /**
     * Saga packages must not depend on controller packages. Enforces layered architecture.
     *
     * Rationale: docs/ARCHITECTURE.md §Layered Architecture —
     *   Controller → Service → Repository. Sagas live in the service layer.
     */
    public static ArchRule sagasMustNotDependOnControllers() {
        return noClasses()
            .that().resideInAPackage("..saga..")
            .should().dependOnClassesThat().resideInAPackage("..controller..")
            .because("Saga classes (service layer) must not depend on controller classes. " +
                     "See docs/ARCHITECTURE.md §Layered Architecture.");
    }

    // ── Predicates & Conditions ─────────────────────────────────────────────────────────────────

    private static class AnnotatedWithSagaHandlerPredicate
            extends com.tngtech.archunit.base.DescribedPredicate<JavaClass> {

        AnnotatedWithSagaHandlerPredicate() {
            super("annotated with @SagaHandler or containing methods annotated with @SagaHandler");
        }

        @Override
        public boolean test(JavaClass javaClass) {
            return javaClass.isAnnotatedWith("SagaHandler") ||
                   javaClass.getMethods().stream()
                       .anyMatch(m -> m.isAnnotatedWith("SagaHandler"));
        }
    }

    private static class HaveCompensationMethodCondition extends ArchCondition<JavaClass> {

        HaveCompensationMethodCondition() {
            super("declare at least one compensation method (on*Failed, compensate*, or rollback*)");
        }

        @Override
        public void check(JavaClass javaClass, ConditionEvents events) {
            boolean hasCompensation = javaClass.getMethods().stream()
                .map(JavaMethod::getName)
                .anyMatch(name ->
                    name.startsWith("compensate") ||
                    name.startsWith("rollback") ||
                    (name.startsWith("on") && name.endsWith("Failed")));

            if (!hasCompensation) {
                String message = String.format(
                    "Class <%s> contains @SagaHandler methods but declares no compensation method " +
                    "(expected: on*Failed, compensate*, or rollback*). " +
                    "See docs/SAGA_PATTERN.md §Compensating Transactions.",
                    javaClass.getName());
                events.add(SimpleConditionEvent.violated(javaClass, message));
            }
        }
    }

    private static class SagaHandlerMethodsAreTransactionalCondition extends ArchCondition<JavaClass> {

        SagaHandlerMethodsAreTransactionalCondition() {
            super("have all @SagaHandler methods also annotated @Transactional, " +
                  "or the class itself annotated @Transactional");
        }

        @Override
        public void check(JavaClass javaClass, ConditionEvents events) {
            boolean classIsTransactional = javaClass.isAnnotatedWith("Transactional");
            if (classIsTransactional) return;

            Set<JavaMethod> nonTransactionalHandlers = javaClass.getMethods().stream()
                .filter(m -> m.isAnnotatedWith("SagaHandler"))
                .filter(m -> !m.isAnnotatedWith("Transactional"))
                .collect(Collectors.toSet());

            for (JavaMethod method : nonTransactionalHandlers) {
                String message = String.format(
                    "Method <%s.%s> is annotated @SagaHandler but not @Transactional. " +
                    "Each saga step must execute within a local transaction. " +
                    "See docs/SAGA_PATTERN.md §Implementation.",
                    javaClass.getName(), method.getName());
                events.add(SimpleConditionEvent.violated(javaClass, message));
            }
        }
    }

    private static class DependOnStateStoreCondition extends ArchCondition<JavaClass> {

        DependOnStateStoreCondition() {
            super("have a field whose type name ends with 'StateStore'");
        }

        @Override
        public void check(JavaClass javaClass, ConditionEvents events) {
            boolean hasStateStore = javaClass.getFields().stream()
                .anyMatch(f -> f.getRawType().getSimpleName().endsWith("StateStore"));

            if (!hasStateStore) {
                String message = String.format(
                    "Saga orchestrator <%s> does not depend on a *StateStore. " +
                    "Saga state must be persisted to survive restarts. " +
                    "See docs/SAGA_PATTERN.md §Saga State Store.",
                    javaClass.getName());
                events.add(SimpleConditionEvent.violated(javaClass, message));
            }
        }
    }

    private static class BrokerClientPredicate
            extends com.tngtech.archunit.base.DescribedPredicate<JavaClass> {

        private static final Set<String> BROKER_SUFFIXES = Set.of(
            "MessagePublisher", "EventBus", "KafkaProducer", "KafkaTemplate",
            "RabbitTemplate", "SqsClient", "SnsClient", "EventPublisher");

        BrokerClientPredicate() {
            super("a known broker client type (*MessagePublisher, *EventBus, *KafkaProducer, " +
                  "*KafkaTemplate, *RabbitTemplate, *SqsClient, *SnsClient, *EventPublisher)");
        }

        @Override
        public boolean test(JavaClass javaClass) {
            String name = javaClass.getSimpleName();
            return BROKER_SUFFIXES.stream().anyMatch(name::endsWith);
        }
    }
}
