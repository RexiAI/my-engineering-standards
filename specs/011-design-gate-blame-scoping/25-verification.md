# Verification — spec 011: Design-gate blame scoping

Stage 4 (Verifier) independent re-check of Coder/Refactorer claims.
Branch: `spec/011-design-gate-blame-scoping`. Date: 2026-08-15.
Verified against `10-tasks.md` and `20-acceptance/*.md` only (`00-informal.md` not read).

Changed files (git status): `.github/workflows/self-ci.yml`, `scripts/check-code-principles.sh`,
`skills/check-principles/SKILL.md`, untracked `scripts/tests/check-code-principles-blame.sh`.

---

## 1. Scenario traceability — PASS (AC-011 scope clean)

**Command:** `bash scripts/check-scenario-traceability.sh`
**Full-repo exit code: 1** — 128 violations, every one attributable to documented
mid-pipeline conditions, none touching AC-011:

- Sibling in-flight specs 007–010, 012–019: scenario headings defined, no tests yet
  (69 violations, direction "defined but unreferenced").
- Archived-spec citations AC-001–006, 016, 020–022: test refs whose scenario headings
  no longer exist on this branch (56 violations, direction "referenced but no heading").
- `PASS AC-011-01 — traced to a test`, `PASS AC-011-02 — traced to a test`,
  `PASS AC-011-03 — traced to a test` in the full run.

**Scoped run** (isolated SPECS tree containing only 011's `20-acceptance/` + SOURCE tree
containing only the files that reference AC-011 — the script's `grep -r` doesn't follow
symlinks, so real copies were used):

```
bash scripts/check-scenario-traceability.sh /tmp/opencode/trace-scope/specs /tmp/opencode/trace-scope/src
Scenario IDs found: 3
PASS AC-011-01 — traced to a test
PASS AC-011-02 — traced to a test
PASS AC-011-03 — traced to a test
✔ Scenario traceability check: every scenario traced, every reference resolves.
SCOPED_RC=0
```

**Sub-ID coverage:** all 23 sub-IDs (AC-011-01-01..09, AC-011-02-01..06, AC-011-03-01..08)
are individually cited in `scripts/tests/check-code-principles-blame.sh` (grep counts 3–8
occurrences each, header comments + per-case `ok`/`bad` messages).

**Judgment:** AC-011 scope is clean — no AC-011 ref dangles, all families traced. The
full-repo exit 1 is the expected mid-pipeline state, not a 011 defect.

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-code-principles.sh` | 0 | syntax OK |
| `bash -n scripts/tests/check-code-principles-blame.sh` | 0 | syntax OK |
| `bash scripts/tests/check-code-principles-blame.sh` | **0** | **24 passed, 0 failed** |
| `./scripts/check-orchestration.sh` | 0 | all references valid |
| `make validate-all` | 0 | all validations passed (1 pre-existing WARN: skills/hallmark/SKILL.md 562 lines — unrelated to 011) |
| `make lint` | 0 | JSON/YAML validation, `[OK] .github/workflows/self-ci.yml` |

Test carrier output tail (representative excerpt):

```
PASS AC-011-01-01 / AC-011-01-03 / AC-011-02-01 -BaseRef accepted; pre-existing complexity in touched file reported WARN, exit 0
PASS AC-011-01-05 edit inside the legacy method span -> diff-introduced FAIL, exit 1
PASS AC-011-02-04 / AC-011-03-02 diff-introduced DIP (judgment gate) -> WARN, no FAIL, exit 0
blame tests: 24 passed, 0 failed
check-code-principles-blame: all cases pass.
```

**self-ci.yml:** parses clean under PyYAML; the new step is present in the `validate`
job with no `continue-on-error`:

```
- name: Check design-gate blame scoping (scratch repos)
  run: bash scripts/tests/check-code-principles-blame.sh
```

(placed between `make validate-all` and `Check orchestration references`; `validate`
steps confirmed via `yaml.safe_load`.) AC-011-02-06 satisfied — a violation in any
assertion fails the job.

**Note:** shellcheck could not be installed locally (no root; apt lock denied). CI runs
`shellcheck scripts/*.sh templates/*.sh` with `continue-on-error: true` — which does not
glob `scripts/tests/*.sh`, so the new carrier is shellcheck-silent in CI; the CI
"Check shell scripts parse (bash -n)" step does cover it (`find . -name '*.sh'`). Flagged
to the Architect as a review hint, not a defect (the shellcheck step is advisory).

## 3. Complexity gate — PASS, with a documented Refactorer-claim discrepancy

No tool in this repo measures cyclomatic complexity of bash functions (the design-principles
gate audits Java/Go/JS only; shellcheck does not compute cyclomatic). Verified by mechanical
decision-point count (if/for/while/case/&&/|| per function, heredoc-polluted slices excluded),
comparing `main` vs working tree:

| Function | main | current |
|---|---|---|
| run_complexity_kiss | 4 | 4 |
| check_dry | 6 | 6 |
| check_yagni | 18 | 18 |
| check_solid_srp | 6 | 6 |
| check_solid_ocp | 8 | 8 |
| check_solid_lsp | 4 | 4 |
| check_solid_isp | 7 | 7 |
| check_solid_dip | 7 | 4 |
| check_property_tests | 2 | 1 |
| new helpers (15: blocking_raw, valid_gate, resolve_blocking_set, abs_of, is_blocking, file_touched, file_fully_added, ranges_overlap, classify_blame, classify, emit, collect_rel_paths, hunk_range, parse_diff_hunks, compute_diff) | — | all ≤6 (max: compute_diff 5, ranges_overlap 4) |

Findings vs the Refactorer's claims:
- "emit consolidated from 18 sites": measured `main` had **19** inline fail/warn routing
  sites; current has **16** through `emit` + 3 direct `fail` in property-tests (deliberate,
  AC-011-03-05 presence gate). Directionally accurate; count is 19, not 18.
- "worst offender before ~18, after ≤6": **not substantiated.** `check_yagni` is ~18 in
  *both* versions; `check_solid_ocp` 8 and `check_solid_isp` 7 are also unchanged. These
  are pre-existing functions whose complexity the refactor neither raised nor lowered, and
  the ≤6 rule is not enforced on bash by any tool in this repo. Not a spec violation —
  flag to the Architect as a self-report inaccuracy.
- "10 functions refactored": measured 8 pre-existing functions modified + 15 new helpers.
  Substance holds.
- Real reduction: check_solid_dip 7→4; single routing path (classify/emit) instead of
  inline fail/warn at 19 sites.

## 3.5. Design-principles gate — PASS (no FAIL attributable to 011)

**Command:** `bash scripts/check-code-principles.sh .` → **exit 1, 5 FAIL(s), 17 WARN(s)**.
Every FAIL line, verbatim (ANSI stripped):

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:158:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:203:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:243:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:304:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:69:getSagaStepOptions:CC=7
```

All 5 confined to `ci/templates/*` — the documented pre-existing state, in files **not
touched by this spec** (diff = self-ci.yml, check-code-principles.sh, SKILL.md,
scripts/tests/). The `main`-version script run against the same tree also yields exactly
**5 FAIL / 17 WARN** — the only output delta is the mandated method-span enrichment
(`:101` → `:101:158`). No FAIL is attributable to 011's changes.

WARN count 17 includes DRY duplication (10), KISS_LINES (4), YAGNI empty bodies (2),
KISS_LINES main (1). DIP/YAGNI single-impl: **zero FAILs** (demoted; see below).

**Demotion delta proven on a judgment-violation tree** (domain class importing infra +
single-impl interface):
- `main` version: `FAIL YAGNI ... Fruit.java`, `FAIL DIP ... Thing.java`, exit 1.
- current: both WARN, exit 0. DIP and YAGNI single-impl findings are warn-only as specified.

**Gate on the changed files themselves:** `bash scripts/check-code-principles.sh scripts`
and `... .github` → both exit 0, "No Java, Go, or JS/TS source files found" (011's changes
are bash/YAML/markdown; nothing to audit).

**mvp-tier claim:** no `AGENTS_*.md` at repo root (`ls AGENTS_*.md` → none) → tier
auto-detection defaults to `mvp` → property-test check skipped:
`Property tests: skipped (project tier is mvp — production+ required)` (×3). Correct.

## 4. Scenario-to-behavior spot checks — PASS (independent fixtures)

Picked scenarios and independently built scratch repos (different fixtures from the
carrier's), verified by direct run:

| Scenario | Observed | Result |
|---|---|---|
| AC-011-01-03 / AC-011-02-01 (pre-existing CC in touched file, touch outside span) | `WARN Cyclomatic complexity >6 (java): ./A.java:4:13:legacy:CC=7`, exit 0 in isolation | ✓ |
| AC-011-01-09 / AC-011-02-03 (brand-new file with CC violation) | `FAIL Cyclomatic complexity >6 (java): ./B.java:2:11:hot:CC=7`, exit 1 | ✓ |
| AC-011-01-08 (untouched file not evaluated) | file C.java (identical legacy violation, never touched): **0 mentions** in output, exit 0 contribution | ✓ |
| AC-011-03-02 (diff-introduced DIP) | `WARN DIP: domain/engine code imports infrastructure ... Thing.java:3`, no FAIL, exit 0 | ✓ |
| AC-011-03-03 (`--blocking complexity,property-tests,dry`) | default set: DRY WARN exit 0; with dry added: `FAIL Possible duplication ...`, exit 1; env var `PRINCIPLES_BLOCKING_GATES=...dry` → same exit 1 | ✓ |
| AC-011-03-04 (unknown/empty blocking values) | `--blocking bogus` → exit 2 "unknown gate name in blocking set: 'bogus'"; `--blocking ""` → exit 2; `PRINCIPLES_BLOCKING_GATES=bogus` → exit 2 | ✓ |
| AC-011-01-02 (unknown option) | `-Zzz` → exit 2 "Unknown option: -Zzz" | ✓ |
| AC-011-03-05 (property-tests presence gate) | production-tier Java, no jqwik: `FAIL Property tests (java)` with `-BaseRef` (exit 1) and without (exit 1) — classification unchanged | ✓ |
| AC-011-03-06 (`--warn-as-error`) | `-BaseRef <base> --warn-as-error` → exit 1 (pre-existing WARN promoted; carrier's r1 isolates this cleanly — only-WARN repo exits 1) | ✓ |

All Given/When/Then pairs match the implemented behavior, not just the test names.

## 5. No unaccounted behavior — PASS

Diff skimmed hunk by hunk. Every addition traces to a task:
- parser `-BaseRef` / `--blocking` → task 1/2; unknown `-*` → exit 2 (AC-011-01-02)
- blocking-set machinery (blocking_raw/valid_gate/resolve_blocking_set) → task 2
- git work-tree guard (non-git → exit 2) → task 1 AC (AC-011-01-07)
- awk span emitter (`end_method` now prints FNR) → task 1 AC (span overlap)
- classify/emit + 16 routing call sites → tasks 1/2
- blame helpers (compute_diff, parse_diff_hunks, ranges_overlap, classify_blame, ...) → task 1
- self-ci step + `scripts/tests/check-code-principles-blame.sh` → task 3
- SKILL.md severity table + invocation docs → tasks 1/2 (AC-011-03-01/08)

**Default-mode equivalence:** diff of `main`-version output vs current output on the repo
root shows classification, counts (5/17), and exit code identical; the only delta is the
line-span enrichment in finding text (`:101` → `:101:158`), which task 1 mandates.
Property-tests deliberately kept direct `fail` calls (presence gate, never blame-scoped —
AC-011-03-05). No stray logic found.

---

## Overall verdict: **PASS** — the Architect may proceed.

Reasons, each independently re-executed:
1. AC-011 scenarios fully traced (scoped run exit 0; full-repo exit 1 is the documented
   mid-pipeline sibling/archived-spec state, zero AC-011 involvement).
2. All suites green: bash -n, blame carrier 24/24 (exit 0), orchestration, validate-all,
   lint — real exit codes. self-ci.yml parses and runs the new no-continue-on-error step.
3. Complexity: all 15 new functions ≤6; no function worsened; DIP 7→4; emit routing
   consolidated. Refactorer's "worst offender after ≤6" claim is **not** substantiated
   (check_yagni ~18, check_solid_ocp 8, check_solid_isp 7, unchanged from main) — flagged
   to the Architect, not a spec defect.
4. Design-principles gate: 5 FAILs, all pre-existing in untouched `ci/templates/*`
   (identical to main's run); zero FAILs attributable to 011; DIP/YAGNI demotion proven
   (FAIL→WARN, exit 1→0 on a judgment-violation tree); mvp tier confirmed (no
   AGENTS_*.md → property-tests skipped).
5. Spot-checks: 9 independent scratch-repo verifications, all match the scenarios.
6. No unaccounted behavior; default-mode behavior unchanged byte-for-byte except the
   mandated span enrichment.

Review hints for the Architect (WARN-level, non-blocking): (a) Refactorer's complexity
self-report overstates the reduction; (b) CI's shellcheck step globs `scripts/*.sh` but
not `scripts/tests/`; (c) `--blocking ""` on a no-arg call is a usage error (exit 2) by
design — callers must pass a non-empty list.
