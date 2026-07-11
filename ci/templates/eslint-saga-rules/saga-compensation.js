"use strict";

/**
 * ESLint plugin — Saga and Outbox pattern enforcement.
 *
 * Standards reference:
 *   docs/SAGA_PATTERN.md
 *   docs/OUTBOX_PATTERN.md
 *
 * Installation (copy this file into the child project):
 *
 *   cp .standards/ci/templates/eslint-saga-rules/saga-compensation.js \
 *      src/lint/saga-compensation.js
 *
 * Wire in eslint.config.js (ESLint v9 flat config, CJS project):
 *
 *   const sagaRules = require("./src/lint/saga-compensation.js");
 *
 *   module.exports = [
 *     {
 *       plugins: { saga: sagaRules },
 *       rules: {
 *         "saga/compensation-required": "error",
 *         "saga/step-timeout-required": "error",
 *         "saga/no-direct-broker-call": "error",
 *       },
 *     },
 *   ];
 *
 * For ESM projects ("type": "module"), rename this file to saga-compensation.cjs
 * and import with: import sagaRules from "./src/lint/saga-compensation.cjs";
 *
 * Rules provided:
 *   saga/compensation-required  — every sagaStep() call must have a compensate option
 *   saga/step-timeout-required  — every sagaStep() call must have a timeout option
 *   saga/no-direct-broker-call  — saga/service code must not call broker directly
 */

// ── Helpers ───────────────────────────────────────────────────────────────────

/**
 * Returns true if node is a call to sagaStep(...).
 */
function isSagaStepCall(node) {
  return (
    node.type === "CallExpression" &&
    node.callee.type === "Identifier" &&
    node.callee.name === "sagaStep"
  );
}

/**
 * Returns the options object argument of a sagaStep(handler, options) call, or null.
 * sagaStep accepts (handler, options) or a single config object.
 */
function getSagaStepOptions(callNode) {
  const args = callNode.arguments;
  if (!args || args.length === 0) return null;

  // sagaStep({ handler, compensate, timeout }) — single object form
  if (args.length === 1 && args[0].type === "ObjectExpression") {
    return args[0];
  }
  // sagaStep(handler, { compensate, timeout }) — two-arg form
  if (args.length >= 2 && args[1].type === "ObjectExpression") {
    return args[1];
  }
  return null;
}

/**
 * Returns true if an ObjectExpression node has a property with the given key name.
 */
function hasProperty(objectNode, propName) {
  return objectNode.properties.some(
    (p) =>
      p.type === "Property" &&
      ((p.key.type === "Identifier" && p.key.name === propName) ||
        (p.key.type === "Literal" && p.key.value === propName))
  );
}

// Known broker client identifiers — direct use in saga/service code is forbidden.
const BROKER_IDENTIFIERS = new Set([
  "kafkaProducer",
  "kafkaClient",
  "rabbitChannel",
  "rabbitConnection",
  "sqsClient",
  "snsClient",
  "eventBus",
  "messageBus",
  "messagePublisher",
  "eventPublisher",
  "producer",
]);

// ── Rules ─────────────────────────────────────────────────────────────────────

/**
 * saga/compensation-required
 *
 * Every sagaStep() call must include a `compensate` option. Without compensation,
 * partial saga failures cannot be rolled back.
 *
 * Bad:  sagaStep(handler, { timeout: 5000 })
 * Good: sagaStep(handler, { compensate: rollbackHandler, timeout: 5000 })
 *
 * See: docs/SAGA_PATTERN.md §Compensating Transactions
 */
const compensationRequired = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Every sagaStep() call must include a compensate option. " +
        "See docs/SAGA_PATTERN.md §Compensating Transactions.",
      url: "docs/SAGA_PATTERN.md",
    },
    messages: {
      missingCompensate:
        "sagaStep() call is missing the required 'compensate' option. " +
        "Every saga step must declare a compensation handler to support rollback on failure. " +
        "See docs/SAGA_PATTERN.md §Compensating Transactions.",
      missingOptions:
        "sagaStep() call has no options argument. " +
        "Provide at minimum { compensate, timeout }. " +
        "See docs/SAGA_PATTERN.md §Compensating Transactions.",
    },
    schema: [],
  },
  create(context) {
    return {
      CallExpression(node) {
        if (!isSagaStepCall(node)) return;

        const options = getSagaStepOptions(node);
        if (!options) {
          context.report({ node, messageId: "missingOptions" });
          return;
        }
        if (!hasProperty(options, "compensate")) {
          context.report({ node, messageId: "missingCompensate" });
        }
      },
    };
  },
};

/**
 * saga/step-timeout-required
 *
 * Every sagaStep() call must include a `timeout` option (milliseconds).
 * Without a timeout, a hung downstream call blocks the saga indefinitely.
 *
 * Bad:  sagaStep(handler, { compensate: rollback })
 * Good: sagaStep(handler, { compensate: rollback, timeout: 30000 })
 *
 * See: docs/SAGA_PATTERN.md §Saga Timeout
 */
const stepTimeoutRequired = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Every sagaStep() call must include a timeout option (ms). " +
        "See docs/SAGA_PATTERN.md §Saga Timeout.",
      url: "docs/SAGA_PATTERN.md",
    },
    messages: {
      missingTimeout:
        "sagaStep() call is missing the required 'timeout' option. " +
        "Every saga step must declare a timeout to prevent hung sagas. " +
        "See docs/SAGA_PATTERN.md §Saga Timeout.",
    },
    schema: [],
  },
  create(context) {
    return {
      CallExpression(node) {
        if (!isSagaStepCall(node)) return;

        const options = getSagaStepOptions(node);
        if (!options) return; // compensationRequired will catch this

        if (!hasProperty(options, "timeout")) {
          context.report({ node, messageId: "missingTimeout" });
        }
      },
    };
  },
};

/**
 * saga/no-direct-broker-call
 *
 * Code in saga orchestrators and service modules must not reference known broker
 * client identifiers directly. All event publishing must go through the outbox.
 *
 * Bad:  kafkaProducer.send("order.created", payload)
 * Good: outboxRepository.save({ eventType: "order.created", payload })
 *
 * This rule applies to files matching *saga*, *Saga*, *orchestrator*, *Orchestrator*.
 * Non-saga files (e.g., the OutboxRelay itself) are intentionally excluded.
 *
 * See: docs/OUTBOX_PATTERN.md §Solution, docs/SAGA_PATTERN.md
 */
const noDirectBrokerCall = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Saga/service code must not call the message broker directly. " +
        "Publish events via the outbox table. " +
        "See docs/OUTBOX_PATTERN.md §Solution.",
      url: "docs/OUTBOX_PATTERN.md",
    },
    messages: {
      directBrokerCall:
        "Direct broker call '{{name}}' in saga/service code. " +
        "Publish events via the outbox table instead. " +
        "See docs/OUTBOX_PATTERN.md §Solution.",
    },
    schema: [],
  },
  create(context) {
    const filename = context.getFilename();
    const isSagaFile =
      /saga/i.test(filename) || /orchestrator/i.test(filename);

    // Only enforce in saga/orchestrator files
    if (!isSagaFile) return {};

    return {
      MemberExpression(node) {
        if (node.object.type !== "Identifier") return;
        const name = node.object.name;
        if (BROKER_IDENTIFIERS.has(name)) {
          context.report({
            node,
            messageId: "directBrokerCall",
            data: { name },
          });
        }
      },
      CallExpression(node) {
        if (node.callee.type !== "Identifier") return;
        const name = node.callee.name;
        if (BROKER_IDENTIFIERS.has(name)) {
          context.report({
            node,
            messageId: "directBrokerCall",
            data: { name },
          });
        }
      },
    };
  },
};

// ── Plugin export ─────────────────────────────────────────────────────────────
// This file uses CommonJS (CJS) format, compatible with both ESLint v8 and v9.
//
// ESLint v8 (.eslintrc.js):
//   plugins: { saga: require("./src/lint/saga-compensation") }
//
// ESLint v9 flat config (eslint.config.js) — two options:
//
//   Option A: require() in .js file (works when "type" is NOT "module")
//     import { createRequire } from "module";
//     const require = createRequire(import.meta.url);
//     const sagaRules = require("./src/lint/saga-compensation.js");
//
//   Option B: rename this file to saga-compensation.cjs, then:
//     import sagaRules from "./src/lint/saga-compensation.cjs";
//
//   Then in both cases:
//     export default [{ plugins: { saga: sagaRules },
//       rules: { "saga/compensation-required": "error",
//                "saga/step-timeout-required": "error",
//                "saga/no-direct-broker-call": "error" } }];

module.exports = {
  rules: {
    "compensation-required": compensationRequired,
    "step-timeout-required": stepTimeoutRequired,
    "no-direct-broker-call": noDirectBrokerCall,
  },
};
