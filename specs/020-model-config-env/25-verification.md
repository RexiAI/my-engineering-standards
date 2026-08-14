# 25-verification.md — spec-020 model-config-env

Verifier: spec-verifier (opencode-go/qwen3.7-plus)
Branch: spec/020-021-model-config-rn-sdlc
Date: 2026-08-13

---

## 1. Scenario traceability

**PASS.** Every AC-020-NN-MN ID in `20-acceptance/` (25 total) is cited by the
selftest or runtime-check output:

- `scripts/model-env.selftest.sh` output cites 24 IDs (all except AC-020-06-04).
- `scripts/model-env.runtime-check.sh` output cites AC-020-06-04 (plus
  AC-020-01-02 and AC-020-01-03 in its header comments).
- Combined: all 25 IDs covered.

```
$ grep -hoE "AC-020-[0-9]+-[0-9]+" specs/020-model-config-env/20-acceptance/*.md | sort -u
AC-020-01-01 .. AC-020-07-03  (25 IDs)
```

---

## 2. Full gate suite

### 2a. `bash -n` on all new scripts

**PASS.** Exit 0 for all five.

```
$ bash -n scripts/load-model-env.sh && bash -n scripts/check-model-env.sh && \
  bash -n scripts/model-env.selftest.sh && bash -n scripts/model-env.runtime-check.sh && \
  bash -n scripts/model-env.vars.sh && echo "ALL SYNTAX OK"
ALL SYNTAX OK
```

### 2b. `make lint`

**PASS.** Exit 0. All YAML files valid, all 35 required files present, all
cross-references valid, all SKILL.md files valid (1 pre-existing WARN for
hallmark line count).

### 2c. `make validate-all`

**PASS.** Exit 0. Required files present, cross-references valid, docs/
cross-refs valid, SKILL.md files valid.

### 2d. `scripts/check-orchestration.sh`

**PASS.** Exit 0. "All orchestration references valid."

### 2e. `scripts/check-skills.sh`

**PASS.** Exit 0. 1 pre-existing WARN (hallmark line count >500).

### 2f. CRLF scan on changed files

**PASS.** All 11 changed files checked; none contain CRLF line endings.

---

## 3. Complexity / design-principles gate

**PASS (for this branch).** `scripts/check-code-principles.sh` reports 5 FAILs
and 17 WARNs. All 5 FAILs are in files **not touched by this branch**:

| FAIL | File | Touched by branch? |
|---|---|---|
| CC=14 `checkCompensationPairs` | `ci/templates/go-saga-lint.go:101` | NO |
| CC=10 `checkOutboxCoLocation` | `ci/templates/go-saga-lint.go:163` | NO |
| CC=10 `checkSagaHandlerContext` | `ci/templates/go-saga-lint.go:207` | NO |
| CC=8 `resolveDirs` | `ci/templates/go-saga-lint.go:275` | NO |
| CC=7 `getSagaStepOptions` | `ci/templates/eslint-saga-rules/saga-compensation.js:56` | NO |

Confirmed via `git diff --name-only HEAD`: neither file appears in the diff.
These are pre-existing violations in saga templates, not regressions from
spec-020.

17 WARNs: all in `ci/templates/` saga/archunit files (pre-existing) or
duplication warnings in the same untouched files.

---

## 4. Task-level verification

### 4a. opencode.json (Task 1 / AC-020-01)

**PASS.**

```
$ python3 -c "import json; json.load(open('opencode.json'))"  # valid JSON
Agent count: 8
spec-specifier: {env:SPEC_SPECIFIER_MODEL}
spec-ux: {env:SPEC_UX_MODEL}
spec-verifier: {env:SPEC_VERIFIER_MODEL}
spec-mutation-runner: {env:SPEC_MUTATION_RUNNER_MODEL}
spec-pr-opener: {env:SPEC_PR_OPENER_MODEL}
spec-coder: {env:SPEC_CODER_MODEL}
spec-refactorer: {env:SPEC_REFACTORER_MODEL}
spec-pipeline: {env:SPEC_PIPELINE_MODEL}
```

- Valid JSON: YES
- 8 agents, all `{env:SPEC_*_MODEL}`: YES
- Zero literal model ids (`opencode-go/...`): NONE found
- Top-level keys: `['$schema', 'agent']` — no extra keys
- Agent keys: exactly the 8 expected
- No `model:` key in any `agents/*.md`: confirmed (grep returns nothing)

### 4b. config/model.local.env.example (Task 2 / AC-020-02)

**PASS.**

- 8 unique `SPEC_*_MODEL=` lines, no duplicates
- Correct defaults: `opencode-go/deepseek-v4-flash` for specifier/ux/coder/refactorer/pipeline; `opencode-go/qwen3.7-plus` for verifier/mutation-runner/pr-opener
- Comment line directly above every var
- Header documents: one-time profile wiring, optional copy→fill→restart, never commit
- File exists on disk

**Note on tracking:** `git ls-files --error-unmatch config/model.local.env.example`
exits 1 — the file is untracked in the working tree (`?? config/`). The selftest
uses the correct Verifier-stage invariant: "not gitignored AND stageable with
`git add --dry-run`" — which passes. The PR Opener (stage 5) will `git add` it
before committing. This is the expected state at verification time.

### 4c. .gitignore (Task 3 / AC-020-03)

**PASS.**

```
$ git check-ignore config/model.local.env  → exits 0 (IGNORED)
$ git check-ignore config/model.local.env.example  → exits non-zero (NOT IGNORED)
```

### 4d. scripts/load-model-env.sh (Task 4 / AC-020-04)

**PASS.** All 5 loader scenarios verified by selftest:

- AC-020-04-01: no local file → all 8 vars at example defaults, exit 0 ✓
- AC-020-04-02: partial local file → defined vars override, missing fall back ✓
- AC-020-04-03: pre-existing env var never clobbered ✓
- AC-020-04-04: no source → exit 1, stderr names the var ✓
- AC-020-04-05: runs from any cwd, non-interactively, defaults to repo root ✓

### 4e. scripts/check-model-env.sh (Task 5 / AC-020-05)

**PASS.** All 5 check-script branches verified by selftest:

- AC-020-05-01: literal model id → exit 1, names spec-coder ✓
- AC-020-05-02: all env refs + example wired → exit 0 with PASS ✓
- AC-020-05-03: tracked real env file → exit 1, names path ✓
- AC-020-05-04: reference with no example default → exit 1, names SPEC_CODER_MODEL ✓
- AC-020-05-05: example var with no reference → exit 1, names SPEC_UNUSED_MODEL ✓

Also verified against the real repo: `bash scripts/check-model-env.sh` exits 0
with PASS line.

### 4f. scripts/model-env.selftest.sh (Task 6 / AC-020-06)

**PASS.** 30/30 PASS.

```
selftest: 30 passed, 0 failed
✔ model-env.selftest: all cases pass.
```

- All AC-020 IDs cited in output (24 of 25; AC-020-06-04 is runtime-check only)
- Self-trip constraint: fixture model ids built at runtime via string
  concatenation (`"$provider/""fast""$RANDOM""$RANDOM"`) — no inline literal
  model-id values
- Fixtures in `mktemp -d` with `trap` cleanup
- `set -euo pipefail` present

### 4g. scripts/model-env.runtime-check.sh (Task 6 / AC-020-06-04)

**PASS.** 4/4 PASS (with correct binary path).

```
$ bash scripts/model-env.runtime-check.sh /tmp/opencode/opencode
PASS AC-020-06-04 opencode binary runs (--version)
PASS AC-020-06-04 case 1: loader sourced, no local file — all 8 agents resolve to fixture example defaults
PASS AC-020-06-04 case 2: local-file override and pre-set env override win, remaining agents stay at defaults
PASS AC-020-06-04 case 3: loader not sourced — every agent resolves to null/empty
runtime-check: 4 passed, 0 failed
```

Binary: `/tmp/opencode/opencode`, v1.18.18, extracted from pinned tarball.

**Note on self-ci.yml path:** The workflow passes `/tmp/opencode` (not
`/tmp/opencode/opencode`). On a clean CI runner, `tar -xzf ... -C /tmp` extracts
the single file `opencode` to `/tmp/opencode` — so the path is correct in CI.
Locally, `/tmp/opencode` is a pre-existing directory from earlier testing;
passing the full binary path `/tmp/opencode/opencode` works correctly.

### 4h. .github/workflows/self-ci.yml (Task 6 / AC-020-06-05)

**PASS.**

- Downloads pinned v1.18.18 tarball from public GitHub release URL (no token)
- Extracts to `/tmp`, runs `/tmp/opencode --version`
- Runs `bash scripts/check-model-env.sh`, `bash scripts/model-env.selftest.sh`,
  `bash scripts/model-env.runtime-check.sh /tmp/opencode`
- No `continue-on-error` on the model-env step (the adjacent shellcheck step
  has `continue-on-error: true`, but that's a different step)
- `permissions: contents: read` preserved
- YAML parses (make lint covers it)

### 4i. docs/SPEC_PIPELINE.md + AGENTS.md (Task 7 / AC-020-07)

**PASS.**

- SPEC_PIPELINE.md §Model configuration: documents one-time profile wiring,
  optional copy→fill→restart, no commit/PR, precedence (env > local > example),
  empty-string boundary, shell-launched boundary, fail-loudly behavior
- AGENTS.md: model table notes per-machine values from `config/model.local.env`
  via `scripts/load-model-env.sh`, switching = edit local file + restart
- Both docs cite `scripts/check-model-env.sh` as structural enforcement
- Both docs mention self-ci pinned-binary runtime check
- `make validate-all` confirms all cross-references valid

---

## 5. Scope check

**PASS.** `git diff --name-only HEAD` shows only spec-020 files:

- `.github/workflows/self-ci.yml`
- `.gitignore`
- `AGENTS.md`
- `docs/SPEC_PIPELINE.md`
- `opencode.json`
- `specs/020-model-config-env/10-tasks.md`
- `specs/020-model-config-env/20-acceptance/AC-020-0{1,2,4,5,6,7}-*.md`

Untracked files: `config/`, `scripts/model-env.*`, `scripts/load-model-env.sh`,
`scripts/check-model-env.sh` (all spec-020). Other untracked dirs
(`commands/opsx-*`, `openspec/`, `specs/002-005`) are pre-existing (from Aug 10,
before this branch) — not defects.

---

## 6. Information-barrier check

**PASS.** Implementation matches `10-tasks.md` + `20-acceptance/` exactly. No
evidence of content from `00-informal.md` (which was not read). All tasks,
decisions, and acceptance criteria trace to the formal spec artifacts.

---

## 7. Design-principles gate (verbatim FAIL/WARN lines)

**5 FAILs** (all pre-existing, not in files touched by this branch):

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

**17 WARNs** (all pre-existing in `ci/templates/` saga/archunit files):

```
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
[+ 5 more duplication warnings in the same untouched files]
```

Exit code: 0 (WARNs are review hints, not pipeline stops).

---

## 8. Spot-check: 2 acceptance scenarios

**AC-020-04-03** (pre-existing exported var never clobbered): Selftest output
confirms the assertion — pre-set `SPEC_SPECIFIER_MODEL=opencode-go/process-env-win`
survives the loader even when `config/model.local.env` defines a different value.
PASS.

**AC-020-05-04** (reference with no example default fails): Selftest output
confirms — fixture with `SPEC_CODER_MODEL` referenced in `opencode.json` but
missing from the example → exit 1, output names `SPEC_CODER_MODEL`. PASS.

---

## Overall verdict

**PASS.**

All checks pass. The implementation matches `10-tasks.md` and `20-acceptance/`
exactly. All 25 acceptance scenarios are covered and verified. All gates are
green. The 5 design-principles FAILs are pre-existing in untouched saga template
files, not regressions from spec-020.

Architect may proceed to stage 5 (PR Opener).

---

## Evidence summary

| Check | Result | Evidence |
|---|---|---|
| Scenario traceability | PASS | 25/25 AC-020 IDs cited |
| `bash -n` (5 scripts) | PASS | ALL SYNTAX OK |
| `make lint` | PASS | All validations passed |
| `make validate-all` | PASS | All cross-refs valid |
| `check-orchestration.sh` | PASS | All references valid |
| `check-skills.sh` | PASS | 1 pre-existing WARN |
| CRLF scan | PASS | 0 CRLF files |
| Design-principles gate | PASS | 5 FAILs pre-existing, not in this branch |
| opencode.json structure | PASS | 8 agents, all `{env:...}`, no literals |
| config/model.local.env.example | PASS | 8 vars, correct defaults, comments, header |
| .gitignore | PASS | real file ignored, example not |
| Loader precedence | PASS | 5/5 scenarios (selftest) |
| Check script branches | PASS | 5/5 scenarios (selftest) |
| Selftest | PASS | 30/30 |
| Runtime check | PASS | 4/4 (with correct binary path) |
| self-ci.yml | PASS | pinned binary, no continue-on-error |
| Docs | PASS | one-time setup, precedence, enforcement cited |
| Scope | PASS | only spec-020 files changed |
| Information barrier | PASS | matches 10-tasks + 20-acceptance |
| Spot-check (2 scenarios) | PASS | AC-020-04-03, AC-020-05-04 verified |

