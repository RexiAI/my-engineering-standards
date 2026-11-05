# 038 — Trim agent prompts: move procedure into scripts

Baseline (measured `wc -l agents/spec-*.md` at spec time): spec-verifier 243,
spec-ux 218, spec-pr-opener 171, spec-pipeline 140, spec-deployer 139 exceed 120;
spec-coder 111, spec-refactorer 101, spec-mutation-runner 97, spec-specifier 55 are within.

Precondition: spec 037 (split `docs/SPEC_PIPELINE.md` per stage) is merged. At spec
time 037 has only `00-informal.md`; `/build` for 038 must not start until 037 lands.

## Task 1 — Agent line-cap check script
Add `scripts/check-agent-line-cap.sh` enforcing a 120-line cap on `agents/spec-*.md`.
- Scans every file matching `agents/spec-*.md` (glob, not a hard-coded list).
- A file with line count (`wc -l`) ≤ 120 passes; > 120 fails.
- On failure prints each offending path and its line count, exits 1.
- On all-pass exits 0.
- Cap value is a single named constant in the script (value 120).
- Self-test or fixture-based test exists exercising pass (=120) and fail (=121).

## Task 2 — Wire the line-cap check into CI
- `.github/workflows/self-ci.yml` has a step running `./scripts/check-agent-line-cap.sh`.
- `AGENTS.md §General Rules` mentions the script alongside check-skills/check-orchestration.

## Task 3 — Extract procedures from over-cap agents
For each of spec-verifier, spec-ux, spec-pr-opener, spec-pipeline, spec-deployer:
- Procedural sequences (ordered command lists, gate-run sequences, file-format
  templates) move to a script under `scripts/` or a reference file under
  `skills/<name>/` or the per-stage doc created by 037.
- The agent file keeps: decisions, stop conditions, outputs, and a path reference
  to each extracted artifact.
- Resulting file ≤ 120 lines.

## Task 4 — No gate removed or weakened
- Every gate script invoked (directly or by name) by an agent before the change is
  still invoked after the change, either by the agent or by an extracted script
  the agent references.
- No threshold value (complexity ≤6, mutation threshold, line caps in check-skills)
  changes in any file.

## Task 5 — Orchestration and skill checks stay green
- `scripts/check-orchestration.sh` exits 0 (every new `scripts/...`/skill path cited in agents resolves).
- `scripts/check-skills.sh` exits 0 (any new skill reference file is compliant).
- `scripts/check-agent-line-cap.sh` exits 0.

## Open questions
1. Scope: `agents/spec-pipeline.md` matches `spec-*` (140 lines) but is the
   orchestrator, not a stage agent. Assumed IN scope per the literal glob in the
   informal spec. Confirm.
2. Does a new script need a `.ps1` twin per repo convention? Assumed no unless the
   repo standard requires it — confirm.
3. Where do file-format templates go when 037's per-stage docs exist — stage doc
   or `skills/`? Assumed: Coder chooses, as long as check-orchestration resolves the reference.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- `spec-pipeline.md` is in scope for the 120-line cap.
- No `.ps1` twin.
- Coder chooses placement of extracted templates (must resolve under check-orchestration.sh).
