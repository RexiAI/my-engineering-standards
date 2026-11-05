# Architecture Decision Record (ADR)

## Title

Pipeline lite mode: a mechanically selected short stage set for small specs

## Status

Proposed

## Context

The spec pipeline is deliberately heavy: Coder, Refactorer, Verifier, Mutation
Runner, PR Opener, and (for frontend lanes) Deploy Verifier. That weight buys
real guarantees on a feature change, but a docs-only spec or a one-script fix
pays the same price for none of the risk. The typical failure mode of a
pipeline like this is that small changes get routed *around* it — a quick
manual edit, a fix that never gets a spec — because the process cost is out of
proportion to the change.

The one thing that must not happen is letting a model decide it is small. An
agent asked "is this a small change?" has every incentive to answer yes: the
short path is cheaper and it cannot measure the surface before implementing.
Spec 039 therefore required the trigger to be mechanical — an explicit token or
a deterministic classifier over the spec folder's own files.

## Decision

The pipeline supports a second mode, `lite`, selected per spec and recorded in
`specs/NNN-slug/45-decisions.md`.

- **Trigger.** `scripts/lite-trigger.sh` prints `lite`, `full`, or `auto` from
  an exact argv token (case-insensitive whole-token match); conflicting tokens
  exit non-zero. No command or agent re-implements the match.
- **Classifier.** `scripts/classify-spec-size.sh` prints `lite` or `full` plus a
  `Reason:` line, from `10-tasks.md` and `20-acceptance/` only. `lite` requires
  every named path to be under `docs/`, under `specs/`, a `*.md` file, or
  exactly one file under `scripts/`, and at most 5 acceptance scenarios. Missing
  or unparsable inputs resolve to `full`.
- **Resolution.** `scripts/resolve-pipeline-mode.sh` applies
  `tier guard > explicit token > classifier` and appends one six-line decision
  entry per invocation.
- **Tier guard.** `lite` is never selected on `production` or `multi-service`
  (the tiers that add mutation testing and cross-service contract gates), nor
  when the repo's `Conformance tier:` declaration cannot be found. Such a
  request resolves to `full` with the refusal on stderr and `Why:` naming the
  tier.
- **Stage set.** In `lite` the pipeline runs Coder → Verifier → PR Opener (5b) →
  Archiver (5d); Refactorer, Mutation Runner, UX Designer, and Deploy Verifier
  are not invoked.
- **No gate is skipped.** Every Verifier hard gate — full test suite, secrets
  scan, `check-code-principles.sh`, scenario traceability — still runs, and a
  FAIL still stops the pipeline.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| Keep one heavy pipeline, no mode | No new concept, no classifier to maintain, uniform guarantees | Small specs keep paying refactor/mutation/deploy cost, which pushes people to route around the pipeline — the guarantee is lost anyway |
| Let the Coder or the orchestrator judge whether the spec is small | Zero new scripts, adapts to context a file scan misses | Unmeasurable and self-interested: the agent choosing the cheap path also benefits from it; the same spec could select differently run to run |
| Classifier only, no explicit token | Purely mechanical, no way to mis-trigger | No human override; a spec that is genuinely small but does not look it (or vice versa) is stuck, and the decision cannot be corrected for one run |
| Refuse lite on `production` only | Simpler guard, one fewer tier to reason about | `multi-service` is a superset of `production`'s gates, so permitting lite there would skip strictly more than the informal spec allowed |

## Consequences

Easier: docs-only and one-script specs finish faster, and the skipped stages are
recorded rather than silently absent. Harder: there is now a second stage list
to keep coherent — `commands/build.md`, `agents/spec-pipeline.md`, the index, and
the stage files must agree — and a second way for `30-report.md` to arrive
(written by the Verifier instead of the Mutation Runner). The classifier's
bounds are heuristics: a spec can be small in lines but large in risk, which is
why the tier guard, not the classifier, is what protects production repos.

The mode is logged, so an audit can always answer which stages ran and why. The
classifier never consults the clock, the network, or the repo outside the spec
folder, so re-running it on the same spec produces the same answer.

## Compliance

- `scripts/lite-trigger.sh`, `scripts/classify-spec-size.sh`, and
  `scripts/resolve-pipeline-mode.sh` are the only implementations of the trigger
  match, the classifier rule, and the tier guard.
- `scripts/tests/ac-039-lite-mode.bats` covers the trigger, classifier,
  precedence, and logging contracts; `scripts/tests/ac-039-lite-wiring.bats`
  covers the stage selection, the retained gates, and this ADR's indexing.
- `scripts/check-orchestration.sh` keeps every cited script, agent, and section
  reference resolving, so the lite wiring cannot silently dangle.
- Code review: a change that adds a stage or a gate must update the lite stage
  set in the same PR.

## Notes

- 2026-10-30: Decision recorded (spec 039 human review gate: Q1 surface and
  scenario bounds, Q2 refusal on `multi-service`, Q3 refusal on an undetectable
  tier).
