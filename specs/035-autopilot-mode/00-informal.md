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
