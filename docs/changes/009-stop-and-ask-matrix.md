# 009-stop-and-ask-matrix

> Spec pipeline archive. Original source: `specs/009-stop-and-ask-matrix/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# Stop-and-Ask decision matrix

Resolve these the same way every run — never improvise. A table in
docs/SPEC_PIPELINE.md, referenced by every pipeline agent:

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report; never stash or auto-commit |
| Repo not found after discovery | Ask for the absolute path once; never scaffold unprompted |
| Project type ambiguous | Defer to harness default; ask only if interactive and unconfirmed |
| Confluence space/parent unknown | Ask once per run; if still unknown, WARN and continue |
| Version bump not requested | Off by default; never infer from SemVer or diff |
| A design gate blocks | Fix the code, never the threshold — gate config is off-limits to agents |
| Out-of-scope finding | Record in outOfScopeFindings[], do not fix; propose follow-up |
| Acceptance criteria ambiguous | Resolve before delegating implementation |

## Acceptance criteria

- AC-001: docs/SPEC_PIPELINE.md contains the matrix; every pipeline agent
  frontmatter or body links to it.
- AC-002: the "fix the code, never the threshold" rule is enforced in
  check-code-principles.sh / design-gate defaults (agent cannot edit the config).
- AC-003: each pipeline agent's prompt references the matrix as authoritative.

## Tasks

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

## Acceptance scenarios

## AC-009-01-01 — Matrix section exists
## AC-009-01-02 — Matrix declares itself authoritative
## AC-009-01-03 — All 11 conditions have deterministic actions
## AC-009-01-04 — No Confluence row
## AC-009-01-05 — Dirty working tree action is STOP and report
## AC-009-02-01 — All 8 agents reference the matrix section
## AC-009-02-02 — Each reference states the matrix is authoritative
## AC-009-02-03 — No other pipeline-touching file is required to change
## AC-009-03-01 — No agent may edit gate config
## AC-009-03-02 — Threshold stays a hard constant
## AC-009-03-03 — Script's threshold value unchanged
## AC-009-03-04 — Matrix row preserves the rule
## AC-009-04-01 — Script exists and is executable
## AC-009-04-02 — Script passes on a compliant repo
## AC-009-04-03 — Script fails when the matrix section is missing
## AC-009-04-04 — Script fails when an agent lacks the matrix reference
## AC-009-04-05 — Script fails when an agent may edit gate config
## AC-009-04-06 — Script fails when a Confluence row appears
## AC-009-04-07 — Script cites every scenario ID for traceability
## AC-009-04-08 — Script is read-only

## Verification

# Verification Report — Spec 009: Stop-and-Ask decision matrix

- **Stage**: 4 (Verifier)
- **Date**: 2026-08-15
- **Branch**: `spec/009-stop-and-ask-matrix` (working-tree changes; HEAD == main tip `3013d8d`)
- **Verified against**: `10-tasks.md`, `20-acceptance/AC-009-01..04.md` (not `00-informal.md`)

Changed footprint: `docs/SPEC_PIPELINE.md` (+19), `agents/spec-{pipeline,specifier,ux,coder,refactorer,verifier,mutation-runner,pr-opener}.md` (+61 total, 0 deletions), new untracked `scripts/check-stop-and-ask-matrix.sh`. No other files touched.

---

## Check 1 — Scenario traceability — PASS (AC-009 scope clean)

Command: `bash scripts/check-scenario-traceability.sh` (script is `644`, not executable — pre-existing; direct exec returns 126 Permission denied).

**Full-repo result: exit 1, "127 violation(s)"** — expected mid-pipeline condition:
- 77 scenario IDs found.
- Every FAIL is either a sibling in-flight spec with untraced scenarios (AC-007-01..04, AC-008-01..05, AC-010-01..06, AC-011-01..03, AC-012-01..08, AC-013-01..06, AC-014-01..05, AC-015-01..16, AC-017-01..05, AC-018-01..08, AC-019-01..07) or an archived-spec citation with no matching scenario (AC-001-01..06, AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04, AC-006-01..06, AC-016-01..05, AC-020-01..07, AC-021-01..08, AC-022-01..04).

**Scoped AC-009 result — clean**:
```
PASS AC-009-01 — traced to a test
PASS AC-009-02 — traced to a test
PASS AC-009-03 — traced to a test
PASS AC-009-04 — traced to a test
```
No AC-009 FAIL anywhere in the run; no dangling AC-009 reference. The 20 sub-scenario IDs cited by the Coder all appear in `scripts/check-stop-and-ask-matrix.sh` output: AC-009-01-01..05, AC-009-02-01..03, AC-009-03-01..04, AC-009-04-01..08 (verified by reading the full script output — every PASS/FAIL line carries its AC-009-NN-NN ID). Judgment: AC-009 scope is clean; the full-repo exit 1 is attributable entirely to sibling in-flight specs and archived-spec citations, not to spec 009.

## Check 2 — Full relevant suite — PASS

This repo's test framework is the `scripts/check-*.sh` + Makefile pattern (no JVM/Go/Node suite — documented in `10-tasks.md`). Ran all relevant gates:

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-stop-and-ask-matrix.sh` | 0 | syntax clean |
| `scripts/check-stop-and-ask-matrix.sh` | 0 | every check PASS; output cites all 20 AC-009-NN-NN IDs (see Check 4 for negative fixtures) |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." (agent/skill/script/doc references all resolve — confirms the 8 agent files' new references don't break orchestration) |
| `make validate-all` | 0 | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines >500 — untouched by this spec) |
| `make lint` | 0 | all JSON/YAML valid |

## Check 3 — Complexity gate — PASS

The changed code is one bash script (no PMD/golangci/eslint applies; the repo's shell-complexity gate is the ≤6 rule from `docs/CODING_CONVENTIONS.md`, mechanically enforced for this script by inspection — `check-code-principles.sh` measures Java/Go/JS only). Hand-verified decision-point counts per function (bash keywords only; excluded `if`/`&&` inside single-quoted awk strings):

- `edit_effective_action` — **5** (`&&`×3, `while`×1, `if`×1) — worst offender, ≤6 ✓
- `glob_to_regex` — 0 (single `printf | sed` pipeline) ✓
- `extract_matrix_section` — 0 (one awk command substitution) ✓
- `fail`/`pass` — 0 ✓

Refactorer claims confirmed against current state:
- **No function over 6; worst offender `edit_effective_action` = 5**: confirmed (count above).
- **`glob_to_regex` pipelines consolidated 3→1**: confirmed — exactly one sed pipeline (lines 95–102).
- **4 redundant empty-then branches inverted**: confirmed end-state — script-wide scan found zero `then` lines with empty bodies (no `then` immediately followed by `fi`/`else`); every branch has a real body. (History not diffable — file is new/untracked — but the claimed end-state holds.)

## Check 3.5 — Design-principles gate — PASS (no FAIL/WARN attributable to spec 009)

Command: `scripts/check-code-principles.sh` (default mode, repo root). **Exit code: 1** — 5 FAIL(s), 17 WARN(s). Line output is ANSI-colored; verbatim content below with escape codes stripped:

FAILs (all in `ci/templates/*`, untouched by this spec):
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARNs (17; all in `ci/templates/*`):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): } /return violations /} /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): schema: [], /}, /create(context) { /},
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): return violations /} / /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): } /} /} /violations++
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): } /} /return violations /}
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): violations++ /} /} /pos, fn.Name.Name)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

**Judgment**: the gate exits 1 with the FAILs/WARNs confined entirely to `ci/templates/*` — a pre-existing, documented state (spec 009 changed only `.md` and `.sh` files; the gate scans `.java`/`.go`/`.js`). **No FAIL or WARN is attributable to spec 009.** The new script produced zero findings on its own file. Property tests correctly skipped: "Property tests: skipped (project tier is mvp — production+ required)" ×3 — consistent with the mvp-tier claim (below).

**mvp-tier claim — confirmed**: no `AGENTS_<PROJECT>.md` exists at repo root (find returned nothing; only `AGENTS.md` and `docs/AGENTS_AND_SKILLS.md` present). Per `docs/CONFORMANCE_TIERS.md` ("A project states its tier once, in its own `AGENTS_<PROJECT>.md` or equivalent"), the absent declaration defaults the tier to mvp — so the property-test skip (Check 3.5) and the Architect mutation-testing skip (`docs/SPEC_PIPELINE.md` stage table: "Architect — mutation testing: skip" at mvp) are both correct.

## Check 4 — Scenario-to-behavior spot check — PASS

Picked AC-009-01-01 (matrix section exists) and AC-009-01-02 (authoritative declaration), plus manual confirmation of the enforcement scenarios AC-009-03-01 and AC-009-04-03..06 via live negative fixtures.

- **AC-009-01-01/02** — `docs/SPEC_PIPELINE.md` line 203: `## Stop-and-Ask decision matrix`, positioned **after** `## Compensating control` (line 190) and **before** `## Commit and push carve-out` (line 222) — exactly the placement the task proposes. Section body lines 205–206: "This matrix is authoritative for every pipeline agent: each agent resolves the listed conditions per the matrix, never by improvisation." — matches the Given/When/Then.
- **AC-009-02-02 (agent wording)** — all 8 agents carry the same sentence: "The `Stop-and-Ask decision matrix` in `docs/SPEC_PIPELINE.md` is authoritative for you: resolve every condition listed there per the matrix, never by improvisation." (verified in the diff; e.g. `agents/spec-verifier.md` lines 20–21). Exact section title `Stop-and-Ask decision matrix` present in each — grep-resolvable as the task requires.
- **AC-009-03-01 (gate-config lock)** — read all 8 frontmatters: 6 agents (pipeline, ux, coder, refactorer, mutation-runner, pr-opener) gained explicit `"**/check-code-principles.sh": deny`, `"**/pmd*.xml": deny`, `"**/*golangci*.yml": deny`, `"**/.eslintrc*": deny` (+ `"*": ask`); spec-specifier and spec-verifier rely on their existing `"*": deny` catch-all. The check script resolves each pattern via `glob_to_regex` and confirmed effective `deny` for all 8×5 (agent×gate-path) combinations (PASS AC-009-03-01).
- **Negative fixtures run for real** (scratch copy of the tree under `/tmp/opencode/fix009`, deleted after):

| Fixture | Manipulation | Exit | Failure line |
|---|---|---|---|
| AC-009-04-03 | removed `## Stop-and-Ask decision matrix` heading | 1 | `FAIL AC-009-01-01 — docs/SPEC_PIPELINE.md is missing the '## Stop-and-Ask decision matrix' heading` |
| AC-009-04-04 | removed all title lines from `agents/spec-coder.md` | 1 | `FAIL AC-009-02-01 — spec-coder.md missing the exact section title 'Stop-and-Ask decision matrix'` |
| AC-009-04-05 | injected `"scripts/check-code-principles.sh": allow` into `spec-pipeline.md` edit block | 1 | `FAIL AC-009-03-01 — spec-pipeline.md permission.edit does not deny scripts/check-code-principles.sh (effective: allow)` |
| AC-009-04-06 | injected `\| Confluence space / parent page unknown \| Ask for the doc space \|` row into matrix | 1 | `FAIL AC-009-01-04 — forbidden Confluence reference in the matrix section: [\| Confluence space / parent page unknown \| Ask for the doc space \|]` |

Each FAIL names the offending artifact as the scenarios require. (First fixture-B attempt was invalid — appending `X` to the title still contains the substring, grep -F semantics — rerun with full line removal; noted for completeness, not a script defect.) Base fixture (unmodified copy) exited 0, proving the negatives aren't trivially-always-fail.

## Check 5 — No unaccounted behavior — PASS

Working-tree diff skimmed in full:
- `docs/SPEC_PIPELINE.md`: +19 lines, exactly the matrix section (heading, authoritative sentence, 11-row table). Nothing else. Traces to Task 1 / AC-009-01.
- 8 agent files: every added line is either (a) the authoritative-reference sentence (Task 2 / AC-009-02-01/02) or (b) the 5-line edit-deny block on the 6 agents that lacked a deny-all (Task 3 / AC-009-03-01); spec-specifier and spec-verifier got only the sentence because their existing `"*": deny` already satisfied Task 3 (the task's option (b), minimal change). 0 deletions.
- `scripts/check-stop-and-ask-matrix.sh`: read in full (366 lines). Non-vacuous: the 11 condition/action pairs in its arrays match `10-tasks.md` verbatim; Check 2 greps the exact section title plus `authoritative` + `never by improvisation` in each agent; Check 3 parses real frontmatter `permission.edit` blocks (`edit_effective_action` + `glob_to_regex`) against 5 concrete gate paths incl. the `.standards/` twin and the three linter configs; AC-009-03-02 greps `> 6` and asserts no `--threshold`/`--complexity` flag; AC-009-03-03 uses `git diff --quiet` to assert the gate script is untouched. AC-009-04-07/08 are self-describing PASS lines, but both hold independently: all 20 sub-IDs genuinely appear in output (traceability script independently resolved AC-009-01..04 against it), and the script performs no writes (no redirects/`sed -i`/`tee`/`cp`/`mv` anywhere — read-only confirmed by inspection and by running it against a scratch copy with no side effects).
- The script takes an optional ROOT arg for scratch verification (matches AC-007's scoped-flag pattern) and is read-only by construction; no task forbids the arg, and it does not violate any acceptance criterion.

---

## Verdict: **PASS**

All five checks pass. Full-repo `check-scenario-traceability.sh` exits 1 and `check-code-principles.sh` exits 1, but both are entirely explained by pre-existing, documented repo state (sibling in-flight specs + archived-spec citations; `ci/templates/*` findings) — **zero violations attributable to spec 009**, whose own scope (matrix doc, 8 agent references, gate-config lock, check script) is clean on every gate. Gate-config lock proven to hold and to detect a violation. mvp-tier claim (no `AGENTS_<PROJECT>.md`) confirmed, making the property-test and mutation skips correct. Architect (stage 5) may proceed.

Review hints for the Architect (WARNs recorded, not stops): the 17 design-principles WARNs in `ci/templates/*` are pre-existing; a follow-up spec could address the `ci/templates` FAILs (CC 14/10/10/8/7), none of which belong to this spec.

## Quality gates

# Mutation Runner Report — Spec 009: Stop-and-Ask decision matrix

- **Stage**: 5a (Mutation Runner)
- **Date**: 2026-08-15
- **Branch**: `spec/009-stop-and-ask-matrix`
- **Tier**: `mvp` (no `AGENTS_<PROJECT>.md` at repo root — confirmed by Verifier Check 3.5)

---

## Verifier verdict (carried forward)

**PASS** — `specs/009-stop-and-ask-matrix/25-verification.md` exists, verdict PASS. All five Verifier checks pass: AC-009 scenario traceability clean, full relevant suite green, complexity gate ≤6, no design-principles FAIL/WARN attributable to this spec, scenario-to-behavior spot checks (incl. live negative fixtures) pass, no unaccounted behavior.

## Mutation score

**skipped — mvp tier.** Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier gate and is skipped at `mvp`. Additionally, the changed code is a shell check script (`scripts/check-stop-and-ask-matrix.sh`) plus markdown docs/agent prompts — no mutation tooling for shell exists in this repo, and none applies to markdown. No mutation tooling attempted.

## Complexity summary (carried from the Refactorer, re-confirmed by the Verifier)

No PMD/golangci/eslint applies (bash + markdown footprint). Shell-complexity gate is the ≤6 decision-point rule from `docs/CODING_CONVENTIONS.md`, enforced by inspection:

- `edit_effective_action` — **5** (`&&`×3, `while`×1, `if`×1) — worst offender, ≤6 ✓
- `glob_to_regex` — 0 (single `printf | sed` pipeline) ✓
- `extract_matrix_section` — 0 (one awk command substitution) ✓
- `fail`/`pass` — 0 ✓

No function over 6; worst offender `edit_effective_action` = 5. Refactorer end-state confirmed: `glob_to_regex` pipelines consolidated 3→1; zero empty-then branches remain.

## Equivalent mutants

**None.** No mutation run was performed (mvp tier), so no mutants of any kind — equivalent or otherwise — were generated.

## Final test status

Full relevant suite re-run one final time after the skip note (no new code was written this stage, so no mutation-kill tests exist to cover):

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-stop-and-ask-matrix.sh` | 0 | syntax clean |
| `scripts/check-stop-and-ask-matrix.sh` | 0 | every check PASS; all 20 AC-009-NN-NN sub-IDs cited in output |
| `scripts/check-orchestration.sh` | 0 | "All orchestration references valid." |
| `make validate-all` | 0 | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines >500 — untouched by this spec) |
| `specs/009-stop-and-ask-matrix/25-verification.md` | — | exists, verdict **PASS** |

**GREEN.** Spec 009 complete and gate-clean at `mvp` tier. Stage 5b (PR Opener) may proceed.
