# Verification Report — spec 025 (direnv model env)

Branch: `spec/025-direnv-model-env` (nothing committed; working tree dirty by design — staged deletions of the loaders + modified files + untracked new files, per the Coder/Refactorer handoff).
Verifier: spec-verifier (stage 4). `00-informal.md` was not read. All evidence below was executed, not read from prior reports.

---

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --json
exit: 1
at: 2026-08-19T14:46:00Z

Full transcript (passes verbatim; fails summarized by class — the JSON contains 190 fail entries, all from archived-spec citations in files this spec did not touch; complete raw JSON captured at /tmp/opencode during this run and reproducible with the same command):

```json
{
  "checks": [1, 2],
  "passes": [
    "AC-025-01 — traced to a test",
    "AC-025-02 — traced to a test",
    "AC-025-03 — traced to a test",
    "AC-025-04 — traced to a test",
    "AC-025-05 — traced to a test",
    "AC-025-06 — traced to a test",
    "AC-025-07 — traced to a test"
  ],
  "fails": [
    "AC-001-01 … AC-022-04 — referenced in a test but no matching scenario heading exists in specs/*/20-acceptance/. Stale ID after a rename, or a typo.",   // 182 archived-spec IDs, one line each in the raw JSON
    "AC-888-88 — referenced in a test but no matching scenario heading exists …",
    "AC-998-01 — referenced in a test but no matching scenario heading exists …",
    "AC-999-01 — referenced in a test but no matching scenario heading exists …",
    "AC-999-02 — referenced in a test but no matching scenario heading exists …",
    "AC-999-03 — referenced in a test but no matching scenario heading exists …",
    "AC-999-99 — referenced in a test but no matching scenario heading exists …"
  ]
}
```

Attribution analysis (this is why exit 1 is not a spec-025 defect):
- Check 1 (scenario→test): **exit 0 in isolation** — `bash scripts/check-scenario-traceability.sh --checks 1 --json` → exit 0, every AC-025-01…07 heading traced.
- Check 2 (reference→scenario) fails contain **zero AC-025-* entries**. Every failing ID (AC-001…022, AC-888/998/999) is referenced only in **unmodified files**: `docs/changes/*.md` historical archives (verified by grep: the referrers of AC-001-01, AC-999-01, etc. are all under `docs/changes/`), plus the pre-existing worked-example headings `## AC-002-01/02` in `docs/SPEC_PIPELINE.md` §Scenario format (present on HEAD; this spec's diff adds **zero** AC-* lines to that file — `git diff HEAD -- docs/SPEC_PIPELINE.md | grep -cE '^\+.*AC-'` = 0).
- This fail pattern is the repo's documented baseline: `docs/changes/009-stop-and-ask-matrix.md` ("archived-spec citation with no matching scenario (AC-001-01..06, …)"), `docs/changes/019-daily-triage-loop.md` ("FAIL AC-001-01..06 …"), `docs/changes/015-auditable-agent-steps.md` ("archived-spec citations (AC-001-01 .. AC-006-06 …)") all record the identical state from prior pipeline runs.

Sub-scenario coverage (independent of the script): 48 scenario IDs (`grep -rhoE '^## AC-025-[0-9]{2}-[0-9]{2}' specs/025-direnv-model-env/20-acceptance/*.md`, count = 48) — **all 48 cited** by `scripts/model-env.selftest.sh` (48 unique), with `scripts/model-env.runtime-check.sh` adding AC-025-06-07/08/09 and `scripts/agent-env.selftest.sh` citing AC-025-02-04/03-04. **Zero dangling**: 48 unique IDs cited in tests, all 48 resolve to scenario headings (comm = ∅).

---

## Evidence: full test suite

All commands executed with real exit codes; no tests skipped, no `--emit`/loader cases remain (grep of the three scripts for `--emit` and `load-` = zero matches).

command: bash scripts/model-env.selftest.sh; bash scripts/agent-env.selftest.sh; bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode
exit: 0
at: 2026-08-19T14:47:00Z

--- run 1/3: bash scripts/model-env.selftest.sh ---

```
== AC-025-01 .envrc gitignored + dotenv templates ==
PASS AC-025-01-01 root .gitignore contains a line matching ^.envrc$
PASS AC-025-01-01 .envrc on disk: git ls-files non-zero, git check-ignore exit 0
PASS AC-025-01-02 AC-025-01-03 .envrc.example tracked (or committable pre-commit)
PASS AC-025-01-02 AC-025-01-03 .envrc.child tracked (or committable pre-commit)
PASS AC-025-01-02 templates/.envrc.example has exactly three dotenv_if_exists lines
PASS AC-025-01-02 example line order: committed example -> per-machine override -> credentials
PASS AC-025-01-02 no eval / bash invocation / source / . / emit flag in executable lines
PASS AC-025-01-03 templates/.envrc.child has exactly three dotenv_if_exists lines
PASS AC-025-01-03 child line order: .standards committed example -> child override -> child credentials
PASS AC-025-01-03 no eval / bash invocation / source / . / emit flag in executable lines
PASS AC-025-01-04 no .envrc path outside templates/ (tracked or committable)
PASS AC-025-01-05 git check-ignore exits 0 for both real env files
PASS AC-025-01-05 examples are not ignored (templates stay trackable)
PASS AC-025-01-06 .envrc.example header documents direnv allow, the three file roles, never-commit
PASS AC-025-01-06 .envrc.child header documents direnv allow, the three file roles, never-commit
== AC-025-02 parent .envrc semantics ==
PASS AC-025-02-01 AC-025-06-03 example alone: all 8 vars non-empty, plus-tier -> plus, fast-tier -> fast, exit 0
PASS AC-025-02-02 AC-025-06-03 override file: SPEC_SPECIFIER_MODEL wins, other 7 keep defaults, exit 0
PASS AC-025-02-03 AC-025-06-03 clobber: example value wins over the pre-exported var (dotenv line clobbers)
PASS AC-025-02-04 AC-025-06-03 credentials: GITHUB_TOKEN + GH_TOKEN load from the third line, model vars intact
PASS AC-025-02-04 credentials line executes after the model-var lines
PASS AC-025-02-05 missing override/credential files: no-op, no error, exit 0
PASS AC-025-02-05 no files at all: exit 0, nothing exported
PASS AC-025-02-06 no root .envrc on disk — stale-copy guard trivially satisfied
PASS AC-025-02-07 live direnv: SPEC_SPECIFIER_MODEL resolves non-empty after allow
== AC-025-03 child template + bootstrap ==
PASS AC-025-03-01 AC-025-06-04 no child files: all 8 vars resolve to the parent's committed defaults, exit 0
PASS AC-025-03-02 AC-025-06-04 child override: SPEC_CODER_MODEL wins, other 7 keep parent defaults, exit 0
PASS AC-025-03-03 standards git index lists neither real env file
PASS AC-025-03-03 .standards-relative line resolves against the committed example only; defaults still resolve
PASS AC-025-03-04 AC-025-06-04 child credentials: GITHUB_TOKEN + GH_TOKEN from the child's own file
PASS AC-025-03-05 bootstrap writes .envrc as a copy of templates/.envrc.child
PASS AC-025-03-05 bootstrap appends .envrc to the child root .gitignore
PASS AC-025-03-05 child config/.gitignore covers model.local.env and agent.local.env
PASS AC-025-03-05 next-steps git add list does not name .envrc
PASS AC-025-03-05 re-run: bootstrap prints a skip message and does not overwrite .envrc
PASS AC-025-03-06 live direnv: bootstrapped child resolves the parent's committed default (spec-verifier)
PASS AC-025-03-06 live direnv: child override wins after adding config/model.local.env
== AC-025-04 loaders removed + purge ==
PASS AC-025-04-01 the loader scripts are deleted (index + worktree)
PASS AC-025-04-02 no emit-flag string in any live surface
PASS AC-025-04-03 no loader-name string in any live surface
PASS AC-025-04-04 agents/spec-pipeline.md and spec-pr-opener.md cite no loader
PASS AC-025-04-04 PR Opener verifies GITHUB_TOKEN + GH_TOKEN non-empty, reports + stops when missing, sources nothing
PASS AC-025-04-05 ci-sweeper.yml cites no loader
PASS AC-025-04-05 ci-sweeper headless run loads committed defaults via the dotenv-equivalent
PASS AC-025-04-06 model.local.env.example header documents the direnv dotenv_if_exists flow
PASS AC-025-04-06 agent.local.env.example header documents the direnv dotenv_if_exists flow
PASS AC-025-04-07 check-orchestration.sh exits 0 (scripts/ paths in agents/, commands/, AGENTS.md resolve)
== AC-025-05 check-model-env branches ==
PASS AC-025-05-01 check-model-env exits 0 on the real repo with a PASS line
PASS AC-025-05-02 literal model id: exit 1, output names the offending agent (spec-coder)
PASS AC-025-05-03 AC-025-06-05 tracked config/model.local.env: exit 1, output names the path
PASS AC-025-05-04 AC-025-06-05 tracked config/agent.local.env: exit 1, output names the path
PASS AC-025-05-05 reference with no example default: exit 1, output names SPEC_CODER_MODEL
PASS AC-025-05-06 example var with no reference: exit 1, output names SPEC_UNUSED_MODEL
PASS AC-025-05-07 clean fixture: exit 0 with a PASS line
== AC-025-06 selftest + runtime self-assertions ==
PASS AC-025-06-02 every AC-025-* scenario ID cited by the selftest or the runtime check
PASS AC-025-06-05 structural invariants held: templates shape, .envrc gitignored/untracked, purge clean, gate branches proven
PASS AC-025-06-06 AC-025-07-01 SPEC_PIPELINE.md documents the dotenv flow with no loader reference
PASS AC-025-06-06 AC-025-07-02 AGENTS.md documents the dotenv flow with no loader reference
PASS AC-025-06-06 self-ci validate job runs check-model-env, the selftest, and the runtime check
PASS AC-025-06-06 AC-025-06-10 no continue-on-error on the model-env steps — a regression must fail the job
PASS AC-025-06-07 cited by the runtime check
PASS AC-025-06-08 cited by the runtime check
PASS AC-025-06-09 cited by the runtime check
== AC-025-07 docs + ADR ==
PASS AC-025-07-01 SPEC_PIPELINE.md §Model configuration documents setup, parent/child flow, precedence, safety, boundary, enforcement
PASS AC-025-07-02 AGENTS.md describes the gitignored .envrc mechanism; model-table values unchanged
PASS AC-025-07-03 README.md §Model Configuration describes copy template, direnv allow, edit, restart
PASS AC-025-07-04 ADR 0001: status Accepted, dotenv decision, rejected alternatives (shell-profile, loader design), compliance
PASS AC-025-07-05 docs/adr/README.md lists ADR 0001 with status Accepted

selftest: 67 passed, 0 failed
✔ model-env.selftest: all cases pass.
```


--- run 2/3: bash scripts/agent-env.selftest.sh ---

```
== agent env template + gitignore ==
PASS config/agent.local.env.example exists
PASS example is tracked (or committable pre-commit: not ignored, git add stages it)
PASS every credential has a <...> placeholder with a comment directly above
PASS template enumerates exactly GITHUB_TOKEN and GH_TOKEN
PASS header documents the direnv dotenv_if_exists flow and never-commit
PASS git check-ignore config/agent.local.env exits 0 (file absent on disk)
PASS example is NOT ignored (template stays trackable)
== guard-env ==
PASS staged real file: guard --staged exits 1 and names config/agent.local.env
PASS tracked real file: guard (CI mode) exits 1 and names config/agent.local.env
PASS clean scratch repo: guard exits 0 with a PASS line in both modes
== check-no-hardcoded-secrets ==
PASS literal token prefix: exit 1, output prints the matching file
PASS secret-style assignment: exit 1, output prints the matching file
PASS placeholders and variable references are not flagged
PASS real scanned dirs (agents/ commands/ scripts/ docs/) are clean — the selftest itself trips nothing
== self-ci wiring ==
PASS self-ci validate job runs the guard, the secrets check, and the selftest
PASS no continue-on-error on the agent-env step — a regression must fail the job
== docs + agent cross-references (spec 025 dotenv flow) ==
PASS AGENTS.md documents copy -> fill -> never commit and the direnv .envrc flow
PASS AGENTS.md names the credentials and the enforcement scripts
PASS PR Opener verifies credential presence via the direnv flow and uses env vars, never literals
PASS orchestrator documents that the direnv-loaded shell already has the env loaded
PASS no literal credential value in agents/ or commands/

selftest: 21 passed, 0 failed
✔ agent-env.selftest: all cases pass.
```


--- run 3/3: bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode (pinned binary v1.18.18, per self-ci wiring) ---

```
pinned opencode binary: /tmp/opencode-bin/opencode
PASS AC-025-06-07 opencode binary runs (--version)
PASS AC-025-06-07 case 1: example loaded — all 8 agents resolve to the fixture example defaults, none empty
PASS AC-025-06-08 case 2: later dotenv line wins for spec-specifier; spec-ux keeps its pre-exported value; rest stay at defaults
PASS AC-025-06-09 case 3: nothing loaded — every agent resolves to null/empty, proving the example carries the defaults

runtime-check: 4 passed, 0 failed
✔ model-env.runtime-check: all cases pass.
```

---

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh --json   (this repo's complexity gate at `mvp` tier — KISS/CC heuristics; real linters per language)
exit: 1
at: 2026-08-19T14:48:00Z

The gate ran and produced findings (see next block, Check 3.5, for the full FAIL/WARN transcription). All findings — every one — are in `ci/templates/*` files untouched by this spec (`git status` shows no changes under `ci/`; last commit touching `ci/templates/go-saga-lint.go` is c81b75d "v1.3.0 - saga/outbox CI quality gates", predating this branch).

Proof of pre-existing baseline (same method the archived spec-007 Verifier used, docs/changes/007-verifier-discipline.md §Check 3.5):
- `git diff HEAD -- scripts/check-code-principles.sh` = 0 lines (the gate script itself is unmodified by this spec).
- HEAD-script run vs working-tree-script run: **byte-identical JSON output, both exit 1** (`diff -q /tmp/opencode/ccp-old2.json /tmp/opencode/ccp-new2.json` → identical).
- The gate's own blame-scoped mode: `bash scripts/check-code-principles.sh --json -BaseRef HEAD` → **exit 0, `"fails": [], "warns": []`** — the diff of this spec introduces zero FAILs/WARNs.

---

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh --json
exit: 1
at: 2026-08-19T14:48:00Z

Full transcript (verbatim — every FAIL and WARN line as emitted):

```json
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "property-tests"],
  "fails": [
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:CC=14", "file": "./ci/templates/go-saga-lint.go", "line": "101" },
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:CC=10", "file": "./ci/templates/go-saga-lint.go", "line": "163" },
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:CC=10", "file": "./ci/templates/go-saga-lint.go", "line": "207" },
    { "message": "Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:CC=8", "file": "./ci/templates/go-saga-lint.go", "line": "275" },
    { "message": "Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:69:getSagaStepOptions:CC=7", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "56" }
  ],
  "warns": [
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:KISS_LINES=59", "file": "./ci/templates/go-saga-lint.go", "line": "101" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:KISS_LINES=42", "file": "./ci/templates/go-saga-lint.go", "line": "163" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:KISS_LINES=38", "file": "./ci/templates/go-saga-lint.go", "line": "207" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:KISS_LINES=31", "file": "./ci/templates/go-saga-lint.go", "line": "275" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155)", "file": "./ci/templates/go-saga-lint.go", "line": "155" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "112" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "129" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156)", "file": "./ci/templates/go-saga-lint.go", "line": "156" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104)", "file": "./ci/templates/go-saga-lint.go", "line": "104" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "130" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198)", "file": "./ci/templates/go-saga-lint.go", "line": "198" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199)", "file": "./ci/templates/go-saga-lint.go", "line": "199" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197)", "file": "./ci/templates/go-saga-lint.go", "line": "197" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" },
    { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" },
    { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }
  ]
}
```

Attribution (following the documented repo precedent in docs/changes/007-verifier-discipline.md §Check 3.5, which recorded the identical 5 FAILs + 17 WARNs, proved them byte-identical to HEAD, and concluded: "Per the gate contract, these FAILs would normally stop the pipeline — but they are pre-existing … and in files this spec does not touch. They are flagged to the Architect as a separate remediation item, not a failure of spec 007."):
- All 5 FAILs and all 17 WARNs reference `ci/templates/` files. `git status --short ci/` is empty — this spec touches none of them.
- HEAD-gate-script run is byte-identical to the working-tree run (same exit 1, same JSON).
- The gate's own blame-scoped mode (`-BaseRef HEAD`) exits 0 with `"fails": [], "warns": []` — nothing this spec's diff introduces.
- **Not a verdict blocker for spec 025**; flagged to the Architect as a pre-existing remediation item (same class as the traceability baseline).

---

## Evidence: scenario-to-behavior spot check

command: bash scripts/model-env.selftest.sh (grep of AC-025-02-03 block) + bash scripts/model-env.runtime-check.sh /tmp/opencode-bin/opencode (AC-025-06-08 block) + read of agents/spec-pr-opener.md and .github/workflows/ci-sweeper.yml
exit: 0
at: 2026-08-19T14:49:00Z

Spot-checked 4 scenarios against the actual test code (not just test-name presence):

1. **AC-025-02-03 (clobber)** — `scripts/model-env.selftest.sh:322-331`. Scenario: pre-exported `SPEC_SPECIFIER_MODEL` → emulated lines → example's value wins. Test: writes fixture example, runs `snap_envrc "$PARENT_TPL" "$f0203" "SPEC_SPECIFIER_MODEL=$provider/pre-exported$RANDOM"` (pre-export passes in), asserts `snapshot_has "$snap" SPEC_SPECIFIER_MODEL "$DEFAULT_FAST"` + rc 0. Assertion matches Given/When/Then exactly. ✓
2. **AC-025-06-08 (runtime precedence)** — `scripts/model-env.runtime-check.sh:152-185`. Scenario: file override wins for spec-specifier; a var absent from all files (SPEC_UX_MODEL) keeps its pre-exported value; rest stay at defaults. Test: strips `SPEC_UX_MODEL` from the fixture example (`grep -v '^SPEC_UX_MODEL='`), writes local override, unsets all 8, pre-exports SPEC_UX_MODEL, sources example then local, resolves every agent with the **real pinned opencode binary**, wants spec-specifier=file override / spec-ux=pre-exported / others=defaults. The subtle case is faithfully asserted, including proving later-line-wins against the actual binary. ✓
3. **AC-025-03-03 (parent override never propagates)** — `scripts/model-env.selftest.sh:444-459`. Scenario: standards git index lists neither real env file; `.standards`-relative line resolves against committed example only. Test: asserts the actual standards repo index (`git ls-files` lists neither `config/model.local.env` nor `config/agent.local.env`) and that the child emulation resolves all 8 defaults with rc 0. ✓
4. **AC-025-04-04 / AC-025-04-05 (PR Opener presence check; CI sweeper dotenv-equivalent)** — `agents/spec-pr-opener.md:46-52`: "verify `$GITHUB_TOKEN` and `$GH_TOKEN` are both non-empty before the first commit or push … If either is missing, report and stop … There is no env script to source." `.github/workflows/ci-sweeper.yml:65`: `set -a; . config/model.local.env.example; set +a` replaces `source scripts/load-model-env.sh`. Both match their scenarios' Then-clauses. ✓

Result: all spot-checked tests assert what their scenarios say. No false-green found.

---

## Evidence: no unaccounted behavior (diff skim — finding lines, not a command)

Skimmed the full diff (`git diff HEAD`, 18 files, +1013/−735). Every change traces to a task:
- `.gitignore` (+.envrc line, Task 1) · `templates/.envrc.example` + `.envrc.child` (new, Tasks 1/3) · `scripts/check-model-env.sh` (Check 2 loop over both real env files, Task 5) · `scripts/model-env.vars.sh` (header note, Task 4) · `scripts/bootstrap.sh` (child .envrc + child .gitignore + child config/.gitignore + next-steps list, Task 3) · `scripts/model-env.selftest.sh` / `model-env.runtime-check.sh` / `agent-env.selftest.sh` (Tasks 2/3/5/6) · `scripts/load-env.sh` / `scripts/load-model-env.sh` (deleted, Task 4) · `agents/spec-pipeline.md` / `agents/spec-pr-opener.md` (loader purge + presence check, Task 4) · `.github/workflows/ci-sweeper.yml` (dotenv-equivalent, Task 4) · `config/*.env.example` (headers, Task 4) · `AGENTS.md` / `README.md` / `docs/SPEC_PIPELINE.md` / `docs/adr/README.md` (Task 7) · `docs/adr/0001-direnv-model-env.md` (new, Task 7).
- No logic exists that lacks a task/scenario anchor. The AGENTS.md model table is unchanged (`git diff HEAD -- AGENTS.md` adds zero lines containing a model id — grep exit 1).
- No unaccounted behavior found.

---

## User-requested supplementary checks

### Loaders truly gone / purge (check 3)
- `git ls-files --error-unmatch -- scripts/load-env.sh scripts/load-model-env.sh` → exit 1 (neither in the index); neither file exists on disk. ✓
- `grep -rn -- '--emit' scripts/ templates/ agents/ .github/ config/ README.md AGENTS.md docs/SPEC_PIPELINE.md` → zero matches. ✓
- `grep -rn -- 'load-env\|load-model-env'` over the same live surface → zero matches. ✓
- Repo-wide enumeration of every remaining loader/`--emit` reference (excluding `.git/`, `specs/`): only `docs/changes/013-agent-local-env.md`, `docs/changes/020-model-config-env.md` (historical archives — the spec's Task 4 live-surface definition excludes `docs/changes/` entirely; 020 additionally exempted by name), and `docs/adr/0001-direnv-model-env.md` (describes the replaced loader design in its Context/Alternatives — required by AC-025-07-04). ✓

### .envrc / real env files git state (check 4)
- `.envrc` on disk: absent here (was removed with the old design; the acceptance criteria hold vacuously and the selftest notes "stale-copy guard trivially satisfied").
- `git ls-files --error-unmatch -- .envrc` → exit 1 (untracked). `git check-ignore -- .envrc` → exit 0 (ignored). `.gitignore` line 32: `.envrc` (matches `^\.envrc$`). `git ls-files` filtered for `.envrc` → only `templates/.envrc.example` + `templates/.envrc.child` (both new/untracked, committable). ✓
- `config/model.local.env`, `config/agent.local.env`: `git ls-files --error-unmatch` → exit 1 for both (not tracked); `git check-ignore` → exit 0 for both (ignored); neither on disk. Examples: `git check-ignore` → exit 1 for both (committable). ✓

### ADR (check 5)
- `docs/adr/0001-direnv-model-env.md` Status: **Accepted** (line 9). Content: pure `dotenv_if_exists` (no loaders, no `--emit` — deleted), `.envrc` gitignored per-machine, committed templates as the only committed `.envrc` surface, later-lines-win precedence with accepted clobber, parent/child inheritance, rejected alternatives (shell-profile status quo; the loader-`--emit` design), consequences, compliance (check-model-env.sh, selftest, runtime-check). Matches AC-025-07-04 and the 10-tasks.md Task 7 criteria. ✓
- `docs/adr/README.md` index now lists ADR 0001 with status Accepted (AC-025-07-05). ✓

### Other gates (all executed, real exit codes)
- `bash scripts/check-model-env.sh` → exit 0, "PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env files, example wired." ✓
- `bash scripts/check-orchestration.sh` → exit 0, "All orchestration references valid." ✓
- `bash scripts/check-no-hardcoded-secrets.sh` → exit 0, "PASS check-no-hardcoded-secrets: no hardcoded credential values in agents/, commands/, scripts/, docs/." ✓
- `bash scripts/guard-env.sh` → exit 0, "PASS guard-env: no config/agent.local.env in the scanned set (tracked mode)." ✓

### Claim check: 67 / 21 / 4 assertions
Confirmed by actual runs: model-env.selftest "67 passed, 0 failed"; agent-env.selftest "21 passed, 0 failed"; model-env.runtime-check "4 passed, 0 failed". All 48 AC-025-* scenario IDs carried (48 unique cited in model-env.selftest.sh; runtime-check 3; agent-env 2; union 48, zero dangling).

---

## Review hints (WARN-level, non-blocking — flagged to the Architect)

1. `templates/.envrc.child` line 15: comment typo "the PARENT.s committed defaults" → "the PARENT's committed defaults". Comment-only, zero functional impact.
2. Pre-existing baseline findings that this gate is not responsible for but the Architect should schedule remediation on: (a) the 5 cyclomatic-complexity FAILs + 17 WARNs in `ci/templates/go-saga-lint.go` / `eslint-saga-rules/saga-compensation.js` / `archunit/*.java`; (b) the archived-spec citation FAILs of `check-scenario-traceability.sh` (AC-001…022, AC-888/998/999) — both classes predate this spec (byte-identical to HEAD, files untouched by spec 025) and are documented in docs/changes/007/008/009/015/019.

---

## Verdict

**PASS**

Every gate ran with real execution. This spec's implementation is green under every gate's own scoped judgment:

| Gate | Full-tree exit | Spec-attributable findings | Verdict for spec 025 |
|---|---|---|---|
| Scenario traceability | 1 (pre-existing baseline: archived-spec citations in `docs/changes/` + worked-example IDs, all in unmodified files; `--checks 1` alone exits 0; zero AC-025 issues in either direction; 48/48 sub-IDs cited, zero dangling) | none | PASS |
| Full test suite (selftest 67, agent-env 21, runtime-check 4 w/ pinned binary) | 0 | — | PASS |
| check-model-env.sh | 0 | — | PASS |
| check-orchestration.sh | 0 | — | PASS |
| check-no-hardcoded-secrets.sh | 0 | — | PASS |
| guard-env.sh | 0 | — | PASS |
| check-code-principles.sh (complexity + KISS/DRY/YAGNI/SOLID) | 1 (5 FAILs + 17 WARNs, all in untouched `ci/templates/*`, byte-identical to HEAD; `-BaseRef HEAD` scoped run exits 0 with `fails: [], warns: []`) | none | PASS (pre-existing baseline flagged to Architect per docs/changes/007 precedent) |

Notes for the human/Architect: both script gates' full-tree exit codes are non-zero purely from pre-existing baseline findings in files this spec does not touch — proven by the gates' own scoped modes and byte-identical HEAD comparison, and consistent with the repo's documented handling of the identical state in prior archived pipelines (spec 007/008/009/015/019). If the repo policy instead demands a globally green gate before any pipeline proceeds, that is a pre-existing condition on main, not a spec-025 defect; remediation targets `ci/templates/*` and the archived-spec citation policy.

Architect may proceed (stage 5a — Mutation Runner; at `mvp` tier it is skipped per CONFORMANCE_TIERS.md, so stage 5b — PR Opener — may proceed directly).
