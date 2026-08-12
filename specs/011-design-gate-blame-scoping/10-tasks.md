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
