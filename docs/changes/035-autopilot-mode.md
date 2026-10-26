# 035-autopilot-mode

> Spec pipeline archive. Original source: `specs/035-autopilot-mode/` (deleted by this script).
> Archived: 2026-10-26

## Original ask

# Informal spec: autopilot mode

## The ask

"If the user says autopilot, you do not ask any questions, you continue the whole
SDLC and find out any gap [without] asking. This is important for nights."

## What exists today

- `docs/SPEC_PIPELINE.md` §Stop-and-Ask decision matrix is authoritative for every
  pipeline stage. Several rows say "stop and ask" or "ask once".
- `/spec` deliberately stops after stage 1 for human review. `/build` requires
  `10-tasks.md` and `20-acceptance/` and stops if they are missing.
- Agents emit `BLOCKED — <question>` (`spec-ux`) and rely on the orchestrator
  relaying the question.
- `scripts/check-stop-and-ask-matrix.sh` mechanically verifies the matrix and the
  nine agent references to it.
- Budgets already exist and are not changed by this feature: phase-1 remediation
  max 3, phase-2 CI max 3.

## Required behavior

1. **Trigger.** The literal token `autopilot` (case-insensitive) in the invocation,
   or `SPEC_AUTOPILOT=1`. New command `/autopilot <slug> [<slug> ...]`. `/spec`
   and `/build` also honor the token when present in their arguments.
2. **No questions.** In autopilot, no stage calls the question tool, emits
   `BLOCKED — question`, or waits for human input. Every "ask" row becomes
   "choose the documented default, record it, continue".
3. **Stops stay stops.** Autopilot only converts *ask* into *decide*. It never
   converts a safety stop into a guess. Hard stops in autopilot:
   - dirty tree outside `specs/<current-slug>/`;
   - no repo, no `00-informal.md`, no way to establish requirements;
   - Verifier/phase-1 budget exhausted (3 cycles) or phase-2 budget exhausted
     (3 rounds);
   - deploy failure after its own 3 attempts;
   - `30-report.md` missing or not green at PR time;
   - any action on the never-list below.
4. **Autopilot disposition for every matrix row.** `docs/SPEC_PIPELINE.md` gains an
   `## Autopilot mode` section with a row-for-row conversion table:
   - dirty tree: continue only if every dirty path is inside the current spec
     folder; otherwise STOP.
   - repo not found: use cwd when it is a work tree; otherwise STOP.
   - spec artifacts missing: if `00-informal.md` exists, run stage 1 and continue;
     otherwise STOP (requirements cannot be invented).
   - project type ambiguous: use `mvp` and the detected language; record.
   - version bump/tag: never; unchanged.
   - design gate FAIL: fix code, never the threshold; unchanged.
   - gate WARN: record; unchanged.
   - out-of-scope finding: record and propose a follow-up; unchanged (plus log).
   - acceptance criteria ambiguous: pick the most conservative option that keeps
     the PR draft and is reversible, record it, continue.
   - Verifier FAIL: bounded 3-cycle remediation, then STOP.
   - deploy ambiguous: bounded 3 attempts, then STOP.
   - PR-opener precondition fails: create `spec/NNN-slug` from the current HEAD
     if the branch is the only failure; never push to `main`; STOP if the report
     is not green.
5. **Decision artifact.** `specs/NNN-slug/45-decisions.md`, written whenever
   autopilot resolves anything. One entry per decision: condition, options,
   chosen, why (evidence), reversibility, UTC timestamp. Empty runs write a single
   `No autopilot decisions were required` line. `30-report.md` carries
   `Autopilot: true` and the decision count.
6. **Morning report.** A queue run (`/autopilot a b c`) writes
   `docs/changes/autopilot-YYYY-MM-DD.md` (or `specs/autopilot-YYYY-MM-DD.md` if
   the run opens no PR) with per-spec status, PR URLs, decisions, stop reasons,
   and follow-up proposals. A queue stops at the first hard stop; it does not
   skip ahead to the next spec.
7. **Never-list (hard, even in autopilot).** No merge, no git tag, no push to
   `main`/`master`, no force-push, no branch deletion, no gate-threshold change,
   no secret creation/rotation, no writes outside the target repo, no
   `git init`/submodule scaffolding. These are refusals, not decisions.
8. **Preflight.** Before a queue starts: branch/HEAD, `gh` auth and both tokens,
   clean tree rule, spec folder existence, optional judgment backend. Missing
   prerequisites fail fast with a written reason instead of burning the night.
9. **Telemetry.** `record-gate-run.sh` records `autopilot: true`,
   `autoDecisions: N`, and `stopReason` when a run stops.
10. **Enforcement.** Extend `scripts/check-stop-and-ask-matrix.sh` to require the
    autopilot section and a disposition for every matrix row, and to fail if a
    pipeline agent instructs an unconditional question. `check-audit-trail.sh`
    requires `45-decisions.md` when `30-report.md` says `Autopilot: true`.
11. **Tests.** Bats fixtures for: trigger parsing, every conversion row, every
    hard stop, the never-list refusal, queue stop-at-first-hard-stop, morning
    report shape, `45-decisions.md` presence/absence, and a static assertion that
    no pipeline agent contains an unconditional `ask the user` path.

## Out of scope

- Unattended merging, tagging, or releasing.
- More remediation budget than the existing 3+3.
- Provisioning credentials, repos, or Vercel projects.
- Changing any gate threshold.

## Decisions taken under autopilot while writing this spec

- ADR 0013 is required (pipeline-role change); 0011 is reserved by PR #99, 0012 by
  PR #101.
- Decision artifact number is `45-decisions.md` so it never collides with the
  fixed 00/10/15/20/25/30/40 sequence.
- Default for an ambiguous acceptance criterion is the **most conservative,
  reversible** option; anything irreversible is a hard stop, not a decision.
- A queue stops at the first hard stop rather than skipping the spec, because
  silently skipping is how a night run hides a broken repo.

## Specifier questions, resolved

- SQ-1 — **Reconcile to 12 rows.** The matrix has 12; the checker's
  `ROW_CONDITIONS` omits `Deploy verification fails`. Fixing that omission is in
  scope; it is the enforcement gap this feature depends on.
- SQ-2 — **`SPEC_AUTOPILOT=1` only.** Literal `1`; no `true`/`yes` aliases.
- SQ-3 — **`/spec autopilot` continues the whole SDLC.** The human gate is
  replaced by `45-decisions.md`. A bare `/spec` without the token still stops.
- SQ-4 — **No `--autopilot` flag.** The standalone token is the only trigger.
- SQ-5 — **Deterministic `scripts/autopilot-report.sh`.** Generated from the
  per-spec decision logs; bats-testable, not freeform prose.
- SQ-6 — **Markers:** `Autopilot: true`, `Autopilot decisions: N`, and the six
  field labels `Condition`, `Options`, `Chosen`, `Why`, `Reversibility`, `At`.
- SQ-7 — **`stopReason` is optional.** It is recorded when a run stops, not on
  every record.
- SQ-8 — **Six-phrase question set is the floor, not the ceiling.** The coder may
  add phrases its tests prove; it may not remove one.

## Tasks

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

## Acceptance scenarios

## AC-035-01 — Literal token `autopilot` (any case) triggers
## AC-035-02 — `SPEC_AUTOPILOT=1` triggers without a token
## AC-035-03 — No token and unset env is not autopilot
## AC-035-04 — Non-`1` env value is not autopilot
## AC-035-05 — Token inside a larger word is not a trigger
## AC-035-06 — Single slug runs the whole pipeline unattended
## AC-035-07 — Multiple slugs form an ordered queue
## AC-035-08 — No slug is a usage error
## AC-035-09 — `/spec` with the token does not stop for human review
## AC-035-10 — `/build` with the token runs stages 2-5 in autopilot
## AC-035-11 — Section declares trigger and no-questions rule
## AC-035-12 — A disposition exists for all 12 matrix rows
## AC-035-13 — All 6 hard stops are listed
## AC-035-14 — All 9 never-list refusals are listed
## AC-035-15 — No questions in autopilot
## AC-035-16 — Never-list refusals are hard even in autopilot
## AC-035-17 — Queue stops at the first hard stop
## AC-035-18 — Each decision entry records six fields
## AC-035-19 — Empty run writes the single no-decision line
## AC-035-20 — `30-report.md` carries autopilot and the decision count
## AC-035-21 — PR opened → report under `docs/changes/`
## AC-035-22 — No PR → report under `specs/`
## AC-035-23 — Report shape
## AC-035-24 — Clean tree (or dirty only inside the spec folder) passes
## AC-035-25 — `gh` auth and both tokens are required
## AC-035-26 — Spec folder must exist
## AC-035-27 — Judgment backend is optional
## AC-035-28 — Record accepts the autopilot fields
## AC-035-29 — Invalid autopilot field values are rejected
## AC-035-30 — Missing autopilot section FAILs
## AC-035-31 — Missing disposition for a matrix row FAILs
## AC-035-32 — An unconditional question in an agent FAILs
## AC-035-33 — `Autopilot: true` without `45-decisions.md` FAILs
## AC-035-34 — `Autopilot: true` with `45-decisions.md` passes
## AC-035-35 — No marker → `45-decisions.md` is optional
## AC-035-36 — No pipeline agent contains an unconditional ask path
## AC-035-37 — ADR file exists and follows the template
## AC-035-38 — ADR is indexed

## Verification

# Verification — spec 035 autopilot mode

- **Attempt:** 1, phase 1 (full verification, first run)
- **Branch:** `spec/035-autopilot-mode`
- **Base ref:** `main`
- **Verifier:** stage 4. Re-executed every gate; no production code written; nothing committed or pushed.
- **Overall verdict: PASS**

Every prior stage's claim was treated as unverified until re-run below. The Coder and
Refactorer write no report artifact; the commands and exit codes in this file are the
record of what was actually executed.

## Check summary

| # | Check | Verdict | Command | Exit |
|---|---|---|---|---|
| 1 | Scenario traceability | PASS | `scripts/check-scenario-traceability.sh --json` | 0 |
| 2 | Full test suite (run 1) | PASS | `make test-scripts` | 0 |
| 2 | Full test suite (run 2) | PASS | `make test-scripts` | 0 |
| 3 | Complexity gate | PASS | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` | 0 |
| 3.5 | Design-principles gate | PASS (change-scoped) | `scripts/check-code-principles.sh -BaseRef main --json` | 0 |
| 4 | Scenario-to-behavior spot check | PASS | manual cross-check of AC-035-04, AC-035-21, AC-035-33 | 0 |
| 5 | No unaccounted behavior | PASS (finding line) | diff skim | — |

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-26T08:27:43Z

```
{
  "checks": [1, 2],
  "passes": ["AC-035-01 — traced to a test", "AC-035-02 — traced to a test", "AC-035-03 — traced to a test", "AC-035-04 — traced to a test", "AC-035-05 — traced to a test", "AC-035-06 — traced to a test", "AC-035-07 — traced to a test", "AC-035-08 — traced to a test", "AC-035-09 — traced to a test", "AC-035-10 — traced to a test", "AC-035-11 — traced to a test", "AC-035-12 — traced to a test", "AC-035-13 — traced to a test", "AC-035-14 — traced to a test", "AC-035-15 — traced to a test", "AC-035-16 — traced to a test", "AC-035-17 — traced to a test", "AC-035-18 — traced to a test", "AC-035-19 — traced to a test", "AC-035-20 — traced to a test", "AC-035-21 — traced to a test", "AC-035-22 — traced to a test", "AC-035-23 — traced to a test", "AC-035-24 — traced to a test", "AC-035-25 — traced to a test", "AC-035-26 — traced to a test", "AC-035-27 — traced to a test", "AC-035-28 — traced to a test", "AC-035-29 — traced to a test", "AC-035-30 — traced to a test", "AC-035-31 — traced to a test", "AC-035-32 — traced to a test", "AC-035-33 — traced to a test", "AC-035-34 — traced to a test", "AC-035-35 — traced to a test", "AC-035-36 — traced to a test", "AC-035-37 — traced to a test", "AC-035-38 — traced to a test"],
  "fails": []
}
```

Both traceability checks ran (`"checks": [1, 2]`), all 38 scenario IDs (AC-035-01 …
AC-035-38) are cited by at least one test, and every test reference resolves. No fails.

---

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T08:18:33Z

Run 1 — raw output excerpt (head, autopilot cases, tail):

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 65 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..529
ok 167 AC-035-37 — ADR 0013 exists, follows the template, and records every required decision
ok 168 AC-035-38 — ADR 0013 is indexed with a title and Accepted status
ok 169 AC-035-06 — /autopilot runs one slug unattended with autopilot on and no human gate
ok 170 AC-035-07 — /autopilot with several slugs is an ordered queue of independent runs
ok 171 AC-035-08 — /autopilot with no slugs prints usage and stops without guessing
ok 172 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 173 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 174 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 176 AC-035-11 — the section declares the trigger and the no-questions rule
ok 177 AC-035-12 — a disposition exists for all 12 matrix rows, including Deploy verification fails
ok 178 AC-035-13 — all 6 hard stops are listed and never converted into a guess
ok 179 AC-035-14 — all 9 never-list refusals are listed as refusals, not decisions
ok 180 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
ok 181 AC-035-15 — the orchestrator never asks in autopilot and records each resolved ask
ok 182 AC-035-16 — the 9 never-list actions are hard refusals, never decisions
ok 183 AC-035-17 — the queue stops at the first hard stop and writes the morning report
ok 184 AC-035-24 — a tree dirty only inside specs/<slug>/ passes
ok 185 AC-035-25 — gh auth, GITHUB_TOKEN, and GH_TOKEN are required and fail fast
ok 186 AC-035-26 — a named slug whose spec folder does not exist fails with a reason
ok 187 AC-035-27 — the judgment backend is optional and never fails preflight
ok 189 AC-035-21 — a queue that opened a PR writes docs/changes/autopilot-YYYY-MM-DD.md
ok 190 AC-035-22 — a queue that opened no PR writes specs/autopilot-YYYY-MM-DD.md
ok 191 AC-035-23 — the report has ordered per-spec blocks and the conditional sections
ok 193 AC-035-09 — /spec with the token continues instead of stopping for human review
ok 194 AC-035-10 — /build with the token resolves asks per autopilot and never emits BLOCKED
ok 195 AC-035-01 — literal token autopilot in any case triggers
ok 196 AC-035-02 — SPEC_AUTOPILOT=1 triggers without a token
ok 197 AC-035-03 — no token and unset env is not autopilot
ok 198 AC-035-04 — any SPEC_AUTOPILOT value other than the literal 1 is not autopilot
ok 199 AC-035-05 — the token inside a larger word is not a trigger
ok 205 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 206 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 207 AC-035-35 — without the marker, 45-decisions.md is optional either way
ok 324 AC-035-30 — a matrix without the Autopilot mode section FAILs AC-035-30
ok 325 AC-035-31 — a missing disposition for one matrix row FAILs AC-035-31 naming it
ok 326 AC-035-32 — an unconditional question phrase with no autopilot reference FAILs AC-035-32
ok 327 unit — the complete fixture passes the autopilot checks (exit 0)
ok 395 AC-035-28 — the optional autopilot fields are accepted and appended unchanged
ok 396 AC-035-29 — invalid autopilot field values are rejected, naming the field, appending nothing
...
ok 527 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 528 wire: non-numeric confidence is invalid, exits 10
ok 529 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts run 1: `529` `ok`, `0` `not ok`; plan `1..529`; make exit 0.

### Full test suite — second full execution (required re-run)

command: make test-scripts
exit: 0
at: 2026-10-26T08:22:04Z

Run 2 — raw output excerpt (head and tail; full TAP plan and counts):

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 65 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..529
...
ok 525 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 526 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 527 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 528 wire: non-numeric confidence is invalid, exits 10
ok 529 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts run 2: `529` `ok`, `0` `not ok`; plan `1..529`; make exit 0.

No test is skipped or disabled: the TAP plan is `1..529` with 529 `ok` lines and zero
`not ok` lines in both runs. The bats assertion-vacuity pre-check (`check-bats-assertions`,
65 files) also passes in both runs.

---

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T08:27:45Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

This repo has no compiled Java/Go/JS production source in the change; the applicable
complexity gate is the repo's own `complexity` category (the same ≤6 rule PMD /
golangci-lint `cyclop` / ESLint `complexity` enforce in child repos), run blame-scoped
to the change against `main`. Zero failures, zero warnings.

---

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef main --json
exit: 0
at: 2026-10-26T08:27:46Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

Change-scoped run: zero FAIL lines and zero WARN lines. Every changed shell script in
the diff (the four new `scripts/autopilot-*.sh`, the extended
`check-stop-and-ask-matrix.sh` / `check-audit-trail.sh` / `record-gate-run.sh`) is
judged under all six categories with no finding.

### Pre-existing unscoped finding (NOT introduced by this change — recorded, not smoothed over)

For completeness, the same gate run **unscoped** over the whole tree exits 1 with one
pre-existing FAIL in a vendored example file this branch does not touch:

command: scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-26T08:30:05Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [{ "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "93" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" }, { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" }, { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }]
}
```

Reproduction on the base ref proves it is pre-existing debt, not a finding against this
spec — a clean `main` worktree gives the identical exit code and identical FAIL:

command: (in `git worktree add /tmp/opencode/main-wt main`) scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-26T08:25:00Z

```
{
  "fails": [
    {
      "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10",
      "file": "./skills/hallmark/site/examples/cobalt-01/script.js",
      "line": "7"
    }
  ]
}
```

`git status` shows no change under `skills/` on this branch. The verdict for this gate is
therefore PASS for the change; the pre-existing finding is flagged to the Architect as a
follow-up candidate (never fixed by the Verifier).

---

## Evidence: scenario-to-behavior spot check

command: manual cross-check of acceptance scenarios AC-035-04, AC-035-21, AC-035-33 against the assertions in scripts/tests/*.bats
exit: 0
at: 2026-10-26T08:26:00Z

Three scenarios drawn from different acceptance files were read alongside their tests
and their live behavior, not just their IDs:

1. **AC-035-04 (AC-035-trigger.md)** — Given `autopilot-trigger.sh`, `SPEC_AUTOPILOT=0`
   (also empty, `true`, `yes`), When it runs, Then it prints exactly `normal` and exits 0.
   `scripts/tests/autopilot-trigger.bats` loops `0 true yes 01 on ""`, asserts
   `status -eq 0` and `output = normal` for each. Direct execution confirmed
   `SPEC_AUTOPILOT=0 → normal`, `true → normal`, `yes → normal`, `"" → normal`,
   `01 → normal`. Assertions match the Given/When/Then.

2. **AC-035-21 (AC-035-morning-report.md)** — Given a queue that opened ≥1 PR, When it
   finishes or stops, Then the report lands at `docs/changes/autopilot-YYYY-MM-DD.md`
   with the UTC queue-start date. `autopilot-report.bats` invokes the writer with
   `--date 2026-10-26`, asserts stdout is exactly
   `docs/changes/autopilot-2026-10-26.md`, asserts the file exists, and greps the PR URL
   out of it. The writer defaults the date to `date -u +%Y-%m-%d` (UTC) and rejects a
   malformed date. Assertions match the scenario.

3. **AC-035-33 (AC-035-audit-enforcement.md)** — Given `30-report.md` contains
   `Autopilot: true` and `45-decisions.md` is missing or empty, When the audit gate runs,
   Then the folder FAILs and the gate exits non-zero. `check-audit-trail.bats` asserts
   status 1 and `45-decisions.md` in the output for both the missing-file and the
   empty-file case; the script's own `--selftest` independently exercises both fixtures
   (`AC-035-33 … exits non-zero (exit 1)` twice). Assertions match the scenario.

No false green found: each test asserts the scenario's concrete outcome, not merely the
presence of an ID.

---

## No unaccounted behavior

Finding line: the change set is fully accounted for by `10-tasks.md` Tasks 1–13. Every
production file maps to a task — `scripts/autopilot-trigger.sh` (Task 1),
`commands/autopilot.md` (Task 2), `commands/spec.md` + `commands/build.md` (Task 3),
`docs/SPEC_PIPELINE.md §Autopilot mode` (Task 4), `agents/spec-pipeline.md` (Task 5),
`scripts/autopilot-decisions.sh` (Task 6), `scripts/autopilot-report.sh` (Task 7),
`scripts/autopilot-preflight.sh` (Task 8), `scripts/record-gate-run.sh` (Task 9),
`scripts/check-stop-and-ask-matrix.sh` (Task 10), `scripts/check-audit-trail.sh`
(Task 11), the bats suite (Task 12), `docs/adr/0013-autopilot-mode.md` +
`docs/adr/README.md` (Task 13). Two changes deserve an explicit justification and are
accounted for:

- `agents/spec-ux.md` — gains an `# Autopilot mode` section. This is required by Task
  10's AC-035-32: `spec-ux.md` carries ask phrases (`BLOCKED —`, `ask one question`), so
  without the autopilot-conversion reference the static scan would (correctly) FAIL it.
- `scripts/tests/typed-judgment-integration.bats` — the AC-029-74 "consumer files carry
  zero changes" assertion is narrowed so `agents/spec-ux.md` may change only additively
  and only with an `Autopilot mode` block, while `skills/ci-triage/SKILL.md` stays
  byte-identical. This is a test-contract update made necessary by the in-scope
  `spec-ux.md` change, not new behavior.

No production logic, flag, or artifact appears that no task or scenario accounts for.

---

## Targeted checks requested by the orchestrator

### Matrix is 12 rows, and the gate enforces all 12

Row counts (data rows, header and separator excluded):

```
Stop-and-Ask decision matrix table: 12
Autopilot mode disposition table:   12
ROW_CONDITIONS in check-stop-and-ask-matrix.sh: 12
```

The previously omitted `Deploy verification fails` row is now enforced in the base matrix
list. Scratch copy with only that base row deleted (`/tmp/opencode/verify035/a`):

```
command: scripts/check-stop-and-ask-matrix.sh /tmp/opencode/verify035/a
exit: 1

FAIL matrix row missing or altered: condition [Deploy verification fails] action [Route per fix-routing rule; on ambiguous failure, STOP and escalate to human; never guess]
FAIL AC-009-01-03 — at least one of the 12 matrix rows is missing or altered
```

A scratch copy missing the `## Autopilot mode` section (`/tmp/opencode/verify035/c`)
FAILs AC-035-30 and exits 1:

```
FAIL AC-035-30 — docs/SPEC_PIPELINE.md is missing the '## Autopilot mode' section
FAIL AC-035-31 — no autopilot disposition for matrix condition [Working tree dirty]
...
FAIL AC-035-31 — no autopilot disposition for matrix condition [Deploy verification fails]
FAIL AC-035-31 — at least one of the 12 matrix conditions has no autopilot disposition
FAIL AC-009-04-02 — 14 violation(s); script exits 1
```

A scratch copy missing only the `Deploy verification fails` autopilot disposition
(`/tmp/opencode/verify035/b`) FAILs AC-035-31 naming that exact condition and exits 1:

```
FAIL AC-035-31 — no autopilot disposition for matrix condition [Deploy verification fails]
FAIL AC-035-31 — at least one of the 12 matrix conditions has no autopilot disposition
FAIL AC-009-04-02 — 2 violation(s); script exits 1
```

### The unconditional-question static scan bites

Planted `Ask the user before continuing.` in a scratch copy of
`agents/spec-coder.md` (the real tree is untouched). The scan FAILs AC-035-32 and exits 1:

```
FAIL AC-035-32 — spec-coder.md contains the unconditional question phrase [ask the user] with no 'Autopilot mode' conversion reference
FAIL AC-035-32 — at least one pipeline agent may still ask unconditionally in autopilot
FAIL AC-009-04-02 — 2 violation(s); script exits 1
```

Control: the same phrase planted in `agents/spec-ux.md`, which does reference the
autopilot conversion, keeps the check green (`PASS AC-035-32`, exit 0) — so the scan is
conditioned on the reference, not a blanket phrase ban.

### Hard stops and the never-list

`docs/SPEC_PIPELINE.md §Autopilot mode` lists all six hard stops verbatim
(dirty tree outside the current spec folder; no repo / no `00-informal.md` / no way to
establish requirements; phase-1 or phase-2 budget exhausted; deploy failure after 3
attempts; `30-report.md` missing or not green at PR time; any never-list action) and all
nine refusals (no merge; no git tag; no push to `main`/`master`; no force-push; no branch
deletion; no gate-threshold change; no secret creation/rotation; no writes outside the
target repo; no `git init`/submodule scaffolding), with the explicit statement that
these are refusals, not decisions. `agents/spec-pipeline.md` restates all nine as hard
refusals and states a never-list action is a hard stop, never a decision.

Enforced by test: `autopilot-doc-section.bats` AC-035-13 asserts each hard stop and the
"never converts a hard stop into a guess" sentence; AC-035-14 asserts each of the nine
refusals and "refusals, not decisions"; `autopilot-orchestrator.bats` AC-035-16 asserts
the nine refusals in the orchestrator plus "hard stop" / "never a decision". Both passed
in both full suite runs.

No autopilot path can merge, tag, or push `main`: the nine refusals are unconditional,
the commit-and-push carve-out is unchanged and still limited to `spec/NNN-slug`, and no
new script or command contains a merge/tag/push-main command. There is no such FAIL.

### `45-decisions.md` contract

Live smoke of the deterministic writer (`/tmp/opencode/vdec`):

```
$ scripts/autopilot-decisions.sh add 45-decisions.md --condition 'Acceptance criteria ambiguous' \
    --options 'conservative; rewrite' --chosen 'conservative' --why 'reversible' \
    --reversibility 'high' --at 2026-10-26T03:14:07Z
exit 0
Condition: Acceptance criteria ambiguous
Options: conservative; rewrite
Chosen: conservative
Why: reversible
Reversibility: high
At: 2026-10-26T03:14:07Z

$ scripts/autopilot-decisions.sh count 45-decisions.md
1

$ scripts/autopilot-decisions.sh mark-report 45-decisions.md 30-report.md
# Report
Final status: green

Autopilot: true
Autopilot decisions: 1

$ scripts/autopilot-decisions.sh none empty-run.md
No autopilot decisions were required          # exactly 1 line, wc -l = 1

$ scripts/autopilot-decisions.sh add bad.md ... --at '26-10-2026'
autopilot-decisions: At must be an ISO-8601 UTC timestamp YYYY-MM-DDTHH:MM:SSZ (got '26-10-2026')
exit 1
no file written (correct)
```

The six labels, ISO-8601 `At`, the exact single-line clean-run artifact, and
`Autopilot: true` / `Autopilot decisions: N` are all present and tested (AC-035-18/19/20
pass). Audit-trail requirement when `30-report.md` says `Autopilot: true`: the gate's own
selftest passes `AC-035-33` twice (missing and empty `45-decisions.md` both exit 1),
`AC-035-34` (non-empty → exit 0), and `AC-035-35` (optional without the marker, present
and absent → exit 0); `check-audit-trail.bats` repeats the same three cases and passed.

### Trigger: whole token only

Direct execution of `scripts/autopilot-trigger.sh` (all exits 0, output is the verdict):

```
token=autopilot      -> autopilot
token=AUTOPILOT      -> autopilot
token=AutoPilot      -> autopilot
token=--autopilot    -> normal
token=myautopilot    -> normal
token=autopilot-mode -> normal
token=autopilot.js   -> normal
SPEC_AUTOPILOT=1     -> autopilot
SPEC_AUTOPILOT=0     -> normal
SPEC_AUTOPILOT=true  -> normal
SPEC_AUTOPILOT=yes   -> normal
SPEC_AUTOPILOT=''    -> normal
SPEC_AUTOPILOT=01    -> normal
unset                -> normal
```

`--autopilot` and `myautopilot` do not trigger; only the literal `1` is truthy for
`SPEC_AUTOPILOT`. `autopilot-trigger.bats` AC-035-01..05 asserts the same set (including
`myautopilot`, `autopilot-mode`, `--autopilot`, `autopilot.js`, `mode-autopilot`).

### Preflight is fail-fast and offline-safe

`scripts/autopilot-preflight.sh` checks in the documented order and `die`s on the first
failure (`preflight: <reason>` to stderr, non-zero, later checks do not run).
`autopilot-preflight.bats` is hermetic: `gh` is a stub on `PATH`
(`cat > "$STUB/gh" <<'SH' … exit "${GH_STUB_EXIT:-0}"`), tokens are literals, and the
optional judgment backend is probed only against `http://127.0.0.1:1` (instant refusal).
No test invokes live `gh`, and the suite passed in both full runs. AC-035-24..27 pass.

### ADR 0013

`docs/adr/0013-autopilot-mode.md` exists and carries `## Title`, `## Status` (body
`Accepted`), `## Context`, `## Decision`, `### Alternatives Considered` (table),
`## Consequences`, `## Compliance` (naming `check-stop-and-ask-matrix.sh` and
`check-audit-trail.sh`), and `## Notes`. `docs/adr/README.md` has the row
`| 0013 | [Autopilot mode: choose-default-record-continue for unattended pipeline queue runs](0013-autopilot-mode.md) | Accepted |`.
It does not reuse 0011/0012: no `0011-*` or `0012-*` file exists, and the Notes record
that 0011 (PR #99) and 0012 (PR #101) are reserved, with 0013 the next free number.
AC-035-37/38 pass.

---

## Warnings and notes (non-blocking)

- **WARN — pre-existing full-tree design-principles FAIL:** `skills/hallmark/site/examples/cobalt-01/script.js` (CC=10) fails the unscoped gate and reproduces identically on `main`. It is untouched by this branch and out of scope; flagged to the Architect as a follow-up. The change-scoped gate is clean.
- **WARN — pre-existing doc-size hint:** `make validate-all` reports `skills/hallmark/SKILL.md` body 562 lines (>500 recommended). Unrelated to this spec; unchanged.
- **NOTE — executable bit:** `scripts/record-gate-run.sh` is not executable in this checkout, so `./scripts/record-gate-run.sh` exits 126; telemetry was appended with the documented bash form `bash scripts/record-gate-run.sh` (exit 0). Same pre-existing shape recorded by earlier specs, not introduced here.
- **NOTE — `make validate-all`** (extra, not one of the five contract checks) exit 0: required files present, all cross-references valid, all SKILL.md files valid (1 pre-existing warning). `scripts/check-orchestration.sh` exit 0: all agent, skill, script, and doc references resolve.

## Telemetry

Appended one record to `runs.jsonl` via `bash scripts/record-gate-run.sh` after the checks
completed (exit 0, `runId` generated by the script, `loopCount`/`phase1Retries`/
`phase2Retries` from the orchestrator's exported `SPEC_LOOP_COUNT=1`,
`SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`):

```
{"specSlug":"035-autopilot-mode","gatesFailed":[],"warnings":["pre-existing full-tree design-principles FAIL in untouched skills/hallmark/site/examples/cobalt-01/script.js reproduces unchanged on main; change-scoped gate clean","validate-all: skills/hallmark/SKILL.md body 562 lines exceeds 500-line recommendation"],"durationSec":649,"outcome":"pass","runId":"d64bcb6e-8046-4664-ab73-7fc7f198e56d","loopCount":1,"phase1Retries":0,"phase2Retries":0}
```

## Verdict

**PASS.** All five contract gates ran and produced no findings against the change:
traceability exit 0, `make test-scripts` exit 0 twice (529 ok / 0 not ok both times),
complexity exit 0, design-principles change-scoped exit 0. The spot check found the
tested assertions match their scenarios. The one unscoped design-principles FAIL is
pre-existing on `main` in an untouched vendored example and is recorded above rather
than hidden. The Architect may proceed.

## Quality gates

# Report — spec 035 autopilot mode

- **Stage:** 5a (Mutation Runner / Architect)
- **Branch:** `spec/035-autopilot-mode`
- **Base ref:** `main`
- **Verifier verdict carried forward:** **PASS** — `25-verification.md`, attempt 1, phase 1
  (`Overall verdict: PASS`, line 7; "The Architect may proceed", lines 479).
- **Work done at this stage:** mutation-tier ruling, mutation-skip evidence, final
  full-suite re-run, `45-decisions.md` written from the deterministic writer.
  No production code changed at this stage, nothing committed, nothing pushed.

Autopilot: true
Autopilot decisions: 0

## Verifier verdict (carried forward, not re-derived)

The Verifier's independent re-check is the precondition for this stage, so its verdict is
carried verbatim rather than re-asserted: `25-verification.md` line 7 reads
`- **Overall verdict: PASS**`, and every one of the five contract checks carries an
evidence block with `command:` / `exit:` / `at:` markers. This stage did not treat that
verdict as its own — it re-ran the full suite itself (below) because the mutation stage
adds new artifacts after the Verifier's run.

## Conformance tier ruling — `mvp`

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier
gate. This repo declares no `production` tier, so the ruling is `mvp` and mutation
testing is a recorded skip, not a gap (`docs/CONFORMANCE_TIERS.md`, "Tiers are
cumulative", and the `production` row for "Mutation testing (PiTest / Gremlins /
Stryker)").

Evidence for the ruling:

```
$ grep -rn "Conformance tier: production" AGENTS.md AGENTS_*.md
(no output)
exit: 2

$ make mutation
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
exit: 0
```

The design-principles gate reports the same tier independently (`"tier": "mvp"` in both
JSON runs recorded in `25-verification.md`, lines 145 and 168).

Secondary confirmation that no mutation engine could run even at a higher tier: this
change set is bash-only. Changed-path extensions are `14 .bats`, `8 .md`, `7 .sh`,
`1 .jsonl` (`runs.jsonl` telemetry), plus the untracked `specs/` folder. There is no
`pom.xml`, `package.json`, or `stryker.conf.*` in the tree, so the repo has no PiTest,
gremlins/go-mutesting, or Stryker target to point at the change. Per the stage
instruction, this tooling gap is reported, not used to block.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-10-26T08:31:35Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

**Mutation score: skipped — `mvp` tier** (tier evidence above; no Java/Go/JS mutation
engine present for a bash-only change set).

### Equivalent mutants

**None.** No mutation engine ran, so no mutant was generated, survived, or was judged
equivalent. There is therefore no un-killable-mutant list to name — an empty list here
means "mutation testing did not apply", not "every mutant was killed".

## Complexity summary (carried from the Refactorer via the Verifier)

The Refactorer writes no report artifact by design (`docs/SPEC_PIPELINE.md §Audit
contract`); the Verifier re-ran the structure gates and recorded the measurements. Carried
into this report unchanged:

| Measurement | Command | Exit | Result |
|---|---|---|---|
| Complexity (change-scoped) | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` | 0 | `"tier": "mvp"`, `"gates": ["complexity"]`, `"fails": []`, `"warns": []` |
| Design principles (change-scoped: complexity, dry, yagni, solid, component-per-file, property-tests) | `scripts/check-code-principles.sh -BaseRef main --json` | 0 | `"fails": []`, `"warns": []` |
| Property tests | tier-gated | — | skipped at `mvp` (`docs/CONFORMANCE_TIERS.md`: property testing is `production`) |

Zero complexity FAILs and zero complexity WARNs against the change: the four new
`scripts/autopilot-*.sh` files and the three extended gate scripts are all within the
≤6 cyclomatic bound. Copying `25-verification.md`'s caveat rather than smoothing it: the
**unscoped** design-principles run exits 1 on pre-existing debt
(`skills/hallmark/site/examples/cobalt-01/script.js`, CC=10) that reproduces identically
on a clean `main` worktree and is untouched by this branch — a WARN-level follow-up, not a
finding against this spec.

## Gate results

| Gate | Result | Evidence (from `25-verification.md`, re-run by the Verifier) |
|---|---|---|
| Scenario traceability | PASS | `scripts/check-scenario-traceability.sh --json` exit 0 at 2026-10-26T08:27:43Z; checks `[1, 2]`, 38 IDs traced (AC-035-01 … AC-035-38), `"fails": []` |
| Full test suite | PASS | `make test-scripts` exit 0 at 2026-10-26T08:18:33Z (529 ok / 0 not ok) and again at 2026-10-26T08:22:04Z (529 ok / 0 not ok) |
| Complexity gate | PASS | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` exit 0 at 2026-10-26T08:27:45Z |
| Design-principles gate | PASS (change-scoped) | `scripts/check-code-principles.sh -BaseRef main --json` exit 0 at 2026-10-26T08:27:46Z; unscoped pre-existing FAIL on `main` recorded, not introduced here |
| Scenario-to-behavior spot check | PASS | manual cross-check of AC-035-04, AC-035-21, AC-035-33 at 2026-10-26T08:26:00Z (assertions match Given/When/Then, not just IDs) |
| Mutation testing | SKIPPED (tier) | `make mutation` exit 0 at 2026-10-26T08:31:35Z — see §Evidence: mutation score |
| Final full suite (this stage) | PASS | `make test-scripts` exit 0 at 2026-10-26T08:35:46Z — see §Evidence: final test status |

Additional gates the Verifier ran beyond the five contract checks, also green:
`make validate-all` exit 0 and `scripts/check-orchestration.sh` exit 0 (all agent, skill,
script, and doc references resolve).

## Evidence: final test status

command: make test-scripts
exit: 0
at: 2026-10-26T08:35:46Z

Full-suite re-run performed at this stage, after the mutation ruling and after
`45-decisions.md` was written — the Verifier's green predates both. Raw output excerpt
(head, TAP plan) and tail:

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 65 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..529
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
...
ok 522 wire: score-shaped response exits 0 with answer the numeric score
ok 523 wire: usage carried only at the response top level populates per-question usage (input/output shape)
ok 524 wire: top-level usage of the total_tokens shape populates per-question usage too
ok 525 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 526 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 527 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 528 wire: non-numeric confidence is invalid, exits 10
ok 529 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts: `529` `ok`, `0` `not ok`, plan `1..529`; `0` skipped (`# skip`); make exit 0.
All 38 spec-035 acceptance tests appear in the run (`grep -c '^ok .*AC-035'` → 38),
matching the 38 scenario IDs the traceability check requires: every scenario is still
traced to a passing test at final status.

Two artifacts this stage added could in principle affect the suite: `45-decisions.md`
existed before the run, `30-report.md` did not. Cheap confirmation that neither disturbs
the green, and that the autopilot rule still bites, after both existed:

command: bats --tap scripts/tests/check-audit-trail.bats scripts/tests/autopilot-enforcement.bats scripts/tests/autopilot-decisions.bats
exit: 0
at: 2026-10-26T08:37:21Z

```
ok 1 check-audit-trail: no slug exits 2 and prints the usage block
ok 2 check-audit-trail: an absent spec folder is 'nothing to check' and exits 0
ok 3 check-audit-trail: a spec folder missing 25-verification.md exits 1
ok 4 check-audit-trail: --selftest exercises every negative case and exits 0
ok 5 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 6 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 7 AC-035-35 — without the marker, 45-decisions.md is optional either way
ok 8 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
ok 9 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 10 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 11 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 12 unit — add rejects a missing field and a malformed timestamp, leaving the file untouched
```

## Autopilot record

This run executed under autopilot. No ask reached a genuine fork that autopilot had to
resolve, so `scripts/autopilot-decisions.sh none specs/035-autopilot-mode/45-decisions.md`
wrote the single documented line (`exit 0`; `count` → `0`):

```
No autopilot decisions were required
```

`Autopilot decisions: 0` above therefore matches the entry count in
`45-decisions.md` (`scripts/autopilot-decisions.sh count` → `0`), which is the
consistency rule from Task 6 / AC-035-20. The marker is non-empty, satisfying the
`check-audit-trail.sh` autopilot rule (AC-035-33/34).

Two conditions evaluated at this stage are recorded here as **dispositions, not
decisions**, because each had exactly one permitted outcome and no alternative was weighed:

- **Working tree dirty** — the tree carries this spec's own uncommitted change set (every
  path accounted for in `25-verification.md §No unaccounted behavior`; commits are stage
  5b's job). The clean-tree rule is a start-of-item preflight
  (`scripts/autopilot-preflight.sh` step 4, run by `/autopilot` "before each queue
  item"), not a per-stage gate — mid-pipeline implementation dirt is the expected state
  between stage 2 and stage 5b.
- **Project type / tier** — resolved to `mvp` by the tier declaration rule, not by a
  judgement call (see §Conformance tier ruling). No ambiguity arose.

## Remediation record

**none.** No BLOCK occurred in this run. `25-verification.md` records a single attempt
("**Attempt:** 1, phase 1 (full verification, first run)") with verdict PASS and no
re-verification entries, so there is no phase-1 or phase-2 attempt count to carry forward.
The orchestrator's loop summary reports no block either. Nothing in this section is
guessed or invented: where the source is silent, this report says so rather than
supplying a phase and attempt number.

## Evidence: audit-trail gate

command: scripts/check-audit-trail.sh 035-autopilot-mode
exit: 0
at: 2026-10-26T08:36:42Z

Verbatim (ANSI colour codes from the script's own output stripped, no wording changed):

```
PASS 035-autopilot-mode: 10-tasks.md present and non-empty
PASS 035-autopilot-mode: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 035-autopilot-mode: 25-verification.md present and non-empty
PASS 035-autopilot-mode: 30-report.md present and non-empty
PASS 035-autopilot-mode: 45-decisions.md present and non-empty for an autopilot run (AC-035-34)
PASS 035-autopilot-mode: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T08:27:43Z
PASS 035-autopilot-mode: evidence block 'full test suite' — command: make test-scripts, exit: 0, at: 2026-10-26T08:18:33Z
PASS 035-autopilot-mode: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json, exit: 0, at: 2026-10-26T08:27:45Z
PASS 035-autopilot-mode: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh -BaseRef main --json, exit: 0, at: 2026-10-26T08:27:46Z
PASS 035-autopilot-mode: evidence block 'scenario-to-behavior spot check' — command: manual cross-check of acceptance scenarios AC-035-04, AC-035-21, AC-035-33 against the assertions in scripts/tests/*.bats, exit: 0, at: 2026-10-26T08:26:00Z
✔ Audit-trail check: specs/035-autopilot-mode complete, verifier evidence recorded.
```

The `45-decisions.md` line is the autopilot rule in action: `Autopilot: true` in this
report is accepted only because `45-decisions.md` exists and is non-empty (AC-035-34).

## Warnings and notes carried forward (non-blocking)

- **WARN — pre-existing full-tree design-principles FAIL:**
  `skills/hallmark/site/examples/cobalt-01/script.js` (CC=10). Reproduces identically on a
  clean `main` worktree; untouched by this branch. Follow-up candidate (a separate spec),
  never fixed inside this run.
- **WARN — pre-existing doc-size hint:** `make validate-all` reports
  `skills/hallmark/SKILL.md` body 562 lines (>500 recommended). Unrelated, unchanged.
- **NOTE — executable bit:** `scripts/record-gate-run.sh` is not executable in this
  checkout, so `./scripts/record-gate-run.sh` exits 126; the documented
  `bash scripts/record-gate-run.sh` form works (exit 0). Same pre-existing shape recorded
  by earlier specs, not introduced here.
- **NOTE for stage 5d (Archiver):** `30-report.md` now exists, so this folder is
  *finished* — `scripts/check-specs-archived.sh` (self-ci `validate`, no
  `continue-on-error`) will fail the merge until `scripts/archive-spec.sh 035-autopilot-mode`
  runs as the pipeline's final act. Expected flow, flagged so it is not mistaken for a
  regression at PR time.

## Verdict

**GREEN.** Verifier PASS carried forward; mutation testing recorded as a tier skip with
executable evidence (`make mutation` exit 0, `mvp` tier); no equivalent mutants (no engine
ran); final full suite re-run green at 529 ok / 0 not ok / 0 skipped after this stage's
artifacts landed. Complexity summary carried from the Verifier's re-run of the Refactorer's
gates with zero findings. Stage 5b (PR Opener) may proceed.

PR: https://github.com/RexiAI/my-engineering-standards/pull/102
Commits on branch (vs main): 15 (13 task commits + spec artifacts + this PR-record commit)

## 40-deploy.md

# 40 — Deploy verification (stage 5c)

Branch: spec/035-autopilot-mode
PR: https://github.com/RexiAI/my-engineering-standards/pull/102
Repo classification: non-frontend (standards/tooling repo)

## Classification evidence

command: test -f vercel.json; test -f package.json (repo root)
exit: 1 (both absent)
at: 2026-10-26T08:40:48Z

command: ls -a | grep -i vercel; ls .vercel
exit: 1 (no `.vercel` project link directory, no Vercel config)
at: 2026-10-26T08:40:48Z

command: grep -l '"(next|@angular/core|react|@ionic/angular)"' --include=package.json (excluding node_modules, .opencode, .standards)
exit: 1 (no frontend framework dependency declared in any repo package.json)
at: 2026-10-26T08:40:48Z

No frontend signal (vercel.json, frontend framework dependency, or connected Vercel Git integration) is present. Repo is not frontend.

## Deploy surface

- Deploy URL: none
- Build status: skip
- Health check status: skip
- E2E verdict: skip (no live preview URL; e2e-runner not invoked)
- `vercel deploy` / `vercel deploy --prod`: not run (prohibited for this agent)
- Phase-3 attempt count: 0 (no attempt consumed; skip is not a failure)
- Timestamp: 2026-10-26T08:40:48Z

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

## 45-decisions.md

No autopilot decisions were required
