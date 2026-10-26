# Autopilot mode — tasks

Spec 035. Turns every "stop and ask" in the spec pipeline into "choose the documented
default, record it, continue" when autopilot is on. Stops stay stops. The never-list
stays never. Each task below cites the acceptance scenarios that verify it.

Scenarios are numbered `AC-035-NN` and live in `20-acceptance/AC-035-*.md` (one file
per task). Every scenario must be cited by a bats test in `scripts/tests/` so
`scripts/check-scenario-traceability.sh` resolves it.

---

## Task 1 — Autopilot trigger detection (`scripts/autopilot-trigger.sh`)

**Verifies:** AC-035-01, AC-035-02, AC-035-03, AC-035-04, AC-035-05

A new script that answers one question: is this invocation autopilot?

- The script is `scripts/autopilot-trigger.sh`, executable, shebang `#!/bin/bash`, `set -euo pipefail`.
- Usage: `scripts/autopilot-trigger.sh [ARG ...]`. Reads the `SPEC_AUTOPILOT` environment variable.
- It prints exactly one of two tokens to stdout and exits 0 in both cases: `autopilot` or `normal`.
- Trigger rule (exactly this): any single argv element equal to the string `autopilot` case-insensitively, OR `SPEC_AUTOPILOT` equal to the literal string `1`.
- A trigger is an *exact whole-token* match: `myautopilot`, `autopilot-mode`, `--autopilot` do NOT trigger.
- `SPEC_AUTOPILOT` unset, empty, `0`, or any value other than `1` does NOT trigger.
- No other side effects; it writes nothing to the filesystem.

## Task 2 — `/autopilot` command (`commands/autopilot.md`)

**Verifies:** AC-035-06, AC-035-07, AC-035-08

A new command entry point for an unattended queue run.

- File `commands/autopilot.md` with frontmatter `agent: spec-pipeline` and a description naming autopilot mode.
- Body: `/autopilot <slug> [<slug> ...]` — treats `$ARGUMENTS` as one or more slugs, in order.
- Delegates to `spec-pipeline` with autopilot explicitly on (regardless of any token or `SPEC_AUTOPILOT`).
- Zero slugs → print a usage/error line and stop; do not guess a slug.
- The command itself never asks the user anything and never stops for the human review gate.

## Task 3 — `/spec` and `/build` honor the token

**Verifies:** AC-035-09, AC-035-10

The existing two commands detect the token and switch to autopilot.

- `commands/spec.md`: when the token `autopilot` is present in `$ARGUMENTS` (case-insensitive) or `SPEC_AUTOPILOT=1`, run in autopilot — do not stop after stage 1 for human review; continue the pipeline.
- `commands/build.md`: same detection; when autopilot is on, `spec-coder`/`spec-refactorer`/`spec-verifier`/stage-5 agents resolve every ask per the autopilot disposition and never emit `BLOCKED` or wait for input.
- Both delegate detection to `scripts/autopilot-trigger.sh` rather than re-implementing the token match.
- Neither command changes its non-autopilot behavior.

## Task 4 — `## Autopilot mode` section in `docs/SPEC_PIPELINE.md`

**Verifies:** AC-035-11, AC-035-12, AC-035-13, AC-035-14

The authoritative documentation of autopilot, mechanically checked.

- Add a `## Autopilot mode` section (immediately after `## Stop-and-Ask decision matrix`).
- It states: the trigger (token + `SPEC_AUTOPILOT=1` + `/autopilot` command); the no-questions rule (no stage calls the question tool, emits `BLOCKED — <question>`, or waits for human input; every "ask" row becomes "choose the documented default, record it, continue").
- It contains a row-for-row disposition table mapping **all 12** matrix conditions to their autopilot action (the 12 conditions currently in `## Stop-and-Ask decision matrix`, including `Deploy verification fails`).
- The 12 dispositions are exactly: dirty tree → continue only if every dirty path is inside the current spec folder, else STOP; repo not found → use cwd when a work tree, else STOP; spec artifacts missing → if `00-informal.md` exists run stage 1 and continue, else STOP; project type ambiguous → `mvp` + detected language, record; version bump/tag → never, unchanged; design gate FAIL → fix code never threshold, unchanged; gate WARN → record, unchanged; out-of-scope → record + propose follow-up, unchanged; acceptance criteria ambiguous → most conservative reversible option, record, continue; Verifier FAIL → bounded 3-cycle remediation then STOP; deploy ambiguous → bounded 3 attempts then STOP; PR-opener precondition fails → create `spec/NNN-slug` from current HEAD if branch is the only failure, never push `main`, STOP if report not green.
- It lists the **6** hard stops verbatim (dirty tree outside the current spec folder; no repo / no `00-informal.md` / no way to establish requirements; phase-1 or phase-2 budget exhausted; deploy failure after 3 attempts; `30-report.md` missing or not green at PR time; any never-list action).
- It lists the **9** never-list refusals (no merge, no git tag, no push to `main`/`master`, no force-push, no branch deletion, no gate-threshold change, no secret creation/rotation, no writes outside the target repo, no `git init`/submodule scaffolding), and states these are refusals, not decisions.

## Task 5 — Orchestrator autopilot behavior (`agents/spec-pipeline.md`)

**Verifies:** AC-035-15, AC-035-16, AC-035-17

The orchestrator prompt carries the runtime autopilot rules.

- Add an autopilot section to `agents/spec-pipeline.md` stating: when autopilot is on, never call the question tool, never relay a `BLOCKED — <question>` as a stop, never wait for human input; resolve each ask per the `## Autopilot mode` disposition table and record the decision.
- State the never-list (all 9 refusals) as hard refusals that apply even in autopilot, and that a never-list action is a hard stop, never a decision.
- State the queue rule: process slugs in the given order; at the first hard stop, write the morning report, stop the queue, and do NOT skip to the next slug.
- State that the human review gate between Specifier and Coder is removed only under autopilot; non-autopilot behavior is unchanged.
- Reference the `## Autopilot mode` section and `scripts/autopilot-trigger.sh`.

## Task 6 — Decision artifact `45-decisions.md` and `30-report.md` markers

**Verifies:** AC-035-18, AC-035-19, AC-035-20

Autopilot records every resolved decision.

- `specs/NNN-slug/45-decisions.md` is written whenever autopilot resolves anything; one entry per decision.
- Each entry records six fields, each on its own line with a fixed label: `Condition:`, `Options:`, `Chosen:`, `Why:`, `Reversibility:`, `At:` (the last an ISO-8601 UTC timestamp `YYYY-MM-DDTHH:MM:SSZ`).
- A run with zero decisions writes a single line, verbatim: `No autopilot decisions were required`.
- `30-report.md` gains two lines: `Autopilot: true` and `Autopilot decisions: N` where `N` is a non-negative integer equal to the number of entries in `45-decisions.md` (0 for the empty line).
- The decision count in `30-report.md` must equal the number of decision entries in `45-decisions.md`; a mismatch is a defect.

## Task 7 — Morning report

**Verifies:** AC-035-21, AC-035-22, AC-035-23

A queue run leaves a human-readable report of the night's work.

- Location rule: `docs/changes/autopilot-YYYY-MM-DD.md` when the run opened at least one PR; `specs/autopilot-YYYY-MM-DD.md` when it opened none. `YYYY-MM-DD` is the UTC date the queue started.
- The report contains, per spec in queue order up to and including the stopping spec: a status block with the slug and a terminal status (PR URL, or the stop reason).
- The report contains a `Decisions` section (or per-spec decision references to `45-decisions.md`), a `Stop reasons` section when any spec stopped, and a `Follow-up proposals` section when any out-of-scope finding was recorded.
- The report is written even when the queue stops at the first hard stop.

## Task 8 — Preflight (`scripts/autopilot-preflight.sh`)

**Verifies:** AC-035-24, AC-035-25, AC-035-26, AC-035-27

Fail fast before burning a night.

- Script `scripts/autopilot-preflight.sh [SLUG ...]`, `set -euo pipefail`; exits 0 when every prerequisite holds, non-zero with a one-line written reason otherwise.
- Checks, in order: (1) inside a git repo with a resolvable HEAD; (2) `gh auth status` succeeds; (3) `GITHUB_TOKEN` and `GH_TOKEN` are non-empty; (4) the clean-tree rule — every dirty path is inside `specs/<current-slug>/` for the slug being processed; (5) each named slug's spec folder exists.
- On the first failing check it prints `preflight: <reason>` to stderr and exits non-zero; it does not continue to later checks.
- Judgment backend check is best-effort: if `JUDGMENT_*` is unconfigured or the backend is unreachable it proceeds (it never fails preflight for a missing optional backend); if `JUDGMENT_BACKEND` is explicitly set and unreachable it records a warning but still exits 0.
- Preflight runs before each queue item, re-evaluating the clean-tree rule against the current slug.

## Task 9 — Telemetry (`scripts/record-gate-run.sh`)

**Verifies:** AC-035-28, AC-035-29

The gate-run record carries autopilot fields.

- Extend `record-gate-run.sh`'s documented schema with three optional fields: `autopilot` (boolean `true`/`false`), `autoDecisions` (non-negative integer), `stopReason` (string).
- When `autopilot` is present it must be exactly `true` or `false`; any other value → validation failure (exit 1, nothing appended).
- When `autoDecisions` is present it must match `^[0-9]+$`; any other value → exit 1, nothing appended.
- `stopReason`, when present, must be a non-empty string; it is recorded when a run stops.
- The fields pass through to the appended JSON record unchanged (append-only, same file contract). The orchestrator/Verifier populate them for autopilot runs; the record is otherwise identical to a non-autopilot record.

## Task 10 — Enforcement: extend `scripts/check-stop-and-ask-matrix.sh`

**Verifies:** AC-035-30, AC-035-31, AC-035-32

The matrix gate now also enforces the autopilot contract.

- Add checks that FAIL (exit 1, `FAIL AC-035-…` line) when: the `## Autopilot mode` section is absent from `docs/SPEC_PIPELINE.md` (AC-035-30).
- Require a disposition for every matrix row: the autopilot section must contain a conversion for **all 12** matrix conditions. Reconcile the existing 11-entry row list: add the missing `Deploy verification fails` condition/action to `ROW_CONDITIONS`/`ROW_ACTIONS` so the base matrix check also covers 12 rows (AC-035-31).
- Add an unconditional-question check: for each of the 9 pipeline agent files, a question-instruction phrase (`BLOCKED —`, `ask the user`, `stop and ask`, `ask one specific question`, `ask one question`, `Ask for the absolute path`) is a violation unless the same file references the autopilot conversion (the `Autopilot mode` section) so the ask is conditioned on non-autopilot (AC-035-32).
- New checks cite `AC-035-30`, `AC-035-31`, `AC-035-32` in their PASS/FAIL output so traceability resolves them.
- Do not change the existing 9-agent reference list, the gate-config lock (AC-009-03-*), or the Confluence check.

## Task 11 — Enforcement: extend `scripts/check-audit-trail.sh`

**Verifies:** AC-035-33, AC-035-34, AC-035-35

The audit gate enforces the decision artifact.

- When `specs/<slug>/30-report.md` contains a line matching `^Autopilot:[[:space:]]*true$`, then `specs/<slug>/45-decisions.md` must exist and be non-empty; otherwise the folder FAILs (AC-035-33).
- With the marker present and `45-decisions.md` present and non-empty, the folder passes (AC-035-34).
- With no `Autopilot: true` marker, `45-decisions.md` is optional — its presence or absence does not affect the verdict (AC-035-35).
- Add a `--selftest` case for the marker-present-but-missing-artifact negative path, mirroring the existing fixture style.

## Task 12 — Bats coverage and traceability

**Verifies:** AC-035-36 (plus every scenario AC-035-01..AC-035-35 is traced by a test)

Shell tests for every scenario above.

- Add bats fixtures under `scripts/tests/` (e.g. `autopilot-trigger.bats`, `autopilot-preflight.bats`, `autopilot-report.bats`, and extensions to `check-stop-and-ask-matrix.bats` / `check-audit-trail.bats` / `record-gate-run.bats`) covering: trigger parsing, every disposition row, every hard stop, the never-list refusal, queue stop-at-first-hard-stop, morning-report shape, `45-decisions.md` presence/absence, and the unconditional-question static assertion.
- Every `AC-035-NN` scenario ID (01–36) is cited in at least one bats test (as `AC-035-NN` or `AC_035_NN`), so `scripts/check-scenario-traceability.sh` check 1 resolves each to a test.
- A repo-level static assertion test (AC-035-36) greps all 9 pipeline agents plus `spec-pipeline.md` and asserts none contains an unconditional question path: `scripts/check-stop-and-ask-matrix.sh` exits 0 against the real repo.
- `make test-scripts` (bats) and `scripts/check-scenario-traceability.sh` both pass.

## Task 13 — ADR 0013 (mandatory)

**Verifies:** AC-035-37, AC-035-38

This is a pipeline-role change; an ADR is required, not optional.

- Write `docs/adr/0013-autopilot-mode.md` following `templates/ADR.md`: `## Status: Accepted`, plus `## Context`, `## Decision`, `### Alternatives Considered` (table), `## Consequences`, `## Compliance` (naming `check-stop-and-ask-matrix.sh` and `check-audit-trail.sh` as the enforcement), and `## Notes`.
- The decision states the trigger, the ask→decide conversion, that stops stay stops, the never-list, and the `45-decisions.md` + morning-report artifacts.
- Add a row for ADR 0013 to the index table in `docs/adr/README.md` with a title and `Accepted` status.
- Record in Notes: the reservation of 0011 (PR #99) and 0012 (PR #101) and that 0013 is the next free number.

---

## Open questions (need a human answer before `/build`)

1. **Matrix row count is 12, not 11.** `docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix` has **12** condition rows today — spec 031 added `Deploy verification fails` — but `scripts/check-stop-and-ask-matrix.sh`'s `ROW_CONDITIONS`/`ROW_ACTIONS` list only **11**, omitting that row. The informal spec's disposition list has 12 entries. Task 4 and Task 10 assume 12 rows and that the enforcement script's row list is reconciled to 12. Confirm that adding the missing 12th row to the script is in scope (it is a pre-existing gap, not introduced by autopilot).

2. **`SPEC_AUTOPILOT` truthy values.** The informal spec says `SPEC_AUTOPILOT=1`. Task 1 treats only the literal `1` as on. Confirm `=true`/`=yes` are out of scope (default: only `1`).

3. **`/spec autopilot` semantics.** The informal spec says `/spec` "honors the token." Does `/spec autopilot <slug>` continue the whole SDLC (human gate removed), or still stop after stage 1? Task 3 assumes it continues (the human gate is the interruption autopilot removes). Confirm.

4. **`--autopilot` flag form.** Should a `--autopilot` flag also trigger? Task 1 treats only the standalone token `autopilot` as triggering. Confirm flags are out of scope.

5. **Morning-report generator.** Task 7 defines the report's location and required sections but not *who* assembles it. For a bats-testable shape, I propose a small deterministic writer (`scripts/autopilot-report.sh`) that the orchestrator feeds a per-spec manifest. Confirm a script is acceptable, or specify the orchestrator writes freeform and bats only greps a documented template.

6. **Exact marker strings.** Task 6 fixes `Autopilot: true` and `Autopilot decisions: N` in `30-report.md`, and the six field labels `Condition:`/`Options:`/`Chosen:`/`Why:`/`Reversibility:`/`At:` in `45-decisions.md`. Confirm these literals (or provide the canonical spellings).

7. **Telemetry `stopReason` coupling.** Task 9 treats `stopReason` as an optional string recorded on stop, without asserting it must coincide with `outcome: block`. Confirm no stronger coupling is required.

8. **Unconditional-question phrase set.** Task 10's static check scans a fixed phrase list. Confirm the six phrases are the complete set, or extend it. (The concrete ask-phrases found today: `spec-ux.md` emits `BLOCKED — <one question>`; the matrix rows say "Ask for the absolute path once" / "stop and ask one specific question".)
