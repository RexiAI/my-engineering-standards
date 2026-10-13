# Architecture Decision Record (ADR)

## Title

Typed-judgment layer: opt-in fast-path for probabilistic classification in pipeline agents

## Status

Accepted

## Context

Several pipeline roles perform the same small, repetitive judgment calls with
an expensive full-LLM procedure: the ci-triage skill classifies a failing CI
run as flake / regression / infra / config, and the spec-ux agent decides
whether a spec has a frontend surface. These decisions are cheap for a typed
judgment API (send state + a typed question, get back an answer with a
confidence), and a wrong one is recoverable — a human or the stock procedure
still runs right behind it. But the repo's documentation and agent wiring are
deliberately provider-agnostic (ADR 0002/0003), no external call may be
mandatory, and no probabilistic signal may carry gate authority.

Forces at play:

- Consumers must work identically on machines that never configure a
  judgment API (most current machines).
- A judgment can be wrong, rate-limited, or down; the failure mode must be
  "fallback", never "blocked pipeline" and never "silently trusted".
- Spend must stay bounded per machine per day.
- The Verifier and the deterministic CI gates remain the only authorities
  that can fail a build.

## Decision

We introduce a typed-judgment layer: a single, offline-testable wrapper,
`scripts/typed-judgment.sh` (curl+jq), that sends a state payload plus typed
questions to a judgment API and prints normalized answers
(`answer`, `confidence`, `probabilities`, `usage` tokens, `latency_ms`).

- **Opt-in optionality.** Everything is driven by environment variables
  (`JUDGMENT_API_URL`, `JUDGMENT_API_KEY`, `JUDGMENT_MODEL`,
  `JUDGMENT_MIN_CONFIDENCE`, `JUDGMENT_DAILY_CAP`), which ship commented-out
  and unset in the config templates. With no credentials the script performs
  no network call and exits 10. Consumers must first check that
  `JUDGMENT_API_URL` and `JUDGMENT_API_KEY` are both set and non-empty;
  otherwise they run their stock procedure exactly as before.
- **Replace-with-fallback semantics.** The exit-code contract is the whole
  integration surface: exit `0` means a usable answer was returned and every
  confidence met the threshold; exit `10` means fallback — the consumer runs
  its existing, unchanged procedure (or emits the same BLOCKED/one-question
  outcome its stock path would produce when ambiguous). Exit `2` is a usage
  error. A consumer may only use a typed judgment to pick a path it already
  knew how to take; it must never be a new behavior and must never be trusted
  over evidence.
- **Confidence threshold.** Answers are only usable at or above
  `JUDGMENT_MIN_CONFIDENCE`, default `0.6`. Below the threshold the script
  still prints the parsed answer (so telemetry is recordable) but exits 10.
- **Daily cap.** Each successful (HTTP 2xx) API call increments a
  gitignored per-day counter file `.cache/judgment-cap-YYYY-MM-DD`. Once the
  count reaches `JUDGMENT_DAILY_CAP`, the script exits 10 without any network
  call. Retries count as the capped operation's own bounded attempts (at most
  3 per call), and no credential is ever echoed to stdout, stderr, or logs.
- **T0 trust tier (read/gate only).** Judgment calls consume read-only state
  (logs, file content, gathered evidence) and produce advisory classifications
  only. They get no write, no commit, no push, and no merge authority — the
  trust tier of the existing consumers is unchanged by this layer.
- **Gate authority is unchanged.** A probabilistic judgment never overrides a
  deterministic gate. Every quality gate, the Verifier's checks, and human
  approval remain authoritative; a typed classification that contradicts
  evidence, a gate result, or a rule (e.g. the flake rule, "infra/config are
  not code defects") loses — the deterministic path governs.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Ship the fast-path always-on | Uniform speed gain | Breaks machines without credentials; external call becomes mandatory; provider coupling |
| Inline API calls in each consumer | No shared script | Divergent retry/cap/secret handling; untestable; leaks provider wiring into prompts |
| Treat the answer as authoritative | Simple control flow | Probabilistic signal would outrank deterministic gates — forbidden |
| No layer at all (status quo) | Zero new surface | Full-LLM cost on every triage/applicability call; no bounded-spend option |

## Consequences

Easier: cheap, bounded, observable classification for triage-type steps; one
place to enforce retries, cap, secret hygiene, and diagnostic truncation;
fully offline-testable with an injected fake transport.

Harder / accepted trade-offs: two classification paths to keep in sync (the
typed one is required to stay a strict subset of the stock procedure's
outcomes); cap and threshold add tuning knobs operators must understand;
telemetry fields extend run-log entries. Consumers must document and preserve
their stock procedure alongside the fast-path — a consumer without a fallback
is a consumer that must not adopt the layer.

## Compliance

- `scripts/tests/typed-judgment.bats` — acceptance tests for the script's
  exit-code contract, cap logic, retry bound, secret non-leakage, diagnostic
  truncation, and dry-run mode (all offline via a fake transport).
- `scripts/tests/typed-judgment-integration.bats` — content contracts for the
  config templates, consumer wiring (ci-triage, spec-ux), this ADR, the docs
  sections, and provider-id/product-name scoping.
- Review rule: any new consumer of typed judgment must state its exit-10
  fallback and keep the stock procedure intact; a WARN-free
  `scripts/check-code-principles.sh` run on the script is expected.

## Notes

- 2026-09-28: Decision recorded (spec 028-typed-judgment-layer, tasks 1–8).
- Consumers shipped at adoption: ci-triage skill (Pilot A), spec-ux agent
  (Pilot B). Loop-triage integration is deferred to a future phase.
