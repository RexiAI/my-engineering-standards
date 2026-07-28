package com.mystandards.archunit;

import com.tngtech.archunit.core.domain.JavaClass;
import com.tngtech.archunit.lang.ArchCondition;
import com.tngtech.archunit.lang.ArchRule;
import com.tngtech.archunit.lang.ConditionEvents;
import com.tngtech.archunit.lang.SimpleConditionEvent;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;

/**
 * ArchUnit fitness functions for the Outbox pattern.
 *
 * Standards reference: docs/OUTBOX_PATTERN.md
 *
 * Usage: import and annotate with @ArchTest in a @AnalyzeClasses test class.
 * See ci/templates/archunit/pom-fragment.xml for dependency snippet.
 *
 * Conventions assumed:
 *   - Outbox entity/repository types are named Outbox* or *Outbox*
 *   - Outbox relay component is named *OutboxRelay* or *OutboxPublisher*
 *   - Consumer deduplication store types end with DedupStore or DeduplicationStore
 *   - Message broker clients are typed *MessagePublisher, *EventBus, *KafkaProducer,
 *     *KafkaTemplate, *RabbitTemplate, *SqsClient, *SnsClient, *EventPublisher
 *   - Service classes live in *.service.* packages
 */
public final class OutboxArchRules {

    private OutboxArchRules() {}

    // ── Rule 1: Service classes must not call broker directly — use OutboxRepository ────────────

    /**
     * Classes in *.service.* must not directly depend on broker client types. All event
     * publishing must go through an Outbox repository/entity write in the same transaction.
     *
     * Rationale: docs/OUTBOX_PATTERN.md §Solution —
     *   Write the event to the outbox table in the same transaction as the business operation.
     */
    public static ArchRule servicesMustPublishViaOutbox() {
        return noClasses()
            .that().resideInAPackage("..service..")
            .and().haveSimpleNameNotEndingWith("OutboxRelay")
            .and().haveSimpleNameNotEndingWith("OutboxPublisher")
            .should().dependOnClassesThat(new BrokerClientPredicate())
            .because("Service classes must publish events via the outbox table, not directly to the broker. " +
                     "See docs/OUTBOX_PATTERN.md §Solution.");
    }

    // ── Rule 2: Outbox relay must exist when Outbox entity exists ───────────────────────────────

    /**
     * Any package that contains an Outbox entity (*Outbox or Outbox*) must also contain
     * an outbox relay component (*OutboxRelay or *OutboxPublisher).
     *
     * Rationale: docs/OUTBOX_PATTERN.md §Outbox Relay —
     *   A separate relay process must publish events from the outbox table to the broker.
     *   Without it, events accumulate in the DB but never reach consumers.
     */
    public static ArchRule outboxRelayMustExist() {
        return classes()
            .that(new IsOutboxEntityPredicate())
            .should(new OutboxRelayExistsInSamePackageCondition())
            .because("An outbox entity exists but no relay component found in the same package " +
                     "(*OutboxRelay or *OutboxPublisher). " +
                     "See docs/OUTBOX_PATTERN.md §Outbox Relay.");
    }

    // ── Rule 3: Message consumers must reference a deduplication store ──────────────────────────

    /**
     * Classes in *.outbox.consumer.*, *.outbox.listener.*, or any consumer/listener class
     * that depends on an Outbox* type must inject a *DedupStore or *DeduplicationStore.
     * The outbox relay may re-publish after a crash; only outbox-related consumers need dedup.
     * Plain listeners (e.g., Redis pub/sub, non-outbox event handlers) are not affected.
     *
     * Rationale: docs/OUTBOX_PATTERN.md §Idempotent Event Processing —
     *   "Consumers must handle duplicate events."
     */
    public static ArchRule consumersMustHaveDedupStore() {
        return classes()
            .that().resideInAnyPackage("..outbox.consumer..", "..outbox.listener..")
            .or(new DependsOnOutboxTypePredicate())
            .and().resideInAnyPackage("..consumer..", "..listener..")
            .should(new DependOnDedupStoreCondition())
            .because("Outbox-related consumers must inject a deduplication store to handle duplicate events " +
                     "published by the outbox relay. " +
                     "See docs/OUTBOX_PATTERN.md §Idempotent Event Processing.");
    }

    // ── Rule 4: Outbox relay must not reside in controller layer ────────────────────────────────

    /**
     * Outbox relay components (*OutboxRelay, *OutboxPublisher) must not live in *.controller.*
     * packages. Relay is infrastructure, not presentation.
     *
     * Rationale: docs/ARCHITECTURE.md §Layered Architecture.
     */
    public static ArchRule outboxRelayMustNotBeInControllerLayer() {
        return noClasses()
            .that().haveSimpleNameEndingWith("OutboxRelay")
            .or().haveSimpleNameEndingWith("OutboxPublisher")
            .should().resideInAPackage("..controller..")
            .because("Outbox relay is infrastructure and must not live in the controller layer. " +
                     "See docs/ARCHITECTURE.md §Layered Architecture.");
    }

    // ── Predicates & Conditions ─────────────────────────────────────────────────────────────────

    private static class BrokerClientPredicate
            extends com.tngtech.archunit.base.DescribedPredicate<JavaClass> {

        private static final java.util.Set<String> BROKER_SUFFIXES = java.util.Set.of(
            "MessagePublisher", "EventBus", "KafkaProducer", "KafkaTemplate",
            "RabbitTemplate", "SqsClient", "SnsClient", "EventPublisher");

        BrokerClientPredicate() {
            super("a known broker client type");
        }

        @Override
        public boolean test(JavaClass javaClass) {
            String name = javaClass.getSimpleName();
            return BROKER_SUFFIXES.stream().anyMatch(name::endsWith);
        }
    }

    private static class IsOutboxEntityPredicate
            extends com.tngtech.archunit.base.DescribedPredicate<JavaClass> {

        IsOutboxEntityPredicate() {
            super("an outbox entity (simple name starts or ends with 'Outbox')");
        }

        @Override
        public boolean test(JavaClass javaClass) {
            String name = javaClass.getSimpleName();
            return (name.startsWith("Outbox") || name.endsWith("Outbox")) &&
                   (javaClass.isAnnotatedWith("Entity") || javaClass.isAnnotatedWith("Table") ||
                    javaClass.isAnnotatedWith("Document"));
        }
    }

    private static class OutboxRelayExistsInSamePackageCondition extends ArchCondition<JavaClass> {

        OutboxRelayExistsInSamePackageCondition() {
            super("have a corresponding *OutboxRelay or *OutboxPublisher in the same package");
        }

        @Override
        public void check(JavaClass javaClass, ConditionEvents events) {
            String packageName = javaClass.getPackageName();

            boolean relayExists = javaClass.getPackage().getClasses().stream()
                .anyMatch(c -> c.getSimpleName().endsWith("OutboxRelay") ||
                               c.getSimpleName().endsWith("OutboxPublisher"));

            if (!relayExists) {
                String message = String.format(
                    "Outbox entity <%s> found in package [%s] but no relay component " +
                    "(*OutboxRelay or *OutboxPublisher) exists in the same package. " +
                    "See docs/OUTBOX_PATTERN.md §Outbox Relay.",
                    javaClass.getName(), packageName);
                events.add(SimpleConditionEvent.violated(javaClass, message));
            }
        }
    }

    private static class DependsOnOutboxTypePredicate
            extends com.tngtech.archunit.base.DescribedPredicate<JavaClass> {

        DependsOnOutboxTypePredicate() {
            super("depends on an Outbox* type (field, parameter, or return type)");
        }

        @Override
        public boolean test(JavaClass javaClass) {
            return javaClass.getFields().stream()
                .anyMatch(f -> f.getRawType().getSimpleName().startsWith("Outbox") ||
                               f.getRawType().getSimpleName().endsWith("Outbox")) ||
                   javaClass.getMethods().stream()
                .anyMatch(m -> m.getRawParameterTypes().stream()
                    .anyMatch(p -> p.getSimpleName().startsWith("Outbox") ||
                                   p.getSimpleName().endsWith("Outbox")));
        }
    }

    private static class DependOnDedupStoreCondition extends ArchCondition<JavaClass> {

        DependOnDedupStoreCondition() {
            super("depend on a *DedupStore or *DeduplicationStore field");
        }

        @Override
        public void check(JavaClass javaClass, ConditionEvents events) {
            boolean hasDedupStore = javaClass.getFields().stream()
                .anyMatch(f -> {
                    String typeName = f.getRawType().getSimpleName();
                    return typeName.endsWith("DedupStore") || typeName.endsWith("DeduplicationStore");
                });

            if (!hasDedupStore) {
                String message = String.format(
                    "Consumer/listener class <%s> does not inject a deduplication store. " +
                    "The outbox relay may re-deliver events after a crash; consumers must deduplicate. " +
                    "See docs/OUTBOX_PATTERN.md §Idempotent Event Processing.",
                    javaClass.getName());
                events.add(SimpleConditionEvent.violated(javaClass, message));
            }
        }
    }
}
