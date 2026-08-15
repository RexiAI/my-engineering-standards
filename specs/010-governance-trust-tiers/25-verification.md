# Verification — spec 010 (governance-trust-tiers)

Verifier: stage 4, `agents/spec-verifier.md` discipline. Every check below was
re-executed for real; nothing is taken from Coder/Refactorer reports. Work is
uncommitted working-tree state on `main` (merge-base 3013d8d = HEAD):
`M AGENTS.md`, `?? docs/GOVERNANCE.md`, `?? docs/adr/`, `?? scripts/check-governance.sh`.
`00-informal.md` was not read at any point.

## 1. Scenario traceability — PASS (AC-010 scope clean; full-repo exit 1 known)

Command: `bash scripts/check-scenario-traceability.sh` → **exit 1**, 125 violations.

Full-repo failures are entirely the known mid-pipeline condition, none touching
AC-010:
- "defined but no test references it": AC-007-01..04, AC-008-01..05, AC-009-01..04,
  AC-011-01..02, AC-012-01..08, AC-013-01..06, AC-014-01..05, AC-015-01..16,
  AC-017-01..05, AC-018-01..08, AC-019-01..07 (sibling in-flight specs with no
  check script yet).
- "referenced in a test but no matching scenario heading": AC-001-01..06,
  AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04, AC-006-01..06,
  AC-016-01..05, AC-020-01..07, AC-021-01..08, AC-022-01..04 (archived/merged
  specs whose test-carriers persist in scripts but whose spec dirs are gone).

Scoped AC-010 result: **all six groups PASS** —
`PASS AC-010-01 .. AC-010-06 — traced to a test`, and **zero AC-010 FAIL lines**
in either direction. Additionally verified mechanically that every one of the 37
sub-IDs defined in `20-acceptance/` (AC-010-01-01 … AC-010-06-08) appears in
`scripts/check-governance.sh`'s output:

```
$ grep -ohE 'AC-010-[0-9]{2}-[0-9]{2}' specs/010-governance-trust-tiers/20-acceptance/*.md | sort -u | wc -l
37
$ scripts/check-governance.sh 2>/dev/null | grep -oE 'AC-010-[0-9]{2}-[0-9]{2}' | sort -u > /tmp/…; diff ids script → (empty)
ALL_37_SUBIDS_CITED_IN_SCRIPT_OUTPUT
```

Judgment: AC-010 scope is clean. The 37 sub-IDs are all defined **and** all cited;
the full-repo exit 1 is fully explained by sibling/archived specs and is not a
spec-010 defect.

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/check-governance.sh` | 0 | `SYNTAX_OK` |
| `scripts/check-governance.sh` (compliant repo) | 0 | 37 PASS lines + `✔ Governance check: every governance requirement verified.` |
| `scripts/check-governance.sh` × 5 negative fixtures (see §4) | 1 each | each FAILs naming the exact missing artifact |
| `scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `make validate-all` | 0 | `All validations passed.` (1 pre-existing WARN: skills/hallmark/SKILL.md body 562 lines >500 — unrelated to spec 010) |
| `make lint` | 0 | all JSON/YAML `[OK]`, `Done.` |

Representative compliant-run output (the script's full output is 37 PASS lines;
excerpt):

```
PASS AC-010-01-01 — docs/GOVERNANCE.md exists
PASS AC-010-01-02 — exactly the three required headings present, no other top-level ## heading
PASS AC-010-02-06 — T3 stated as universal: applies to every agent with no exceptions
PASS AC-010-03-02 — spec-verifier mapped to T0
PASS AC-010-03-03 — spec-pr-opener mapped to T2
PASS AC-010-04-06 — conformance note ties the same-commit rule to the observed spec-architect drift (governance defect)
PASS AC-010-05-05 — docs/adr/README.md exists, indexes one ADR per file, and references templates/ADR.md (AC-010-06-07 failure mode)
PASS AC-010-06-01 — scripts/check-governance.sh exists and is executable
PASS AC-010-06-02 — compliant repo passes all checks (exit 0)
```

Executable bit set (`-rwxr-xr-x` 755) — AC-010-06-01 satisfied. Script is
read-only: grep for `rm|mv|cp|>>|> ` finds only comment lines; no file is
modified by any run.

## 3. Complexity gate — PASS (all functions ≤6; some Refactorer numbers don't reproduce)

No shell complexity linter exists in this repo; measured with the standards'
own heuristic (`scripts/check-code-principles.sh` header: counts
if/for/while/case/&&/||/ternary per function), via awk over the script:

```
extract_section        CC=2
check_section          CC=2     (Refactorer claimed 2 — matches)
expect                 CC=6     (claimed 6 "by design" — matches; at the ≤6 limit)
expect_row             CC=5     (claimed 2 — does NOT reproduce)
check_failure_mode     CC=1     (claimed 2 — does NOT reproduce)
```

Every function is ≤6, so the cyclomatic-complexity rule holds — no gate
violation. Discrepancies recorded as self-report inaccuracy only:
- `expect_row` measured CC 5 (two `&&`/`||` guard expressions), not 2.
- `check_failure_mode` measured CC 1, not 2.
- Line count: `wc -l` = **416**, not the claimed 412 (445→412).
- "Top-level decisions ~25→~13": current top-level if/for decision statements
  measure **26**; the delta claim is unverifiable because the script is
  untracked (no pre-refactor version in git history).

None of these affect the actual gate outcome; flagging so the Architect does not
propagate the stale numbers into `30-report.md`.

## 3.5. Design-principles gate — PASS for spec 010 (pre-existing FAILs confined to ci/templates/*)

Command: `scripts/check-code-principles.sh` (default mode, repo root) → **exit 1**,
`5 FAIL(s), 17 WARN(s)`. Tier auto-detected: `Checking design principles in: . (tier: mvp)`.

Every FAIL and WARN line, verbatim:

FAILs:
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARNs (17):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
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
```

Judgment: all 5 FAILs and all 17 WARNs reference files under `ci/templates/*`
(go-saga-lint.go, eslint-saga-rules/saga-compensation.js, archunit/*.java) — a
directory spec 010 does not touch (git status/diff confirm). **No FAIL or WARN is
attributable to spec 010.** The pre-existing exit-1 state is unchanged from
baseline. WARNs are review hints; flagged to the Architect, no pipeline stop
(per project instructions, a WARN alone does not stop unless it concerns the
changed files — none do).

## 4. Scenario-to-behavior spot check — PASS

Two scenarios checked by hand against the real artifacts, plus a live negative
fixture run.

**AC-010-02-07 (sole remote-write carve-out)** — scenario asserts: names
`spec-pr-opener` as the only push-capable agent; carve-out limited to
`spec/NNN-slug`; draft PR only after every configured quality gate is green.
`docs/GOVERNANCE.md:30-33` reads: "`spec-pr-opener` is the only push-capable
agent: it may push to a branch named `spec/NNN-slug` and open a **draft** PR,
only after every configured quality gate is green, per
`docs/SPEC_PIPELINE.md §Commit and push carve-out`." — matches on all three
assertions.

**AC-010-04-06 (conformance note)** — scenario asserts: explicit conformance
note; violating the same-commit rule is a governance defect; names the observed
`spec-architect` drift. `docs/GOVERNANCE.md:74-77` reads: "**Conformance note:**
violating the same-commit rule is a governance defect — a review blocker, same
class as the ADR rule. The drift observed in this repo (a model entry pointing
at a nonexistent agent, `spec-architect`) is exactly what this rule exists to
prevent." — matches.

Additional confirmation of the same kind: AC-010-03-06 (`spec-pipeline` gap row
records "no `permission` block at all", not papered over — GOVERNANCE.md:49),
AC-010-05-05/06 (ADR index exists, references `templates/ADR.md`, states "No
ADRs are recorded yet" — `docs/adr/README.md`), and the exact T0-T3 capability
rows from AC-010-02-02..05 (GOVERNANCE.md:19-22, byte-identical to Task 2's
table).

**Negative fixture (the check script really detects violations).** Built scratch
trees under /tmp/opencode (deleted after), ran the script against each with a
`ROOT` argument:

| Fixture | Broken state | Exit | FAIL line naming the artifact |
|---|---|---|---|
| f1 | no `docs/GOVERNANCE.md` (AC-010-06-03) | 1 | `FAIL AC-010-01-01 — docs/GOVERNANCE.md is missing (AC-010-06-03 failure mode)` |
| f2 | `## Trust Tiers` heading removed (AC-010-06-04) | 1 | `FAIL AC-010-01-02 — docs/GOVERNANCE.md is missing the '## Trust Tiers' heading (AC-010-06-04 failure mode)` |
| f3 | `spec-verifier` row removed from mapping (AC-010-06-05) | 1 | `FAIL AC-010-03-01 — mapping table omits agent \`spec-verifier\`` + `FAIL AC-010-03-02 — spec-verifier row missing or not mapped to T0` |
| f4 | authoritative-source statement removed (AC-010-06-06) | 1 | `FAIL AC-010-04-02 — section must name opencode.json (agent.<name>.model) as the single authoritative model source (AC-010-06-06 failure mode)` |
| f5 | no `docs/adr/README.md` (AC-010-06-07) | 1 | `FAIL AC-010-05-05 — docs/adr/README.md is missing (AC-010-06-07 failure mode)` |

Each fixture exits 1 and names the exact artifact the corresponding scenario
requires. The failure-mode mirror checks (AC-010-06-03..07) correctly FAIL in
the broken fixtures and PASS on the compliant repo — the mirroring logic is
genuine, not a hardcoded pass.

**Mapping-table basis vs real frontmatter.** All 8 rows of the agent mapping
(GOVERNANCE.md:42-49) were checked against `agents/*.md` frontmatter:
- spec-coder: read denies only `specs/*/00-informal.md`; `git push*: deny`, rest allow ✓
- spec-mutation-runner: `git commit*`/`git push*` denied ✓
- spec-pr-opener: read denies 00-informal.md + docs/changes/*.md; `git push*: ask` ✓
- spec-refactorer: read denies `specs/**`; `git push*: deny` ✓
- spec-specifier: edit `specs/**` allow, `*` deny; `git *: allow` ✓
- spec-ux: read `*` allow; `git commit*`/`git push*` ask ✓
- spec-verifier: edit only `specs/*/25-verification.md`; `git commit*`/`git push*` denied ✓
- spec-pipeline: **no `permission` block in the file at all** — the recorded gap is real ✓

## 5. No unaccounted behavior — PASS

The entire change set is four paths: `M AGENTS.md` (+1 line),
`docs/GOVERNANCE.md`, `docs/adr/README.md`, `scripts/check-governance.sh`.

- The `AGENTS.md` line adds `docs/GOVERNANCE.md` to the "Reading the Standards"
  list. This is exactly open question 7 in `10-tasks.md` ("Optionally add
  docs/GOVERNANCE.md to the AGENTS.md 'Reading the Standards' list. Not required
  by any AC; include only if you want") — sanctioned by the tasks doc, and it
  also satisfies the governance/operations-split intent (the doc is discoverable
  from the standards index). It breaks nothing: `check-orchestration.sh` (which
  validates `docs/` references in agents/commands/AGENTS.md) exits 0.
- `docs/GOVERNANCE.md` → Tasks 1-5; `docs/adr/README.md` → Task 5;
  `scripts/check-governance.sh` → Task 6. No other logic exists in the diff.
- The script is not vacuous: §4 proves five distinct broken states each produce
  a named FAIL and exit 1; its PASS lines are gated on real greps of real files
  (`expect()`/`expect_row()`/`check_section()` all read the target file at run
  time), and the AC-010-06-08 "all IDs cited" claim was verified mechanically
  (37/37). If a scenario were renamed in `20-acceptance/` without the script
  being updated, the traceability script's defined-but-untraced direction would
  catch the stale ID.

## mvp-tier claim (property-test / mutation skips) — CONFIRMED

- `find . -maxdepth 1 -name 'AGENTS_*.md'` → **0 files**. The conformance-tier
  auto-detection in `scripts/check-code-principles.sh` (grep of `AGENTS_*.md`
  for `Conformance tier:`) therefore resolves to the `mvp` default, confirmed in
  the gate run output: `(tier: mvp)`.
- Property tests: skipped at mvp — verified live: `Property tests: skipped
  (project tier is mvp — production+ required)` ×3.
- Mutation testing: skipped at mvp per `docs/SPEC_PIPELINE.md` conformance-tier
  table (Architect row: mutation `skip` for mvp). Consistent with the skips the
  prior stages assumed.

## Verdict

**PASS** — Architect may proceed.

Reasons, all verified by execution:
1. AC-010 scenario traceability clean (37/37 sub-IDs defined and cited; zero
   AC-010 failures; full-repo exit 1 fully explained by sibling/archived specs).
2. check-governance.sh: syntax-clean, exit 0 on the compliant repo, exit 1 with
   the correct named artifact on all five negative fixtures, executable, read-only.
3. check-orchestration.sh 0, make validate-all 0, make lint 0.
4. Complexity: every function ≤6 (expect=6 at limit by design; others 1-5);
   measured discrepancies in the Refactorer's reported numbers (expect_row 5 not
   2, check_failure_mode 1 not 2, 416 lines not 412, top-level decisions 26 with
   the 25→13 delta unverifiable) are noted for the Architect but do not violate
   the gate.
5. Design-principles gate exit 1 is entirely pre-existing `ci/templates/*`
   findings; nothing attributable to spec 010. WARNs flagged, not blocking.
6. Spot-checked scenarios' Given/When/Then match the real document content, and
   the mapping table's frontmatter-basis claims match the real agent files.
7. No unaccounted behavior; the one extra diff hunk (AGENTS.md cross-reference)
   is explicitly sanctioned by 10-tasks.md open question 7.
8. mvp tier confirmed (no AGENTS_*.md), so the property-test and mutation
   skips are correct.
