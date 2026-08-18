# 25 — Verification Report (spec 018: PR Babysitter loop)

Stage 4 of the spec pipeline. Independent re-verification of the Coder/Refactorer
deliverables for spec 018. Verifier model: `opencode-go/deepseek-v4-flash`.
Date: 2026-08-18. Branch: `spec/018-pr-babysitter-loop`.

Deliverables under verification:
- `scripts/check-pr-babysitter.sh` (Task 8 — traceability shell gate)
- `skills/pr-review-triage/SKILL.md` (Tasks 1–7)
- `STATE.md` root `## PR Babysitter` section (Task 6)
- `.github/workflows/self-ci.yml` step (Task 8, AC-018-08-03)

Verdict: **PASS** (AC-018 scope). Details per gate below; the two full-repo
exit-1 results (traceability, design-principles) are pre-existing conditions
outside AC-018 scope and are transcribed verbatim for the record.

---

## 1. Scenario traceability

### 1a. Full-repo run (transcript)

Command: `scripts/check-scenario-traceability.sh --json` — **exit code 1**.

The full-repo run exits 1. Every FAIL is in sibling/in-flight specs and stale
test references — **none is an AC-018 ID**:

- Passes (11): `AC-008-01, AC-015-07, AC-018-01, AC-018-02, AC-018-03,
  AC-018-04, AC-018-05, AC-018-06, AC-018-07, AC-018-08, AC-019-07` — each
  "traced to a test". **All 8 AC-018 scenario families trace.**
- Fails: orphaned scenarios `AC-008-02..05, AC-009-01..04, AC-010-01..06,
  AC-011-01..03, AC-012-01..08, AC-013-01..06, AC-014-01..05, AC-015-01..06,
  AC-015-08..16, AC-017-01..05, AC-019-01..06` and stale test references
  `AC-001-01..06, AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04,
  AC-006-01..06, AC-007-01..04, AC-016-01..05, AC-020-01..07, AC-021-01..08,
  AC-022-01..04, AC-998-01, AC-999-01, AC-999-99`.
- **No AC-018 reference dangles.** AC-018 does not appear in the fails list at all.

These fails are attributable to other in-flight specs (008–022) and pre-existing
test files referencing scenarios not present in this repo's `specs/*/20-acceptance/`.
Not a spec-018 defect.

### 1b. Scoped AC-018 run (transcript)

To isolate spec 018 I pointed SPECS_DIR at a scratch dir holding only spec 018's
`20-acceptance/` and SOURCE_DIR at a scratch dir holding only the four spec-018
deliverables (check script, skill, STATE.md, self-ci.yml). Scratch was removed
after the run.

Command: `scripts/check-scenario-traceability.sh --json <scratch-specs> <scratch-src>`
— **exit code 0**.

```
{
  "checks": [1, 2],
  "passes": ["AC-018-01 — traced to a test", "AC-018-02 — traced to a test",
             "AC-018-03 — traced to a test", "AC-018-04 — traced to a test",
             "AC-018-05 — traced to a test", "AC-018-06 — traced to a test",
             "AC-018-07 — traced to a test", "AC-018-08 — traced to a test"],
  "fails": []
}
```

**AC-018 scope: clean.** All 8 scenario families traced; zero fails; zero stale
references.

**Check 1: PASS** (AC-018 scope).

---

## 2. Full relevant suite

The spec ships configuration/skill/state/shell-gate, not application code. The
"test suite" for this spec is `scripts/check-pr-babysitter.sh` (per task 8).
All commands below ran for real with real exit codes.

| Command | Real exit | Result |
|---|---|---|
| `./scripts/check-pr-babysitter.sh` | **0** | **72 PASS** lines, 0 FAIL |
| `bash -n scripts/check-pr-babysitter.sh` | **0** | syntax clean |
| `scripts/check-orchestration.sh` | **0** | "All orchestration references valid." |
| `make validate-all` | **0** | "All validations passed." (1 pre-existing WARN: `skills/hallmark/SKILL.md` body 562 lines — unrelated to spec 018) |
| `make lint` | **0** | all workflow files `[OK]` incl. `.github/workflows/self-ci.yml`; "Done." |
| `scripts/check-loop-files.sh` | **0** | "every check passed" (016 foundation bundle intact) |

`./scripts/check-pr-babysitter.sh` output summary (real): every AC-018 block
reported `PASS`; final line `✔ PR Babysitter check: every check passed.`; counted
PASS lines = **72**.

`scripts/check-pr-babysitter.sh` is executable (`-rwxr-xr-x`), per AC-018-08-01.

### self-ci.yml verification

PyYAML parse: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/self-ci.yml'))"`
→ printed `YAML_PARSE_OK`, jobs = `['validate']`. Parse OK.

The Validate job contains the step:
- name: `Check PR Babysitter loop deliverables`
- run: `./scripts/check-pr-babysitter.sh`
- **no `continue-on-error`** (confirmed absent; value `None`).

Only diff to `.github/workflows/self-ci.yml` is this 5-line step (no other
change). No new workflow file added (AC-018-08-03 satisfied).

### STATE.md

`STATE.md` exists at repo root and contains the `## PR Babysitter` section
(AC-018-06-01) with per-PR columns `PR | Branch | Check summary | Last action |
Outcome | Human override` and a human-override explanation paragraph.

**Check 2: PASS.**

---

## 3. Complexity gate

The check script's only functions and their decision points (real read of the
file; CC = 1 + #decision points: `if`/`for`/`&&`/`||`/`case`):

| Function | Line | Decision points | CC |
|---|---|---|---|
| `fail()` | 67 | 0 | 1 |
| `pass()` | 68 | 0 | 1 |
| `require_file()` | 75 | 1 (`if [ -f ]`) | 2 |
| `require_grep()` | 84 | 2 (`if [ -f ] && grep`) | **3** |

Worst offender is `require_grep` at **CC 3** — matches the Refactorer's claim and
is well under the ≤6 limit.

Independent confirmation via the design-principles script's complexity gate on
the spec-018 files:

```
scripts/check-code-principles.sh --json --gates complexity <scratch-src>
tier: mvp  gates: ["complexity"]  fails: []  warns: []   → exit 0
```

**Check 3: PASS.**

---

## 3.5. Design-principles gate

### Scoped spec-018 run (transcript)

Command: `scripts/check-code-principles.sh --json <scratch-src>` (default mode,
auto-detected tier `mvp`). **Exit code 0.**

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "property-tests"],
  "fails": [],
  "warns": []
}
```

No FAIL, no WARN on any spec-018 file.

### Repo-root run (known pre-existing state, transcribed verbatim)

Command: `scripts/check-code-principles.sh --json` — **exit code 1**.

FAILs (5) — all in `ci/templates/*`, none in spec-018 files:
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14`
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10`
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10`
- `Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8`
- `Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7`

WARNs — all in `ci/templates/*` (KISS_LINES and duplication in
`ci/templates/go-saga-lint.go`, `ci/templates/eslint-saga-rules/saga-compensation.js`,
empty method bodies in `ci/templates/archunit/{OutboxArchRules,SagaArchRules}.java`).

**Judgment:** every repo-root FAIL and WARN is confined to `ci/templates/*`
(the saga/outbox gate templates), pre-existing and unrelated to spec 018. No
FAIL or WARN is attributable to any spec-018 deliverable. The scoped spec-018 run
is clean (exit 0, 0 fails, 0 warns).

**Check 3.5: PASS** for AC-018 scope (repo-root exit 1 is a transcribed
pre-existing condition, not a spec-018 finding).

---

## 4. Scenario-to-behavior spot check

Picked 6 acceptance scenarios and manually confirmed the skill/STATE.md content
implements each Given/When/Then (not just that a check named the ID exists):

| Scenario | Required behavior | Found in deliverable | Verdict |
|---|---|---|---|
| **AC-018-05-01** | max 3 fix attempts; escalate + stop commenting on exhaustion | SKILL.md §Circuit breaker: "max 3 fix attempts without progress … escalates to the human … stops commenting on that PR" | ✓ |
| **AC-018-05-03** | >10 files human gate; gate.yaml denylist; no fix without human decision | SKILL.md §Human gates: "a PR touching more than 10 files. These never go to the fix sub-agent without a human decision" + `gate.yaml` denylist | ✓ |
| **AC-018-05-04** | >3 days idle → single close/hand-off suggestion, recorded, not re-pinged | SKILL.md §Idle PRs: "more than 3 days … recorded in state, and is not re-pinged on later runs" | ✓ |
| **AC-018-03-03** | loop proposes, never merges, no auto-merge | SKILL.md §Failing-check remediation: "never merges the PR; no auto-merge path exists" | ✓ |
| **AC-018-06-01** | STATE.md has `## PR Babysitter` section w/ per-PR fields + human overrides | STATE.md `## PR Babysitter` with columns PR/Branch/Check summary/Last action/Outcome/Human override | ✓ |
| **AC-018-06-03** | every comment signed exact string `Loop Engineering — PR Babysitter` | SKILL.md §Comment signing: "`Loop Engineering — PR Babysitter`" | ✓ |

### Negative fixture (script assertions reference real strings)

Injected a wrong string ("max 3 fix attempts" → "max 9 fix attempts") into a
scratch copy of `skills/pr-review-triage/SKILL.md` and re-ran the check script
against that fixture. Real output:

```
FAIL AC-018-05-01: circuit breaker: max 3 fix attempts per PR (expected "max 3 fix attempts" in .../SKILL.md)
✘ PR Babysitter check: 1 violation(s). Fix before merging.
```
→ exit code **1**. The script genuinely detects a violation; it is not a
pass-everything no-op. Fixture removed after the run.

**Check 4: PASS.**

---

## 5. No unaccounted behavior

Skim of the deliverable set against `10-tasks.md`:
- `scripts/check-pr-babysitter.sh` → Task 8 (AC-018-08). Every AC-018-NN-NN ID
  cited (self-checked by AC-018-08-02 and confirmed by the traceability scoped
  run: 8/8 families, 0 stale refs).
- `skills/pr-review-triage/SKILL.md` → Tasks 1–7 (AC-018-01..07). Content maps
  1:1 to the acceptance criteria.
- `STATE.md` `## PR Babysitter` section → Task 6 (AC-018-06-01).
- self-ci step → Task 8 / AC-018-08-03.

**Self-ci step scope check:** The Refactorer added the "Check PR Babysitter loop
deliverables" step to `.github/workflows/self-ci.yml`'s Validate job. This is
**required by Task 8** ("The script is wired into CI by adding a step to the
existing Validate job … `./scripts/check-pr-babysitter.sh`") and by
AC-018-08-03 ("The job runs `./scripts/check-pr-babysitter.sh` as a step / no new
workflow file"). It is not scope creep. It carries no `continue-on-error`, so a
missing deliverable fails the Validate job — the intended gate behavior.

No logic in the deliverables fails to trace to a task/scenario.

### mvp-tier claim

No `AGENTS_*.md` exists at the repo root (`ls AGENTS_*.md` → "No such file or
directory"). The design-principles gate auto-detected tier **`mvp`** in both
runs, confirming the property-test/mutation skips are correct for this tier.

**Check 5: PASS.**

---

## Overall verdict: **PASS**

Every gate ran for real. Spec-018 scope is clean on every check:

1. **Traceability (AC-018 scope): PASS** — scoped run exit 0, 8/8 families
   traced, 0 stale refs. (Full-repo exit 1 transcribed: fails confined to
   sibling specs 008–022 / stale test refs, none AC-018.)
2. **Full relevant suite: PASS** — check-pr-babysitter exit 0 / 72 PASS;
   bash -n 0; check-orchestration 0; make validate-all 0; make lint 0;
   check-loop-files 0; self-ci.yml parses (PyYAML) with the new step and no
   continue-on-error; STATE.md has the `## PR Babysitter` section.
3. **Complexity: PASS** — worst function `require_grep` CC 3 (≤6); complexity
   gate on spec-018 files exit 0.
3.5. **Design-principles (AC-018 scope): PASS** — scoped run exit 0, 0 FAIL /
   0 WARN. (Repo-root exit 1 transcribed: FAILs/WARNs confined to
   `ci/templates/*`, pre-existing, none attributable to spec 018.)
4. **Spot check: PASS** — 6 scenarios confirmed implemented; negative fixture
   correctly flagged the injected wrong string (exit 1).
5. **No unaccounted behavior: PASS** — all deliverables trace to tasks; self-ci
   step is task-mandated (AC-018-08-03), not scope creep; mvp tier confirmed.

Architect may proceed (mutation-testing gate skipped at `mvp` tier).
