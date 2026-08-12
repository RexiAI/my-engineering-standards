# Spec 015 — Auditable agent steps

Formalized from `specs/015-auditable-agent-steps/00-informal.md`. The pipeline already
writes a per-stage artifact set (`10-tasks.md`, `20-acceptance/`, `25-verification.md`,
`30-report.md`) but has no uniform rule for *what evidence each stage must leave behind*.
This spec adds a documented audit contract, makes the existing stage artifacts carry that
evidence, ships `scripts/check-audit-trail.sh` as the mechanical gate, and wires the gate
into the pipeline end.

This repo has no JVM/Go/Node test suite. Per the established precedent (spec-001's
`scripts/verify-spec-001.sh`), the shipped shell check script is the test carrier: it must
reference every scenario ID so `scripts/check-scenario-traceability.sh` resolves them.

## Task 1 — Document the audit contract in docs/SPEC_PIPELINE.md

Maps informal AC-001 (contract documented) and part of AC-003 (machine-readable rule).

**Acceptance criteria**

- Add a top-level `## Audit contract` section to `docs/SPEC_PIPELINE.md`.
- The section maps each pipeline stage to the artifact(s) that carry its evidence:
  - Specifier → `10-tasks.md` + `20-acceptance/` — task acceptance criteria and scenario IDs (`AC-NNN-NN`).
  - Coder → the tests in the project suite carrying `AC-NNN-NN` IDs; the build/test commands
    and exit codes it ran, re-recorded by the Verifier in `25-verification.md` (the Coder
    leaves no report artifact; the section says so explicitly).
  - Refactorer → the gates it applied (complexity, duplication, property tests) with
    before/after measurements, re-recorded by the Verifier; the complexity summary carried
    into `30-report.md`.
  - Verifier → `25-verification.md` — per check: exact command, real output, exit code, timestamp.
  - Mutation Runner → `30-report.md` — mutation score (or skip reason), equivalent mutants, final test status.
  - PR Opener → `30-report.md` — PR URL and commit count, appended after the PR opens.
- The section names the five runnable Verifier checks the report must carry evidence for:
  scenario traceability, full test suite, complexity gate, design-principles gate, and
  scenario-to-behavior spot check. The "no unaccounted behavior" skim is recorded as a
  finding line, not a command.
- The section states the machine-readable rule: machine-readable evidence (gate script
  output, CI query, deploy check) is recorded with an ISO-8601 UTC timestamp
  (`YYYY-MM-DDTHH:MM:SSZ`) as raw output or exit code — never as a prose paraphrase.
- The section defines the uniform evidence block used in `25-verification.md`, with a
  worked example containing `command:`, `exit:`, `at:`, and raw output.
- The section states the Coder and Refactorer leave no report artifact; their claims become
  auditable because the Verifier re-executes them and records command + exit code in
  `25-verification.md`.

**Scenarios:** AC-015-01 — AC-015-03

## Task 2 — Make each stage artifact carry the contract's evidence

Maps informal AC-002 (artifacts include required evidence) and the agent-facing half of AC-003.

**Acceptance criteria**

- `agents/spec-verifier.md`: the Report section requires, for every check, an evidence block
  with the exact `command:`, the real output (or representative excerpt), the `exit:` code,
  and an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ`; the design-principles gate's exit code
  and every FAIL/WARN line stay verbatim.
- `agents/spec-coder.md`: the Output section requires listing the exact build/test commands
  run and their exit codes in the handoff.
- `agents/spec-refactorer.md`: the Output section requires listing the gates applied with
  before/after measurements in the handoff.
- `agents/spec-mutation-runner.md`: the Report section requires the mutation score or an
  explicit `skipped — <tier> tier` reason and the final test status.
- `agents/spec-pr-opener.md`: after opening the PR, append to `30-report.md` a `PR:` line
  with the PR URL and a line with the commit count.
- No new spec-folder artifacts are introduced — the evidence lands in the artifacts the
  layout already defines.

**Scenarios:** AC-015-04 — AC-015-06

## Task 3 — Add the `scripts/check-audit-trail.sh` gate script

Maps informal AC-004 (artifact existence + exit 0 only when complete) and AC-005 (verifier
report cites real evidence).

**Acceptance criteria**

- Usage `scripts/check-audit-trail.sh <slug>`; missing argument prints usage and exits 2.
- Follows the house style of the other `scripts/check-*.sh` scripts: `#!/bin/bash`,
  `set -euo pipefail`, header comment (checks, usage, exit codes, standards reference),
  `PASS`/`FAIL` lines, violation counter, summary and non-zero exit on violations.
- When `specs/<slug>` does not exist, prints "nothing to check" and exits 0 — mirrors
  `check-scenario-traceability.sh`'s empty-directory behavior so the gate is a no-op on
  main after a spec is archived.
- Verifies each expected artifact exists and is non-empty: `10-tasks.md`, `20-acceptance/`
  (at least one non-empty `AC-*.md` containing at least one `## AC-NNN-NN` heading),
  `25-verification.md`, `30-report.md`, and `15-design.md` when present (zero-byte
  `15-design.md` is a failure).
- Verifies `25-verification.md` records real evidence for every one of the five contract
  checks: a `command:`, an `exit:`, an `at:` timestamp in `YYYY-MM-DDTHH:MM:SSZ`, and
  non-empty raw output for each.
- Exits 0 only when the folder is complete AND the verifier evidence is complete; exits 1
  otherwise, listing every missing artifact or check.
- The negative cases (missing artifact, empty file, missing evidence) are genuinely
  exercised — e.g. against a temp spec-folder fixture — not dead code.
- Passes `bash -n scripts/check-audit-trail.sh` and shellcheck cleanly.
- References every scenario ID `AC-015-01`…`AC-015-16` (as function names or comments) so
  `check-scenario-traceability.sh` resolves them.

**Scenarios:** AC-015-07 — AC-015-14

## Task 4 — Wire the gate into the pipeline end

Maps the informal spec's "Run at pipeline end" (AC-004).

**Acceptance criteria**

- `agents/spec-pr-opener.md`: before committing, pushing, and opening the PR, run
  `scripts/check-audit-trail.sh <slug>`; if it exits non-zero, stop and report — do not open
  the PR.
- `.github/workflows/self-ci.yml`: add a step that runs `scripts/check-audit-trail.sh` for
  each present `specs/*/` directory; when no spec folder exists the step exits 0.

**Scenarios:** AC-015-15 — AC-015-16

## Open questions

1. **Timestamp pinned to UTC.** The contract requires `YYYY-MM-DDTHH:MM:SSZ` (i.e.
   `date -u +%Y-%m-%dT%H:%M:%SZ`) so the gate can verify it deterministically. Acceptable,
   or must the timestamp preserve local time?
2. **Evidence-block markers are a new inline convention.** `command:` / `exit:` / `at:` are
   a uniform format applied *inside* the existing `25-verification.md` / `30-report.md`
   artifacts — this is the informal spec's "make it uniform", not a new artifact. Confirm
   the marker names are acceptable before the Coder bakes them into the agent prompts.
