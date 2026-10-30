# 036 — Single source of truth for orchestrator rules: tasks

Source: `00-informal.md`. Normative source after this spec: `docs/SPEC_PIPELINE.md`.
`agents/spec-pipeline.md` becomes a runtime procedure that references the doc.
No pipeline behavior change.

Definitions used below:

- **Section reference** — a string of the form `docs/SPEC_PIPELINE.md §<Heading text>`
  where `<Heading text>` equals the text of a `##` or `###` heading in
  `docs/SPEC_PIPELINE.md` (exact match, case-sensitive, after stripping the `#`s
  and surrounding whitespace).
- **Normalized line** — a line with leading/trailing whitespace removed, a leading
  list/quote marker (`- `, `* `, `> `, `N. `) removed, and internal runs of
  whitespace collapsed to one space.
- **Verbatim duplicate** — a normalized line of at least 8 words (whitespace-split
  tokens) that appears identically in both an `agents/*.md` file and
  `docs/SPEC_PIPELINE.md`. Lines inside fenced code blocks and heading lines are
  excluded. (Threshold: see Open question Q1.)

## Task 1 — Trim `agents/spec-pipeline.md` to runtime procedure

Acceptance criteria:

- Frontmatter (`description`, `mode`, `permission` block) is byte-identical to before.
- Retains, as runtime instructions: the `scripts/judgment-preflight.sh` first action;
  the `/spec` sequence (`spec-specifier` then `spec-ux`, stop for human review,
  relay `BLOCKED`, note `SKIPPED`); the `/build` order `spec-coder` →
  `spec-refactorer` → `spec-verifier` → `spec-mutation-runner` → `spec-pr-opener`;
  the stop conditions (Verifier non-PASS → no stage-5 agents; Mutation Runner not
  green → no PR Opener; any stage cannot proceed → stop and relay; remediation
  budget exhausted → stop and escalate; autopilot hard stop → write morning report
  and stop queue); the `SPEC_LOOP_COUNT`/`SPEC_PHASE1_RETRIES`/`SPEC_PHASE2_RETRIES`
  export instruction.
- Does NOT restate: the nine never-list bullets (no merge, no git tag, …), the
  commit/push carve-out conditions, the autopilot trigger definition
  (`autopilot` token / `SPEC_AUTOPILOT=1`), or the remediation-budget rules beyond
  naming the cap. Each is replaced by a section reference to
  `§Autopilot mode` / `§Never-list`, `§Commit and push carve-out`,
  `§Remediation budget`, `§Post-PR CI check-and-remediate loop (phase 2)`.
- Contains at least one section reference for each of: `Remediation budget`,
  `Never-list`, `Commit and push carve-out`, `Autopilot mode`,
  `Stop-and-Ask decision matrix`.
- File is shorter than 140 lines.

## Task 2 — No normative content lost

Acceptance criteria:

- Every rule removed from `agents/spec-pipeline.md` in Task 1 is present in
  `docs/SPEC_PIPELINE.md`: max 3 phase-1 cycles, independent max-3 phase-2 budget,
  all nine never-list items, the carve-out branch/`30-report.md` precondition, the
  autopilot trigger.
- Any such rule missing from the doc is added to the doc in the relevant section
  (not left only in git history).
- No other `docs/SPEC_PIPELINE.md` rule is changed in meaning (diff limited to
  additions needed by this task and, if any, deduplication-neutral edits).

## Task 3 — Duplication check script

Acceptance criteria:

- New script `scripts/check-agent-doc-duplication.sh` (POSIX bash, `set -euo pipefail`).
- Compares every `agents/*.md` against `docs/SPEC_PIPELINE.md` using the
  "verbatim duplicate" definition above.
- Exit 0 and prints a single OK line when no verbatim duplicate exists.
- Exit 1 when ≥1 duplicate exists; prints one line per duplicate in the form
  `<agent-file>:<line-number>: duplicated from docs/SPEC_PIPELINE.md:<line-number>`.
- Also validates section references: each `docs/SPEC_PIPELINE.md §<Heading>` in
  `agents/*.md` must match a heading (definition above); each unresolved one is
  printed as `<agent-file>:<line-number>: unresolved section reference §<Heading>`
  and causes exit 1.
- Exit 2 on usage error / missing `docs/SPEC_PIPELINE.md` or `agents/` directory.
- Accepts an optional repo-root argument (default: current directory) so tests can
  run it against fixtures.
- A selftest `scripts/check-agent-doc-duplication.selftest.sh` exercises the
  scenarios in AC-036-03 against temp fixtures.

## Task 4 — Wire the check and pass on the repo

Acceptance criteria:

- `scripts/check-orchestration.sh` invokes `scripts/check-agent-doc-duplication.sh`
  and fails (exit 1) when it fails. (See Q2.)
- Running `scripts/check-agent-doc-duplication.sh` on the repo after Tasks 1–2
  exits 0 (all agents, not just `spec-pipeline.md`).
- Existing `scripts/check-orchestration.sh` checks still exit 0 on the repo.

## Open questions

- **Q1 (threshold):** "Duplicated verbatim" has no size in the informal spec. This
  spec assumes a normalized line of ≥8 words. Confirm or give another threshold
  (shorter lines like "Never commit or push" would otherwise false-positive).
- **Q2 (placement):** Informal allows a new check or extending
  `check-orchestration.sh`. This spec chooses a standalone script called from
  `check-orchestration.sh`. Confirm.
- **Q3 (conflict with 037):** `specs/037-split-spec-pipeline-doc` may split
  `docs/SPEC_PIPELINE.md`. If 037 lands first, the "normative source" and section
  references must cover the split files. Confirm 036 runs before 037, or widen the
  doc set.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Duplicate threshold: >=8 words after whitespace/list-marker normalization.
- Standalone `scripts/check-agent-doc-duplication.sh`, invoked by `check-orchestration.sh`.
- 036 lands before 037.
- ADR `docs/adr/0017-pipeline-agent-single-source.md` is in scope (required by `check-pr-review.sh` AC-024-01-12; 0016 is claimed by open PR #106).
