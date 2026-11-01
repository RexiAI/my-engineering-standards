# 10-tasks — 037-split-spec-pipeline-doc

## The ask (verbatim summary)

Split the 892-line `docs/SPEC_PIPELINE.md` into a short index (overview, stage
table, cross-cutting rules: commit/push carve-out, remediation budget, autopilot
never-list, Stop-and-Ask matrix) plus one file per stage under
`docs/spec-pipeline/<stage>.md`. Every agent reads only the index section it
needs plus its own stage file. Update every reference in `agents/`, `commands/`,
`AGENTS.md`, `docs/`, `scripts/`; `scripts/check-orchestration.sh` resolves all
of them. Per-stage read cost drops ≥50% versus today. Depends on 036 landing first.

## Grounded context (do not re-derive)

- `docs/SPEC_PIPELINE.md` is 892 lines today (`wc -l`), with top-level sections:
  Stages, Why a separate Verifier stage, Artifact layout, Audit contract,
  Evidence: scenario traceability, Archive in the PR, Definition of done,
  Scenario format, The information barrier, Compensating control, Stop-and-Ask
  decision matrix, Autopilot mode, Commit and push carve-out, Remediation budget,
  Post-PR CI check-and-remediate loop, Deploy verification loop, Production
  deploy verification, Conformance tiers, Model configuration, PR review model
  wiring, Typed-judgment layer, Tooling by language, Why no BDD runner, Why no
  scenario mutation.
- 102 files under `agents/ commands/ AGENTS.md docs/ scripts/ skills/` mention
  `SPEC_PIPELINE`; many use the form `docs/SPEC_PIPELINE.md §<Section>`.
- `scripts/check-orchestration.sh` check 4 only matches `docs/[A-Z_]+.md` in
  `agents/*.md`. A lowercase path such as `docs/spec-pipeline/coder.md` is
  **not** matched today, and `§Section` anchors are never verified.
- Spec 036 (`specs/036-pipeline-agent-single-source/`) currently has only
  `00-informal.md`; it has **not** landed.

## Precondition

- **P1 — 036 landed.** `/build` for 037 must not start until 036 is merged to
  `main` (informal spec: "Depends on 036 landing first"). The Coder STOPs and
  reports (no workaround)
  if `specs/036-pipeline-agent-single-source/` still exists on the base branch
  without a `docs/changes/036-*.md` archive.

## Tasks

### Task 1 — Index doc `docs/SPEC_PIPELINE.md` (AC-037-01)

- `docs/SPEC_PIPELINE.md` keeps its path (so existing bare links still resolve).
- It contains exactly these sections: overview, Stages table, Artifact layout,
  Stop-and-Ask decision matrix, Commit and push carve-out, Remediation budget,
  Autopilot never-list (incl. hard stops), and a "Stage files" table mapping
  each stage to its `docs/spec-pipeline/<stage>.md`.
- The cross-cutting sections' text is moved verbatim (no semantic change);
  the Stop-and-Ask table rows are byte-identical to today's rows.
- Index is ≤ 250 lines (`wc -l`).

### Task 2 — Per-stage files under `docs/spec-pipeline/` (AC-037-02)

- One file per stage agent: `specifier.md`, `ux.md`, `coder.md`,
  `refactorer.md`, `verifier.md`, `mutation-runner.md`, `pr-opener.md`
  (covers 5b + 5d archive), `deployer.md`.
- Shared reference material not owned by one stage lives in named shared files
  in the same directory: `audit-contract.md` (Audit contract + Evidence:
  scenario traceability + Definition of done), `model-config.md` (Model
  configuration + PR review model wiring), `rationale.md` (Why a separate
  Verifier stage, Information barrier, Compensating control, Why no BDD
  runner, Why no scenario mutation), `typed-judgment.md`, `post-pr-loops.md`
  (Post-PR CI loop, Production deploy verification).
- Every one of today's top-level sections appears in exactly one destination
  file (index or a `docs/spec-pipeline/*.md`); none is dropped or duplicated.
  "Scenario format" goes to `specifier.md`; "Conformance tiers" and "Tooling
  by language" go to `coder.md`; "Archive in the PR" to `pr-opener.md`;
  "Deploy verification loop" to `deployer.md`.
- Each stage file starts with a one-line pointer back to `docs/SPEC_PIPELINE.md`
  and lists which index sections the stage must also read.

### Task 3 — Rewrite references (AC-037-03)

- Every `docs/SPEC_PIPELINE.md §<Section>` reference in `agents/`, `commands/`,
  `AGENTS.md`, `docs/`, `scripts/`, `skills/` whose section moved is rewritten
  to `docs/spec-pipeline/<file>.md §<Section>`.
- References to sections that stayed in the index keep `docs/SPEC_PIPELINE.md`.
- Each `agents/spec-*.md` instructs reading only its stage file plus named
  index sections, not "read docs/SPEC_PIPELINE.md first" in full.

### Task 4 — Extend `check-orchestration.sh` (AC-037-04)

- Check 4 additionally matches `docs/spec-pipeline/[a-z-]+.md` references in
  `agents/`, `commands/`, `AGENTS.md`.
- New check: every `<doc path> §<Section>` reference whose path is
  `docs/SPEC_PIPELINE.md` or `docs/spec-pipeline/*.md` resolves to a heading
  (`^#+ <Section>`) in that file; a miss prints the source file:line and exits 1.
- Script exits 0 on the tree after Tasks 1-3.

### Task 5 — Read-cost measurement (AC-037-05)

- A script `scripts/measure-stage-read-cost.sh` prints, per stage agent, the
  byte count of (its stage file + the index) versus the byte count of today's
  full `docs/SPEC_PIPELINE.md` (baseline recorded as a constant: the byte size
  at the 036-merged base commit).
- Exits 0 only if every stage's ratio is ≤ 0.50; exits 1 naming any stage over.
- See open question Q1 on the metric.

## Open questions (need human answer before /build)

- **Q1 — token metric.** "Tokens drop ≥50%" has no defined tokenizer. Proposed
  default: bytes as a proxy (`wc -c`), cost = index + own stage file, shared
  files (`audit-contract.md` etc.) counted only if the agent's file says
  "must read". Accept, or name a tokenizer?
- **Q2 — stage file names.** Proposed names in Task 2 are by agent, not stage
  number. Accept, or prefer `NN-<stage>.md`?
- **Q3 — 036 overlap.** 036 is not yet specified beyond its informal note;
  if 036 rewrites agent prompts, Task 3's agent edits must be rebased on it.
  Confirm 037 waits for 036 merge (P1) rather than running in parallel.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Q1: read cost measured in bytes (`wc -c`).
- Q2: stage files named by agent (`coder.md`, `verifier.md`, ...).
- Q3: 037 waits for 036 to merge.
