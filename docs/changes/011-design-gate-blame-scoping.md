# 011-design-gate-blame-scoping

> Spec pipeline archive. Original source: `specs/011-design-gate-blame-scoping/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# Blame scoping for design gates

The design gates judge the author for the code they wrote. Touching one line of
a legacy class must never block delivery on debt someone else introduced —
otherwise the gate gets switched off, which is worse than not having it.

Update check-code-principles.sh to accept a `-BaseRef <ref>` (like acdc-civ's
design-checker) and, for every finding, classify it:
- **introduced by this change** (the finding's line range overlaps the diff) → FAIL (blocking)
- **pre-existing in a touched file** → WARN (non-blocking, still reported)

Rules:
- Complexity/size (D1): only diff-introduced violations block.
- Naming (D6), test-delta (D10): always blocking (they're objective).
- All judgment checks (SRP, ISP, DIP, DRY, YAGNI, dead code, KISS composite):
  warn only.

## Acceptance criteria

- AC-001: check-code-principles.sh accepts `-BaseRef` and applies blame scoping.
- AC-002: a scratch repo where a pre-existing bad class is touched by one line
  exits 0 (WARN not FAIL); a diff-introduced violation exits 1.
- AC-003: only objective checks block; the blocking set is configurable and
  documented in the script header and design-gates defaults.

## Tasks

# Tasks — Blame scoping for design gates

Formalization of `specs/011-design-gate-blame-scoping/00-informal.md`. Goal: the
design-principles gate (`scripts/check-code-principles.sh`) stops judging the
author for debt they did not write. Add a `-BaseRef <ref>` flag: a finding FAILs
(blocks) only when it is **diff-introduced** — its line range overlaps the diff
against `<ref>` — and its gate is in the **blocking set**; pre-existing debt in a
touched file is a non-blocking WARN, still reported; judgment checks are
warn-only by default.

## Grounded reality (verified against this repo)

- **The gate's FAIL vs WARN mapping is fixed today, and three gate categories
  currently FAIL.** `scripts/check-code-principles.sh` runs five gate categories:
  Complexity/KISS (`run_complexity_kiss`, lines 214-229), DRY (`check_dry`,
  232-266), YAGNI (`check_yagni`, 269-326), SOLID (SRP 329-348, OCP 350-375,
  LSP 377-394, ISP 396-415, DIP 417-453), Property-tests (`check_property_tests`,
  456-495). Current severity: cyclomatic CC>6 is FAIL (224); KISS_LINES /
  KISS_PARAMS are WARN (225-226); DRY duplication is WARN (260); YAGNI
  single-implementation interface is FAIL (284, 303, 318) and empty method body
  is WARN (289); SRP/OCP/LSP/ISP are WARN (343, 365/370, 389, 410); DIP is FAIL
  (426, 436, 446); Property-tests missing framework is FAIL at `production`+
  tier (469, 479, 490).
- **Informal "objective vs judgment" split, mapped onto the real gate names:**
  the objective set *in this repo's terms* is the **Complexity/KISS** gate
  (complexity + size findings — the informal's D1 "complexity/size") plus the
  **Property-tests** presence gate. The judgment set is **DRY, YAGNI, SOLID**
  (all five sub-checks). The informal's "naming (D6)" and "test-delta (D10)"
  categories have **no gate in this script** and are **not invented** here (see
  open question 2); "dead code" and "KISS composite" are likewise not separate
  findings — the script's KISS_LINES/KISS_PARAMS *are* the "size" half of D1 and
  stay objective.
- **The informal demotes DIP and YAGNI single-impl from FAIL to WARN.** Both are
  in the informal's judgment list and both FAIL today. This is the largest
  behavioral change to the existing gate — DIP is a hard architectural rule in
  `docs/ARCHITECTURE.md` (dependency rule) and `AGENTS.md` treats a FAIL as a
  defect. See open question 1.
- **Findings are not all line-anchored, and blame scoping needs a line range.**
  CC/KISS findings carry only the method *start* line (awk `STACK[top,"l"]`,
  emitted at 176-181); DRY carries the window start (FNR-3, line 250); YAGNI
  single-impl, SRP, LSP, and DIP report the file with **no line** (284, 343,
  389, 426/436/446); Property-tests is a whole-repo presence check with no line
  at all. Task 1 must give every finding a line or line range. CC/KISS in
  particular need the method *span* (start..end) so overlap is tested against
  the whole method, not just its first line — `end_method` (174) already runs
  with the closing line's FNR, so the awk can emit it. Property-tests stays
  unanchored and therefore outside blame scoping.
- **Flag style and exit-code contract.** The script uses double-dash kebab flags
  (`--tier`, `--warn-as-error`; parser at 67-76); any other `-*` is "Unknown
  option" → exit 2 (73). Exit codes: 0 = no FAILs, 1 = ≥1 FAIL (or a WARN with
  `--warn-as-error`), 2 = usage/tooling failure (52, 536-550). The informal
  demands the literal single-dash `-BaseRef <ref>` spelling "like acdc-civ's
  design-checker"; that spelling is kept as specified (open question 3).
- **The script is not wired into CI.** It is invoked by the spec pipeline's
  Verifier (check 3.5, `agents/spec-verifier.md:57-66`) and the `check-principles`
  skill. `.github/workflows/self-ci.yml` runs `make validate-all`, `make lint`,
  and shellcheck only — so AC-002's scratch-repo behavior needs new test wiring
  (task 3).
- **Sibling specs touch the same files and must coordinate.** `007-verifier-discipline`
  (informal AC-003) adds `--gates`/`--json` and a hardened exit-2 contract to
  this same script; `012-gate-selftests-telemetry` (informal AC-002) proposes a
  `check-code-principles.selftest.sh` wired into self-ci **and a `-BaseRef` flag
  "for telemetry output"** — a flag-name collision with different meanings if
  both land as written (open question 4); `008-remediation-budget` edits
  `agents/spec-verifier.md`. 011 must not assume `--gates`/`--json` exist: they
  are not in the script today.

## Tasks

### Task 1 — Add `-BaseRef <ref>` and blame-scoped classification

Extend `scripts/check-code-principles.sh` so that when a base ref is given, every
line-anchored finding is classified as diff-introduced (overlaps the diff) or
pre-existing, and only diff-introduced findings in the blocking set FAIL.

Acceptance criteria:
- The parser (67-76) accepts `-BaseRef <ref>` with the literal single-dash
  spelling and a value (the git ref to diff against). Any other `-*` still exits
  2 with the existing "Unknown option" behavior.
- When `-BaseRef` is set, the script computes the diff of the working tree
  against `<ref>` scoped to the source files it audits (e.g.
  `git diff --unified=0 <ref> -- <files>`), parses the `@@` hunks, and records
  the added-line (`+`) ranges per touched file.
- Only touched files (present in the diff) are evaluated. A finding in a file
  with no diff overlap is not reported — the gate judges the author's change,
  not the whole tree (open question 5).
- Classification for a finding whose gate is in the blocking set (default set
  defined in task 2): if its line range overlaps an added-line range for that
  file → **FAIL**; otherwise (pre-existing debt in a touched file) → **WARN**,
  still reported.
- CC/KISS findings carry the method's **span** (start..end line), not just the
  start line, so overlap is tested against the whole method. The awk emitter
  (176-181) is extended to output the end line; `end_method` (174) already has
  it. Other findings carry a line anchor where they currently have none
  (interface declaration line for YAGNI single-impl, import line for DIP).
- File-level findings (e.g. a god-file SRP finding if SRP is ever added to the
  blocking set) treat "overlap" as "the file is touched": any added line in the
  file counts.
- A file fully added by the diff is entirely diff-introduced: every finding in
  it is a FAIL if its gate is in the blocking set.
- Without `-BaseRef`, behavior is byte-for-byte the current behavior (all gates,
  legacy severities — including, until task 2's severity change lands, DIP and
  YAGNI as FAILs).
- Usage/tooling failures: an unresolvable `<ref>`, or running outside a git
  repository, writes an error to stderr and exits 2 — never a false PASS.
- Exit-code contract preserved: 0 = no FAILs, 1 = ≥1 FAIL (or WARN with
  `--warn-as-error`), 2 = usage/tooling failure.
- `-BaseRef` is documented in the script's header usage block (lines 36-51) and
  in `skills/check-principles/SKILL.md` (invocation section, lines 17-30).

Scenarios: `20-acceptance/AC-011-01-base-ref-blame-scoping.md`

### Task 2 — Objective/judgment severity split with a configurable blocking set

Define the blocking set (which gates may emit FAIL) and make it configurable, so
"only objective checks block" is the default and judgment checks are warn-only.
This task changes the script's default severity mapping and is the biggest
behavioral change in this spec.

Acceptance criteria:
- The script defines a **blocking set** over its five gate names — `complexity`
  (CC + KISS size findings), `dry`, `yagni`, `solid` (all SOLID sub-checks as a
  unit), `property-tests` — matching the vocabulary spec 007 proposes for its
  `--gates` flag. **Default: `complexity,property-tests`** (the objective gates
  in this repo's terms).
- A gate not in the blocking set is warn-only: it never emits FAIL, regardless
  of blame or `-BaseRef`. Consequence, stated explicitly in the header: **DIP
  and YAGNI single-impl findings drop from FAIL to WARN** (open question 1).
- Within the blocking set, line-anchored gates are blame-scoped when `-BaseRef`
  is present (task 1's classification). `property-tests` is a presence check
  with no line anchor: it is **never blame-scoped** and keeps its current
  behavior (FAIL at `production`+ tier) whether or not `-BaseRef` is given.
- The blocking set is configurable via a `--blocking <comma-list>` flag and a
  `PRINCIPLES_BLOCKING_GATES` env-var fallback; a value overrides the default.
  An unknown gate name or an empty value → message to stderr, exit 2.
- The default blocking set and the configuration mechanism are documented in the
  script header (a "Blocking set" block in the usage comment) and in
  `skills/check-principles/SKILL.md` (open question 6 covers what "design-gates
  defaults" means — no such config file exists in this repo).
- `--warn-as-error` is unchanged and still promotes every WARN — including the
  newly-warned pre-existing and judgment findings — to a failure.
- No `naming` or `test-delta` gates are added: the informal's D6/D10 do not
  exist in this script and are not invented (open question 2).
- The summary line (536-550) continues to report FAIL/WARN counts and the exit
  contract is unchanged.

Scenarios: `20-acceptance/AC-011-03-configurable-blocking-set.md`

### Task 3 — Scratch-repo blame-scoping tests wired into self-ci

Prove AC-002's observable behavior with real tests: a scratch git repo with a
pre-existing bad class touched by one line exits 0 (WARN, not FAIL); a
diff-introduced violation exits 1.

Acceptance criteria:
- A test script (e.g. `scripts/tests/check-code-principles-blame.sh`) creates
  throwaway scratch git repos (base commit containing a legacy violation, then a
  one-line touch; or a clean base and a diff-introduced violation), runs
  `scripts/check-code-principles.sh -BaseRef <base>`, and asserts the exit code
  and severity.
- The script asserts at least: (a) pre-existing bad class touched by one line →
  exit 0, finding reported as WARN not FAIL; (b) diff-introduced complexity
  violation → exit 1, FAIL reported; (c) a violation in a brand-new file added
  by the change → exit 1; (d) a diff-introduced judgment-gate finding (e.g.
  SOLID/DIP or DRY) → WARN, exit 0 under the default blocking set; (e) legacy
  invocation without `-BaseRef` keeps the pre-011 behavior.
- Every test asserts the AC-011-02 scenario IDs (per `docs/SPEC_PIPELINE.md` the
  traceability gate requires scenario IDs cited by real tests).
- The test script is wired into `.github/workflows/self-ci.yml` (a job/step, or
  a `make validate-blame` target invoked there).
- No production-code changes beyond `scripts/check-code-principles.sh` (and the
  skill / self-ci docs). The scratch repos are cleaned up on exit (trap), and
  the tests run entirely under the repo's existing tooling (bash, git, awk).

Scenarios: `20-acceptance/AC-011-02-scratch-repo-blame-behavior.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 script accepts `-BaseRef` and applies blame scoping | 1 | `AC-011-01-base-ref-blame-scoping.md` |
| AC-002 scratch repo: pre-existing touch exits 0, diff-introduced exits 1 | 3 | `AC-011-02-scratch-repo-blame-behavior.md` |
| AC-003 only objective checks block; blocking set configurable + documented | 1 (mechanism), 2 (severity + docs) | `AC-011-01-base-ref-blame-scoping.md`, `AC-011-03-configurable-blocking-set.md` |

## Open questions (need a human answer before /build)

1. **DIP and YAGNI demotion is the largest behavioral change.** The informal
   lists DIP, YAGNI, DRY, SRP, ISP (and "dead code", "KISS composite") under
   judgment checks → warn only. Today DIP (426/436/446) and YAGNI
   single-implementation-interface (284/303/318) are FAILs, and DIP is a hard
   architectural rule (`docs/ARCHITECTURE.md` dependency rule; `AGENTS.md`: "a
   FAIL is a defect"). Task 2 follows the informal literally: both demote to
   WARN. If they should keep blocking in a full-tree audit, the default blocking
   set must include `dip`/`yagni` and "only objective checks block" is then not
   literally true. My recommendation: follow the informal (warn-only) — the
   point of the spec is that the gate must not block delivery on judgment calls;
   DIP enforcement remains with review and the real linters. Confirm.
2. **Naming (D6) and test-delta (D10) do not exist in this script.** The
   informal says they are "always blocking (they're objective)" — a reference to
   acdc-civ's gate taxonomy. This repo's `check-code-principles.sh` has no such
   gates, and this spec does not invent them (task 2). Confirm the objective
   blocking set is `complexity,property-tests` only; if D6/D10-like gates are
   wanted they are a separate spec.
3. **Flag spelling.** The informal demands literal `-BaseRef` (single dash,
   acdc-civ style); the script's own flags are double-dash kebab (`--tier`,
   `--warn-as-error`). Kept as specified. Prefer `--base-ref` for consistency
   instead? Confirm.
4. **Flag collision with spec 012.** `012-gate-selftests-telemetry`
   (`00-informal.md` AC-002) also names `-BaseRef` — "for telemetry output".
   011 needs `-BaseRef <ref>` as the git diff base. If both land as written, one
   flag means two things. Resolve before /build: 012 renames its flag (e.g.
   `-ReportPath` alone), 011 renames to `--base-ref`, or the specs merge/land in
   a batch with a shared flag surface.
5. **Untouched files.** Task 1 evaluates only files present in the diff; debt in
   a *touched* file outside the diff's lines is a reported WARN; debt in a file
   the change never touches is not reported. Alternative: run the full tree and
   warn on everything outside the diff. My recommendation: suppress untouched
   files — the gate judges the author's change, and printing unrelated repo-wide
   WARNs on every PR is noise. Confirm.
6. **"Design-gates defaults" (AC-003).** No `design-gates` config file exists in
   this repo; the script's defaults live in its header. Task 2 documents the
   default blocking set in the header and the skill. If the informal means a
   child-repo override file (like acdc-civ's design-gates config), say so and it
   becomes a fourth task; otherwise the header default + `PRINCIPLES_BLOCKING_GATES`
   env var is the whole story.
7. **Verifier wiring is out of scope here.** This spec changes the script only;
   `agents/spec-verifier.md` (check 3.5) is not changed to pass `-BaseRef` on
   re-checks — 007/008 already edit that file. Confirm that's acceptable, or
   make the verifier invocation a follow-up.

## Acceptance scenarios

## AC-011-01-01 — The script accepts the literal `-BaseRef <ref>` flag (AC-001)
## AC-011-01-02 — An unknown `-*` option still exits 2
## AC-011-01-03 — A pre-existing finding in a touched file is WARN, not FAIL (AC-001)
## AC-011-01-04 — A diff-introduced finding is FAIL (AC-001)
## AC-011-01-05 — Complexity overlap is tested against the whole method span
## AC-011-01-06 — Without `-BaseRef` behavior is unchanged (AC-001)
## AC-011-01-07 — Unresolvable base ref or non-git tree is a tooling failure, never a false PASS
## AC-011-01-08 — Files with no diff overlap are not evaluated (AC-001)
## AC-011-01-09 — A file added entirely by the diff is fully diff-introduced (AC-001)
## AC-011-02-01 — Pre-existing bad class touched by one line exits 0 (AC-002)
## AC-011-02-02 — A diff-introduced violation exits 1 (AC-002)
## AC-011-02-03 — A violation in a new file added by the change exits 1
## AC-011-02-04 — A diff-introduced judgment-gate finding stays WARN
## AC-011-02-05 — Legacy invocation without `-BaseRef` keeps pre-011 behavior
## AC-011-02-06 — Blame-scoping tests run in self-ci (AC-002)
## AC-011-03-01 — The default blocking set is documented in the script header (AC-003)
## AC-011-03-02 — Judgment gates are warn-only even when diff-introduced (AC-003)
## AC-011-03-03 — The blocking set is configurable (AC-003)
## AC-011-03-04 — An unknown gate name in the blocking-set override is a usage error
## AC-011-03-05 — `property-tests` is a presence gate and is not blame-scoped (AC-003)
## AC-011-03-06 — `--warn-as-error` still promotes the new WARNs to failures
## AC-011-03-07 — No naming or test-delta gates are added (AC-003)
## AC-011-03-08 — The blocking set and severity mapping are documented in the skill (AC-003)

## Verification

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

## Quality gates

# Mutation & Gate Report — spec 011: Design-gate blame scoping

Stage 5a (Mutation Runner). Branch: `spec/011-design-gate-blame-scoping`. Date: 2026-08-15.

## Verifier's verdict (carried forward)

**PASS** — `specs/011-design-gate-blame-scoping/25-verification.md` exists, verdict
`PASS — the Architect may proceed`. All AC-011 scenarios traced (scoped run exit 0),
full relevant suite green, complexity gate clean for new code, design-principles gate
shows zero FAILs attributable to 011, 9 independent scenario spot-checks passed.

## Mutation score

**skipped — `mvp` tier.**

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier
gate; this repo is `mvp` tier (no `AGENTS_<PROJECT>.md` at repo root; archived specs
020/021/022 confirm). Changed code is bash scripts + markdown; no mutation tooling for
shell exists in this repo. No mutation run attempted, no mutants generated.

## Complexity summary (carried from the Refactorer, per Verifier re-measurement)

- 15 new bash helper functions, all ≤6 decision points (max: `compute_diff` 5,
  `ranges_overlap` 4): `blocking_raw`, `valid_gate`, `resolve_blocking_set`, `abs_of`,
  `is_blocking`, `file_touched`, `file_fully_added`, `ranges_overlap`, `classify_blame`,
  `classify`, `emit`, `collect_rel_paths`, `hunk_range`, `parse_diff_hunks`, `compute_diff`.
- Real reduction: `check_solid_dip` 7→4; single routing path (`classify`/`emit`) replaces
  inline fail/warn at 19 sites (now 16 through `emit` + 3 deliberate direct `fail` in
  property-tests — the AC-011-03-05 presence gate, never blame-scoped).
- **Pre-existing, unchanged from `main`, out of scope for 011:** `check_yagni` ~18,
  `check_solid_ocp` 8, `check_solid_isp` 7. The Refactorer's "worst offender after ≤6"
  claim is not substantiated for these functions; the ≤6 rule is not enforced on bash by
  any tool in this repo. Carried forward as the Verifier's review hint (a) for the
  Architect — not a spec defect.

## Equivalent mutants

**None.** Mutation testing not run (`mvp` tier), so no mutants were generated and none
survived.

## Final test status

Re-confirmed after Verifier's PASS (new carrier test code covered by this run):

| Check | Exit | Result |
|---|---|---|
| `bash -n scripts/check-code-principles.sh` | 0 | syntax OK |
| `bash -n scripts/tests/check-code-principles-blame.sh` | 0 | syntax OK |
| `bash scripts/tests/check-code-principles-blame.sh` | 0 | **24 passed, 0 failed** (all AC-011-01/02/03 families) |
| `bash scripts/check-orchestration.sh` | 0 | all references valid |
| `make validate-all` | 0 | all validations passed (1 pre-existing WARN: `skills/hallmark/SKILL.md` 562 lines — unrelated to 011) |

Full suite green. `25-verification.md` present with PASS.

## Gates for the Architect (carried review hints, non-blocking)

- (a) Refactorer's complexity self-report overstates the reduction (`check_yagni`/`ocp`/`isp` unchanged from main).
- (b) CI's shellcheck step globs `scripts/*.sh`, not `scripts/tests/` — the new carrier is shellcheck-silent in CI (bash -n still covers it).
- (c) `--blocking ""` on a no-arg call is exit 2 by design — callers must pass a non-empty list.

No commit, push, or PR performed — that is the PR Opener's job (stage 5b).
