# Tasks: Stop-and-Ask decision matrix

Formalizes `00-informal.md` into an authoritative Stop-and-Ask decision matrix that
lives in `docs/SPEC_PIPELINE.md`, referenced by every pipeline agent. This repo's
orchestrator is `spec-pipeline` (there is no `spec-coordinator`); the stage agents
are `spec-specifier`, `spec-ux`, `spec-coder`, `spec-refactorer`, `spec-verifier`,
`spec-mutation-runner`, and `spec-pr-opener` (the "Architect" role in
`docs/SPEC_PIPELINE.md` is split into 5a `spec-mutation-runner` and 5b
`spec-pr-opener`).

## Informal-spec row adaptation

The informal spec's 8 rows were checked against this pipeline's real semantics
(`docs/SPEC_PIPELINE.md`, `agents/spec-pipeline.md`, each stage agent, and
`scripts/check-code-principles.sh`). Two changed, one was dropped, three real
stop conditions were added:

- **Dropped — Confluence space/parent unknown.** This pipeline has no Confluence
  step: it writes `specs/NNN-slug/`, commits to a `spec/NNN-slug` branch, and opens
  a PR. There is no doc space or parent page to resolve. Row removed; no analog.
- **Adapted — version bump not requested.** This repo has no version-bump step;
  Semantic Release owns versioning after merge. The row's underlying principle
  ("never infer a version you weren't asked to create") maps to the existing
  "never create git tags" rule (`AGENTS.md`, `agents/spec-pr-opener.md`). Kept as
  "Version bump / git tag not requested → off by default; never create tags."
- **Adapted — repo not found after discovery.** Kept as-is plus an added sibling
  row for the pipeline's actual discovery failure: `/build` invoked without
  `10-tasks.md` / `20-acceptance/` → tell the user to run `/spec` first, never
  scaffold the spec folder yourself.
- **Added — design gate WARN.** `spec-verifier.md` treats a `check-code-principles.sh`
  WARN as a review hint, not a stop. Codified so "never improvise" covers it.
- **Added — Verifier verdict FAIL.** `spec-pipeline.md` hard-stops before stage 5;
  codified in the matrix.
- **Added — PR Opener precondition fails** (branch not `spec/NNN-slug`, or
  `30-report.md` missing/not green). Codified.

Informal AC mapping: AC-001 → Tasks 1 + 2; AC-002 → Task 3; AC-003 → Task 2.

Note: this repo has no Java/Go/JS test suite — its "test framework" is the
`scripts/check-*.sh` + Makefile pattern. The acceptance scenarios for this spec
therefore become a new shell check script (Task 4), which is also what satisfies
`scripts/check-scenario-traceability.sh` (the script's output must cite every
`AC-009-NN` ID).

---

## Task 1 — Add the Stop-and-Ask decision matrix to `docs/SPEC_PIPELINE.md`

Add a section titled `## Stop-and-Ask decision matrix` to `docs/SPEC_PIPELINE.md`
(document placement left to the implementer; a natural home is after `§Compensating
control` and before `§Commit and push carve-out`).

The section must open with a sentence stating the matrix is authoritative and is
referenced by every pipeline agent: every agent resolves the listed conditions per
the matrix, never by improvisation.

The section must contain a two-column table (`| Condition | Deterministic action |`)
with exactly these rows:

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report; never stash or auto-commit |
| Repo not found after discovery (wrong directory, `.standards/` submodule missing) | Ask for the absolute path once; never scaffold (no `git init`, no submodule creation) unprompted |
| Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`) | Tell the user to run `/spec` first; never create the artifacts yourself |
| Project type ambiguous (language stack / conformance tier undetectable) | Defer to the harness default (`mvp` tier; language per `language-specific/<lang>/SKILL.md`); ask only if interactive and unconfirmed |
| Version bump / git tag not requested | Off by default; never infer from SemVer or the diff; never create git tags — CI (Semantic Release) owns versioning |
| A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold) | Fix the code, never the threshold — gate config is off-limits to agents |
| Design gate WARN (not FAIL) | Record in the report; do not stop; flag to the Architect |
| Out-of-scope finding | Record it (Verifier: `25-verification.md`); do not fix; propose a follow-up spec |
| Acceptance criteria ambiguous | Resolve before delegating implementation — stop and ask one specific question |
| Verifier verdict FAIL | STOP the pipeline; relay the report; do not run stage-5 agents; do not fix it yourself |
| PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green) | STOP; commit nothing, push nothing |

No row may reference Confluence.

Acceptance:
- `docs/SPEC_PIPELINE.md` contains `## Stop-and-Ask decision matrix`.
- The section declares the matrix authoritative for every pipeline agent.
- All 11 rows above are present verbatim (condition text and deterministic action).
- No Confluence reference exists within the matrix section.

## Task 2 — Every pipeline agent references the matrix as authoritative

Add a reference to `docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix` to each of
the 8 pipeline agents, in the frontmatter description and/or the body prompt:

- `agents/spec-pipeline.md`
- `agents/spec-specifier.md`
- `agents/spec-ux.md`
- `agents/spec-coder.md`
- `agents/spec-refactorer.md`
- `agents/spec-verifier.md`
- `agents/spec-mutation-runner.md`
- `agents/spec-pr-opener.md`

Each reference must state the matrix is authoritative: the agent resolves the
listed conditions per the matrix, never by improvisation. Wording per agent is left
to the implementer; the section title must be exact so a grep can verify it.

Acceptance:
- Each of the 8 agent files mentions `Stop-and-Ask decision matrix`.
- Each such mention also states the matrix is authoritative for that agent.
- No other repo doc or agent is required to change.

## Task 3 — Enforce "fix the code, never the threshold"

The matrix rule must hold mechanically. Enforcement has two parts:

1. **Gate config is off-limits.** No pipeline agent's `permission.edit` may permit
   modifying `scripts/check-code-principles.sh` or linter configs that set the
   complexity threshold (PMD/golangci/eslint configs, `.standards/` equivalents).
   Agents with an explicit `edit` deny for `*` already satisfy this (e.g.
   `spec-specifier`, `spec-verifier`); agents with no `edit:` block or a broad one
   must gain an explicit deny for these paths. The implementer may either add
   `edit` deny patterns to the affected agent frontmatter or extend an existing
   deny-all block — whichever keeps each agent's legitimate edit scope intact.
2. **Threshold stays a constant in code.** `check-code-principles.sh` must keep
   its hard-coded cyclomatic threshold (6) and not gain a threshold parameter an
   agent could tune. Do not change the script's threshold value.

Acceptance:
- No pipeline agent file's `permission.edit` allows editing `scripts/check-code-principles.sh`
  or a linter complexity config.
- `check-code-principles.sh` still hard-codes the ≤6 complexity rule; no new
  threshold-override flag was added.
- The matrix row "A design gate blocks" still reads "Fix the code, never the
  threshold — gate config is off-limits to agents".

## Task 4 — Add `scripts/check-stop-and-ask-matrix.sh`

Add a mechanical check script (matching the existing `scripts/check-*.sh` style:
`set -euo pipefail`, `FAIL`/`PASS` lines, exit 0 on compliance / 1 on violation).
It must verify:

1. `docs/SPEC_PIPELINE.md` contains `## Stop-and-Ask decision matrix` with all 11
   required conditions present.
2. Each of the 8 pipeline agent files references the matrix section title.
3. No pipeline agent's `permission.edit` allows editing `scripts/check-code-principles.sh`
   or a linter complexity config (grep the frontmatter).
4. The matrix section contains no Confluence reference.

The script must cite every scenario ID from `20-acceptance/` in its PASS/FAIL
output (e.g. `PASS AC-009-01-01 …`), so `scripts/check-scenario-traceability.sh`
resolves each scenario to this script. The script must not modify any file.

Acceptance:
- `scripts/check-stop-and-ask-matrix.sh` exists and is executable.
- Exit code 0 on the compliant repo state after Tasks 1–3.
- Each individual check FAILs (exit 1) when its corresponding artifact is broken
  (missing matrix section / missing agent reference / editable gate config /
  Confluence present).
- The script's output contains every `AC-009-NN-NN` ID from this spec.

---

## Open questions

1. **Matrix placement in `docs/SPEC_PIPELINE.md`.** I propose after
   `§Compensating control`, before `§Commit and push carve-out`. Confirm or re-home
   during the human gate.
2. **Task 3 enforcement form.** Option (a): add `edit` deny patterns to agent
   frontmatter. Option (b): rely on existing deny-all blocks where present and only
   patch the agents missing an `edit:` block. Both satisfy the acceptance criteria;
   the Coder picks the minimal change. No design decision needed from you unless
   you prefer agents to keep zero `edit:` blocks (default "ask" per opencode).
3. **Added rows.** Rows beyond the informal spec (spec-artifacts-not-found, gate
   WARN, Verifier FAIL, PR Opener precondition) were added to cover conditions that
   actually stop a run today. Confirm you want them in the authoritative matrix.
4. **Traceability vehicle.** Because this repo has no JVM/Go/Node test suite, Task 4
   ships a shell check script to carry the `AC-009-NN` IDs for the traceability
   gate. This matches the repo's existing `scripts/check-*.sh` pattern but is an
   implementation choice worth confirming before `/build`.
