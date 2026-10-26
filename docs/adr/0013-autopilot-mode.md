# Architecture Decision Record (ADR)

## Title

Autopilot mode: choose-default-record-continue for unattended pipeline queue runs

## Status

Accepted

## Context

The spec pipeline has exactly one designed human interruption — the review gate
between Specifier and Coder — plus a `Stop-and-Ask decision matrix` that every
agent resolves per the matrix. On an unattended overnight queue, both become
blocking: a matrix "ask" row waits for a human who is asleep, and the queue
stalls with nothing to show in the morning.

The matrix already encodes the answer for every listed condition. What was
missing was permission to take the documented default without a human, plus a
record of what was chosen and why, so the morning review can audit the run
instead of re-deriving it.

## Decision

We add autopilot mode to the spec pipeline. It is off by default.

- **Trigger.** An invocation is autopilot when any single argument is the
  literal token `autopilot` (case-insensitive), or when `SPEC_AUTOPILOT=1` (the
  literal `1` is the only truthy value). A new `/autopilot <slug> [<slug> ...]`
  command turns it on explicitly for a queue run. There is no `--autopilot`
  flag; detection is delegated to `scripts/autopilot-trigger.sh`, never
  re-implemented in a command or agent.
- **Ask becomes decide.** In autopilot, no stage calls the question tool, emits
  `BLOCKED — <question>` as a stop, or waits for human input. Every ask row of
  the Stop-and-Ask decision matrix becomes: choose the documented default,
  record it, continue. The human review gate between Specifier and Coder is
  removed only under autopilot; non-autopilot behavior is unchanged.
- **Stops stay stops.** Six hard stops remain, as hard as before: a dirty tree
  outside the current spec folder; no repo / no `00-informal.md` / no way to
  establish requirements; phase-1 or phase-2 budget exhausted; deploy failure
  after 3 attempts; `30-report.md` missing or not green at PR time; any
  never-list action. A queue stops at its first hard stop — it never skips to
  the next slug, and it writes the morning report before stopping.
- **The never-list stays never.** No merge, no git tag, no push to
  `main`/`master`, no force-push, no branch deletion, no gate-threshold change,
  no secret creation/rotation, no writes outside the target repo, and no
  `git init`/submodule scaffolding. These are refusals, not decisions — autopilot
  never converts them into a guess.
- **Two artifacts make the run auditable.** Each resolved ask writes one entry
  to `specs/NNN-slug/45-decisions.md` with six labelled fields (`Condition:`,
  `Options:`, `Chosen:`, `Why:`, `Reversibility:`, `At:`); a run that resolves
  nothing writes the single line `No autopilot decisions were required`, and
  `30-report.md` carries `Autopilot: true` plus `Autopilot decisions: N`. A
  queue run writes a morning report to `docs/changes/autopilot-YYYY-MM-DD.md`
  when it opened at least one PR, or `specs/autopilot-YYYY-MM-DD.md` when it
  opened none.

### Alternatives Considered

| Alternative | Pros | Cons |
|-------------|------|------|
| A `--autopilot` CLI flag | Conventional CLI ergonomics | The pipeline commands are prompt artifacts, not argv parsers; a flag token invites partial matches (`--autopilot` vs `autopilot`) and a second detection rule |
| Truthy `SPEC_AUTOPILOT` values (`true`, `yes`, `on`) | Forgiving for humans | Non-deterministic: every consumer would need the same truth table; the literal `1` is one rule, one implementation |
| Let the orchestrator keep asking on genuinely ambiguous criteria | Preserves human judgment | The queue stalls overnight — the exact failure autopilot exists to remove; the most conservative reversible option plus a recorded decision preserves reviewability |
| Skip a stopped spec and continue the queue | Finishes more specs per night | Hurts the queue invariant that a hard stop is a stop, and hides the failure that needs morning attention first |
| No decision artifact; agent prose only | Less machinery | A morning reviewer cannot audit what was chosen or why; the audit-trail gate would have nothing to enforce |

## Consequences

- Unattended overnight runs finish specs that only needed documented defaults,
  and every deviation is visible the next morning.
- Autopilot can never merge, tag, push to `main`, or change a gate threshold —
  the pipeline's existing carve-out is unchanged, and the never-list is
  restated where the orchestrator reads it.
- `45-decisions.md` is a new spec-folder artifact; a folder claiming
  `Autopilot: true` without it fails the audit gate.
- Four new script surfaces (`autopilot-trigger.sh`, `autopilot-decisions.sh`,
  `autopilot-preflight.sh`, `autopilot-report.sh`) that are deterministic and
  hermetic-testable, rather than prose instructions the model may drift from.
- A queue run now has a preflight that fails fast on a dirty tree, missing `gh`
  auth, missing tokens, or a missing spec folder — burning a night to discover
  those at 06:00 is no longer possible.

## Compliance

- `scripts/check-stop-and-ask-matrix.sh` requires the `## Autopilot mode`
  section, a disposition for all 12 matrix rows, and no unconditional question
  instruction in any of the nine pipeline agents.
- `scripts/check-audit-trail.sh` requires `45-decisions.md` whenever
  `30-report.md` carries `Autopilot: true`.
- `scripts/tests/autopilot-*.bats` and the extended
  `check-stop-and-ask-matrix.bats` / `check-audit-trail.bats` /
  `record-gate-run.bats` exercise every scenario hermetically.

## Notes

- 2026-10-26: Decision recorded on branch `spec/035-autopilot-mode`.
- ADR numbers 0011 (PR #99) and 0012 (PR #101) are reserved by open pull
  requests; 0013 was the next free number when this ADR was written.
