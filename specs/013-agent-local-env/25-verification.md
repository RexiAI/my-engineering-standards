# Verification — spec 013: Agent local environment (secrets per machine)

- Stage: 4 (Verifier) — `agents/spec-verifier.md`
- Branch: `spec/013-agent-local-env`
- Verified against: `specs/013-agent-local-env/10-tasks.md`, `specs/013-agent-local-env/20-acceptance/*.md`
- `00-informal.md` was not read (information barrier).
- Date: 2026-08-15

Every check below is a real execution with its real exit code / output, not a
paraphrase of a prior stage's report.

---

## 1. Scenario traceability — PASS (spec 013 scope clean)

Command: `bash scripts/check-scenario-traceability.sh`

Full-repo run: **exit 1**, 125 violations. As anticipated for a mid-pipeline
state, every violation is outside spec 013:

- Untraced scenarios in sibling in-flight specs: AC-007..012, AC-014, AC-015,
  AC-017..019 (`specs/*/20-acceptance/` present, no test cites them yet).
- Stale test references to archived spec IDs: AC-001..006, AC-016, AC-020..022
  (tests cite IDs whose scenario headings no longer exist — archived specs'
  citations, per the known condition).

Spec-013 scoped result (grep of the script's output for `AC-013`):

```
PASS AC-013-01 — traced to a test
PASS AC-013-02 — traced to a test
PASS AC-013-03 — traced to a test
PASS AC-013-04 — traced to a test
PASS AC-013-05 — traced to a test
PASS AC-013-06 — traced to a test
```

Both directions checked:

- Every `## AC-013-NN` heading (25 sub-scenarios across 6 files) is exercised by
  `scripts/agent-env.selftest.sh` (AC-013-01-01..01-04, 02-01..02-05,
  03-01..03-05, 04-01..04-05, 05-01..05-02, 06-01..06-03 — all present in the
  selftest as PASS/FAIL cases).
- Zero dangling AC-013 references: grep of every AC-013-NN citation across the
  tree (`scripts/`, `docs/`, `.github/`) shows citations only in
  `agent-env.selftest.sh`, `10-tasks.md`, and the acceptance files — none
  reference a non-existent heading, none cite an ID the selftest lacks.

Judgement: **AC-013 scope is clean.** The full-repo exit 1 is entirely
attributable to sibling/archived specs, not to spec 013.

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/load-env.sh` | 0 | parses |
| `bash -n scripts/guard-env.sh` | 0 | parses |
| `bash -n scripts/check-no-hardcoded-secrets.sh` | 0 | parses |
| `bash -n scripts/agent-env.selftest.sh` | 0 | parses |
| `bash scripts/agent-env.selftest.sh` | **0** | **28 passed, 0 failed** (`selftest: 28 passed, 0 failed` / `✔ agent-env.selftest: all cases pass.`) |
| `bash scripts/guard-env.sh` (real repo, CI mode) | 0 | `PASS guard-env: no config/agent.local.env in the scanned set (tracked mode).` |
| `bash scripts/check-no-hardcoded-secrets.sh` (real repo) | 0 | `PASS check-no-hardcoded-secrets: no hardcoded credential values in agents/, commands/, scripts/, docs/.` |
| `scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `bash scripts/check-model-env.sh` | 0 | `PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env file, example wired.` (file is mode 644 — pre-existing from spec 020, invoked via `bash`; not in spec-013 scope) |
| `bash scripts/model-env.selftest.sh` | 0 | 30 passed, 0 failed |
| `make validate-all` | 0 | `All validations passed.` (1 WARN: `skills/hallmark/SKILL.md` body 562 lines — pre-existing, unrelated) |
| `make lint` | 0 | `Done.` |

Selftest parse caveat caught and re-run correctly: `bash -n f1 f2 ...` only
syntax-checks the **first** argument, so the initial 5-file batch exit 0 was a
false green for files 2–5. Re-ran per-file (as self-ci's `find -name '*.sh'`
loop does) — all four new `.sh` files parse cleanly, each exit 0.

`scripts/load-env.ps1` is PowerShell, not bash: `bash -n` errors on its
`param(` (line 22) — **expected and correct**. self-ci's `bash -n` step globs
only `*.sh` (`.github/workflows/self-ci.yml:58`), so the `.ps1` is out of parse
scope by design; its acceptance per Task 3 / AC-013-03-05 is existence + a
documented parity contract, both satisfied (selftest asserts existence and the
header's parity terms: no-op, clobber, load-env.sh).

**self-ci wiring** — `.github/workflows/self-ci.yml` parses as YAML (PyYAML,
`jobs: ['validate']`), and the new step exists:

```yaml
- name: Check agent env guard and hardcoded secrets
  run: |
    set -euo pipefail
    bash scripts/guard-env.sh
    bash scripts/check-no-hardcoded-secrets.sh
    bash scripts/agent-env.selftest.sh
```

No `continue-on-error` on the new step (the only `continue-on-error: true` in
the job is the pre-existing shellcheck step, line 118). The step sits after the
implementation files and after the model-env step — runs on the working tree's
four scanned dirs as Task 8 requires.

## 3. Complexity gate — PASS

No bash complexity linter exists in this repo (shellcheck is the only shell
tool and is not a complexity gate); the complexity claim is therefore
spot-checked by counting decision points (`if/elif/for/while/case`, the same
heuristic `check-code-principles.sh` uses) in the current files:

| Function | Refactorer claim | Measured (current) |
|---|---|---|
| `guard_env_main` (guard-env.sh) | 8 → 5 | **5** (for, case, if -z, if MODE, if grep) |
| `load_env_main` (load-env.sh) | 7 → 3 + 5 | **3** (if -z root, if real, elif example) |
| `_load_env_export` (load-env.sh) | (part of 3+5) | **5** (while, case x3, if) |
| `scan_root` (check-no-hardcoded-secrets.sh) | max 6 | **5** (for, if -d, while x3, if) |
| `is_ignored_rhs` / `report_hit` | — | **1 / 0** |

Every function is ≤6. The pre-refactor values (8, 7) are **not independently
verifiable** — all scripts are new/untracked files on this branch, so no git
history of an earlier form exists. The current values match the claimed
post-refactor numbers exactly and satisfy the ≤6 rule, which is the gate that
matters. Selftest "untouched": also not verifiable from git (new file); the
28/28 green run above is the operative evidence.

## 3.5. Design-principles gate — PASS (no finding attributable to spec 013)

Command: `bash scripts/check-code-principles.sh` (default mode, repo root)

**Exit code: 1** — pre-existing state, 5 FAILs / 17 WARNs, **every line confined
to `ci/templates/*`**. FAIL lines, verbatim:

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARN lines, verbatim (all `ci/templates/*`, abbreviated to first occurrence —
full list is 17 lines):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): ...
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```
Summary line, verbatim: `✘ Design-principles check: 5 FAIL(s), 17 WARN(s).`

Scope note: the gate scans `.java/.go/.ts/.tsx/.js/.jsx` only — spec 013's
changed files are bash scripts, markdown, YAML, gitignore, and a `.env.example`
template, none of which the gate scans. A scoped run `bash
scripts/check-code-principles.sh scripts` exits **0** with no output (no
scanned-language files in scripts/). **No FAIL or WARN is attributable to spec
013.** The exit-1 root state is the documented pre-existing `ci/templates/*`
noise; flagged to the Architect as known/pre-existing, not a spec-013 defect.

Property-test tier: gate tier auto-detection finds **no `AGENTS_*.md`** at the
repo root (verified: `ls AGENTS_*.md` → not found), so no property-test check
applies — consistent with the mvp-tier claim (see §6).

## 4. Scenario-to-behavior spot check — PASS

Two scenarios manually executed against scratch trees in `/tmp` (independent of
the selftest, cleaned up after):

**AC-013-03-01 — loader fails loudly (example present, real missing):**
```
$ bash scripts/load-env.sh <scratch-only>
rc=1
stderr: ERROR: <scratch>/config/agent.local.env not found, but <scratch>/config/agent.local.env.example exists. Copy it and fill in real values:
  cp config/agent.local.env.example config/agent.local.env
```
Exit 1, names the missing path, prints the copy-fill step — matches the
Given/When/Then exactly.

**AC-013-02-02 — guard refuses a staged real file:**
```
$ printf 'GITHUB_TOKEN=rt-123\n' > <scratch>/config/agent.local.env
$ git -C <scratch> add config/agent.local.env
$ bash scripts/guard-env.sh --staged <scratch>
FAIL guard-env: config/agent.local.env is staged — the real env file must never be committed. Unstage it (git reset config/agent.local.env) before committing.
rc=1
```
Exit 1, names the offending path `config/agent.local.env` — matches. Clean
scratch repo → `PASS guard-env: no config/agent.local.env in the scanned set
(staged mode).`, rc=0 (AC-013-02-04).

Additional behaviors exercised (supporting scenarios AC-013-03-03/04,
AC-013-04-01/02, AC-013-02-01, Task 5's live fix):

- **No clobber (AC-013-03-04):** `export GITHUB_TOKEN=already-set` then source
  a fixture real file defining `GITHUB_TOKEN=file-value` → resulting env keeps
  `already-set`. Matches the scenario's "pre-existing exported variables are
  never clobbered". (Edge note, not a failure: the no-clobber test uses
  `${!var:-}`, so an *empty-but-exported* var would be refilled from the file —
  no scenario covers an empty pre-set; behavior is consistent with the model
  loader's empty-falls-through precedence.)
- **Both files missing (AC-013-03-03):** rc=0, 0 bytes on stderr.
- **Secrets check flags literals (AC-013-04-01/02):** fixture `agents/leak.txt`
  containing `GITHUB_TOKEN=ghp_abc123xyz` → exit 1, output prints
  `agents/leak.txt:1` twice (literal token prefix + secret-style assignment),
  summary `✘ check-no-hardcoded-secrets: 2 violation(s)`. Real repo → exit 0.
- **okf literal rewritten (Task 5):** `okf/mcp-server-connection.md:79` now
  reads `export GITHUB_TOKEN=<your-github-personal-access-token>` — the
  literal `ghp_...` is gone (verified by grep of the file).
- **.gitignore (AC-013-02-01):** `git check-ignore config/agent.local.env` →
  exit 0 (ignored, file absent on disk); `git check-ignore
  config/agent.local.env.example` → exit 1 (not ignored, trackable).
- **Template (AC-013-01):** `config/agent.local.env.example` exists; exactly
  two `KEY=value` lines (`GITHUB_TOKEN`, `GH_TOKEN`), both `<...>` placeholders
  with a comment line directly above each; header states
  copy → fill → never commit (confirmed by read + selftest AC-013-01-01..04).
- **Docs (AC-013-05, AC-013-06):** AGENTS.md §Per-machine agent environment
  walks copy/fill/source/never-commit, names both tokens + both enforcement
  scripts; `agents/spec-pr-opener.md` gains the defensive `source
  scripts/load-env.sh` step with `$GITHUB_TOKEN`/`$GH_TOKEN` from the
  environment; `agents/spec-pipeline.md` documents the pre-loaded shell
  (confirmed by read + selftest).

## 5. No unaccounted behavior — PASS

Diff skim (6 modified files + 5 new files). Every change traces to a task:

| Change | Task |
|---|---|
| `.github/workflows/self-ci.yml` — new validate step (guard + secrets + selftest, no continue-on-error) | Task 8 |
| `.gitignore` — `config/agent.local.env` rule | Task 2 |
| `AGENTS.md` — §Per-machine agent environment | Task 7 |
| `agents/spec-pipeline.md` — pre-loaded shell note | Task 6 |
| `agents/spec-pr-opener.md` — defensive loader sourcing | Task 6 |
| `okf/mcp-server-connection.md:79` — placeholder rewrite | Task 5 |
| `config/agent.local.env.example` (new) | Task 1 |
| `scripts/load-env.sh`, `scripts/load-env.ps1` (new) | Task 3 |
| `scripts/guard-env.sh` (new) | Task 4 |
| `scripts/check-no-hardcoded-secrets.sh` (new) | Task 5 |
| `scripts/agent-env.selftest.sh` (new) | Task 8 |

No orphan logic found. The two script-level design choices (no-clobber via
`${!var:-}`, guard `ROOT` positional arg for scratch-repo testing) are exactly
the mechanisms Task 3/Task 4 specify. Self-trip constraint verified: grep for
the literal token patterns in `agent-env.selftest.sh` and
`check-no-hardcoded-secrets.sh` finds nothing (fixtures built via `GHP="ghp""_"`
concatenation and `mktemp -d`), and the check passes over the real `scripts/`
dir — the selftest does not trip the check it proves (AC-013-04-05).

## 6. mvp-tier claim — CONFIRMED

No `AGENTS_*.md` exists at the repo root (`ls AGENTS_*.md` → not found). The
design-principles gate's tier auto-detection therefore applies no
property-test check, and the mvp-tier skips (no property-test gate, no
Architect mutation gate) per `docs/SPEC_PIPELINE.md` §Conformance tiers are
correct.

---

## Overall verdict: **PASS**

Every spec-013 check is green:

1. Traceability — AC-013-01..06 all traced, zero dangling refs (full-repo exit 1
   is entirely sibling/archived-spec noise).
2. Suite — selftest 28/28 exit 0; guard exit 0; secrets check exit 0;
   orchestration exit 0; model-env check + selftest exit 0; `make validate-all`
   exit 0; `make lint` exit 0; self-ci YAML parses with the new step, no
   continue-on-error.
3. Complexity — all new functions ≤6; measured values match the claimed
   post-refactor numbers (5 / 3+5 / max 5).
3.5. Design-principles gate — exit 1 from the pre-existing `ci/templates/*`
   FAILs/WARNs only; zero findings attributable to spec 013 (bash + docs out of
   the gate's language scope; `scripts`-dir scoped run exits 0).
4. Scenario-to-behavior — loader fail-loud, no-clobber, both-missing, guard
   `--staged`, secrets literal detection, okf rewrite, gitignore coverage all
   confirmed by manual execution.
5. No unaccounted behavior — every diff hunk traces to Tasks 1–8.
6. mvp-tier claim confirmed (no `AGENTS_*.md`), so the property-test/mutation
   skips are correct.

Architect may proceed. Flagged as review hints only (not failures): (a) the
root design-principles exit 1 is pre-existing `ci/templates/*` debt, already
known; (b) `scripts/check-model-env.sh` is mode 644 and must be invoked via
`bash` (pre-existing, spec 020); (c) load-env no-clobber treats empty pre-set
vars as unset (uncovered edge, consistent with existing precedence).
