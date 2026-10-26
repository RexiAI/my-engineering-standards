# Verification — spec 035 autopilot mode

- **Attempt:** 1, phase 1 (full verification, first run)
- **Branch:** `spec/035-autopilot-mode`
- **Base ref:** `main`
- **Verifier:** stage 4. Re-executed every gate; no production code written; nothing committed or pushed.
- **Overall verdict: PASS**

Every prior stage's claim was treated as unverified until re-run below. The Coder and
Refactorer write no report artifact; the commands and exit codes in this file are the
record of what was actually executed.

## Check summary

| # | Check | Verdict | Command | Exit |
|---|---|---|---|---|
| 1 | Scenario traceability | PASS | `scripts/check-scenario-traceability.sh --json` | 0 |
| 2 | Full test suite (run 1) | PASS | `make test-scripts` | 0 |
| 2 | Full test suite (run 2) | PASS | `make test-scripts` | 0 |
| 3 | Complexity gate | PASS | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` | 0 |
| 3.5 | Design-principles gate | PASS (change-scoped) | `scripts/check-code-principles.sh -BaseRef main --json` | 0 |
| 4 | Scenario-to-behavior spot check | PASS | manual cross-check of AC-035-04, AC-035-21, AC-035-33 | 0 |
| 5 | No unaccounted behavior | PASS (finding line) | diff skim | — |

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-26T08:27:43Z

```
{
  "checks": [1, 2],
  "passes": ["AC-035-01 — traced to a test", "AC-035-02 — traced to a test", "AC-035-03 — traced to a test", "AC-035-04 — traced to a test", "AC-035-05 — traced to a test", "AC-035-06 — traced to a test", "AC-035-07 — traced to a test", "AC-035-08 — traced to a test", "AC-035-09 — traced to a test", "AC-035-10 — traced to a test", "AC-035-11 — traced to a test", "AC-035-12 — traced to a test", "AC-035-13 — traced to a test", "AC-035-14 — traced to a test", "AC-035-15 — traced to a test", "AC-035-16 — traced to a test", "AC-035-17 — traced to a test", "AC-035-18 — traced to a test", "AC-035-19 — traced to a test", "AC-035-20 — traced to a test", "AC-035-21 — traced to a test", "AC-035-22 — traced to a test", "AC-035-23 — traced to a test", "AC-035-24 — traced to a test", "AC-035-25 — traced to a test", "AC-035-26 — traced to a test", "AC-035-27 — traced to a test", "AC-035-28 — traced to a test", "AC-035-29 — traced to a test", "AC-035-30 — traced to a test", "AC-035-31 — traced to a test", "AC-035-32 — traced to a test", "AC-035-33 — traced to a test", "AC-035-34 — traced to a test", "AC-035-35 — traced to a test", "AC-035-36 — traced to a test", "AC-035-37 — traced to a test", "AC-035-38 — traced to a test"],
  "fails": []
}
```

Both traceability checks ran (`"checks": [1, 2]`), all 38 scenario IDs (AC-035-01 …
AC-035-38) are cited by at least one test, and every test reference resolves. No fails.

---

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T08:18:33Z

Run 1 — raw output excerpt (head, autopilot cases, tail):

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 65 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..529
ok 167 AC-035-37 — ADR 0013 exists, follows the template, and records every required decision
ok 168 AC-035-38 — ADR 0013 is indexed with a title and Accepted status
ok 169 AC-035-06 — /autopilot runs one slug unattended with autopilot on and no human gate
ok 170 AC-035-07 — /autopilot with several slugs is an ordered queue of independent runs
ok 171 AC-035-08 — /autopilot with no slugs prints usage and stops without guessing
ok 172 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 173 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 174 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 176 AC-035-11 — the section declares the trigger and the no-questions rule
ok 177 AC-035-12 — a disposition exists for all 12 matrix rows, including Deploy verification fails
ok 178 AC-035-13 — all 6 hard stops are listed and never converted into a guess
ok 179 AC-035-14 — all 9 never-list refusals are listed as refusals, not decisions
ok 180 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
ok 181 AC-035-15 — the orchestrator never asks in autopilot and records each resolved ask
ok 182 AC-035-16 — the 9 never-list actions are hard refusals, never decisions
ok 183 AC-035-17 — the queue stops at the first hard stop and writes the morning report
ok 184 AC-035-24 — a tree dirty only inside specs/<slug>/ passes
ok 185 AC-035-25 — gh auth, GITHUB_TOKEN, and GH_TOKEN are required and fail fast
ok 186 AC-035-26 — a named slug whose spec folder does not exist fails with a reason
ok 187 AC-035-27 — the judgment backend is optional and never fails preflight
ok 189 AC-035-21 — a queue that opened a PR writes docs/changes/autopilot-YYYY-MM-DD.md
ok 190 AC-035-22 — a queue that opened no PR writes specs/autopilot-YYYY-MM-DD.md
ok 191 AC-035-23 — the report has ordered per-spec blocks and the conditional sections
ok 193 AC-035-09 — /spec with the token continues instead of stopping for human review
ok 194 AC-035-10 — /build with the token resolves asks per autopilot and never emits BLOCKED
ok 195 AC-035-01 — literal token autopilot in any case triggers
ok 196 AC-035-02 — SPEC_AUTOPILOT=1 triggers without a token
ok 197 AC-035-03 — no token and unset env is not autopilot
ok 198 AC-035-04 — any SPEC_AUTOPILOT value other than the literal 1 is not autopilot
ok 199 AC-035-05 — the token inside a larger word is not a trigger
ok 205 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 206 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 207 AC-035-35 — without the marker, 45-decisions.md is optional either way
ok 324 AC-035-30 — a matrix without the Autopilot mode section FAILs AC-035-30
ok 325 AC-035-31 — a missing disposition for one matrix row FAILs AC-035-31 naming it
ok 326 AC-035-32 — an unconditional question phrase with no autopilot reference FAILs AC-035-32
ok 327 unit — the complete fixture passes the autopilot checks (exit 0)
ok 395 AC-035-28 — the optional autopilot fields are accepted and appended unchanged
ok 396 AC-035-29 — invalid autopilot field values are rejected, naming the field, appending nothing
...
ok 527 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 528 wire: non-numeric confidence is invalid, exits 10
ok 529 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts run 1: `529` `ok`, `0` `not ok`; plan `1..529`; make exit 0.

### Full test suite — second full execution (required re-run)

command: make test-scripts
exit: 0
at: 2026-10-26T08:22:04Z

Run 2 — raw output excerpt (head and tail; full TAP plan and counts):

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 65 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..529
...
ok 525 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 526 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 527 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 528 wire: non-numeric confidence is invalid, exits 10
ok 529 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
```

Counts run 2: `529` `ok`, `0` `not ok`; plan `1..529`; make exit 0.

No test is skipped or disabled: the TAP plan is `1..529` with 529 `ok` lines and zero
`not ok` lines in both runs. The bats assertion-vacuity pre-check (`check-bats-assertions`,
65 files) also passes in both runs.

---

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T08:27:45Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

This repo has no compiled Java/Go/JS production source in the change; the applicable
complexity gate is the repo's own `complexity` category (the same ≤6 rule PMD /
golangci-lint `cyclop` / ESLint `complexity` enforce in child repos), run blame-scoped
to the change against `main`. Zero failures, zero warnings.

---

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef main --json
exit: 0
at: 2026-10-26T08:27:46Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

Change-scoped run: zero FAIL lines and zero WARN lines. Every changed shell script in
the diff (the four new `scripts/autopilot-*.sh`, the extended
`check-stop-and-ask-matrix.sh` / `check-audit-trail.sh` / `record-gate-run.sh`) is
judged under all six categories with no finding.

### Pre-existing unscoped finding (NOT introduced by this change — recorded, not smoothed over)

For completeness, the same gate run **unscoped** over the whole tree exits 1 with one
pre-existing FAIL in a vendored example file this branch does not touch:

command: scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-26T08:30:05Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [{ "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "93" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" }, { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" }, { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }]
}
```

Reproduction on the base ref proves it is pre-existing debt, not a finding against this
spec — a clean `main` worktree gives the identical exit code and identical FAIL:

command: (in `git worktree add /tmp/opencode/main-wt main`) scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-26T08:25:00Z

```
{
  "fails": [
    {
      "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10",
      "file": "./skills/hallmark/site/examples/cobalt-01/script.js",
      "line": "7"
    }
  ]
}
```

`git status` shows no change under `skills/` on this branch. The verdict for this gate is
therefore PASS for the change; the pre-existing finding is flagged to the Architect as a
follow-up candidate (never fixed by the Verifier).

---

## Evidence: scenario-to-behavior spot check

command: manual cross-check of acceptance scenarios AC-035-04, AC-035-21, AC-035-33 against the assertions in scripts/tests/*.bats
exit: 0
at: 2026-10-26T08:26:00Z

Three scenarios drawn from different acceptance files were read alongside their tests
and their live behavior, not just their IDs:

1. **AC-035-04 (AC-035-trigger.md)** — Given `autopilot-trigger.sh`, `SPEC_AUTOPILOT=0`
   (also empty, `true`, `yes`), When it runs, Then it prints exactly `normal` and exits 0.
   `scripts/tests/autopilot-trigger.bats` loops `0 true yes 01 on ""`, asserts
   `status -eq 0` and `output = normal` for each. Direct execution confirmed
   `SPEC_AUTOPILOT=0 → normal`, `true → normal`, `yes → normal`, `"" → normal`,
   `01 → normal`. Assertions match the Given/When/Then.

2. **AC-035-21 (AC-035-morning-report.md)** — Given a queue that opened ≥1 PR, When it
   finishes or stops, Then the report lands at `docs/changes/autopilot-YYYY-MM-DD.md`
   with the UTC queue-start date. `autopilot-report.bats` invokes the writer with
   `--date 2026-10-26`, asserts stdout is exactly
   `docs/changes/autopilot-2026-10-26.md`, asserts the file exists, and greps the PR URL
   out of it. The writer defaults the date to `date -u +%Y-%m-%d` (UTC) and rejects a
   malformed date. Assertions match the scenario.

3. **AC-035-33 (AC-035-audit-enforcement.md)** — Given `30-report.md` contains
   `Autopilot: true` and `45-decisions.md` is missing or empty, When the audit gate runs,
   Then the folder FAILs and the gate exits non-zero. `check-audit-trail.bats` asserts
   status 1 and `45-decisions.md` in the output for both the missing-file and the
   empty-file case; the script's own `--selftest` independently exercises both fixtures
   (`AC-035-33 … exits non-zero (exit 1)` twice). Assertions match the scenario.

No false green found: each test asserts the scenario's concrete outcome, not merely the
presence of an ID.

---

## No unaccounted behavior

Finding line: the change set is fully accounted for by `10-tasks.md` Tasks 1–13. Every
production file maps to a task — `scripts/autopilot-trigger.sh` (Task 1),
`commands/autopilot.md` (Task 2), `commands/spec.md` + `commands/build.md` (Task 3),
`docs/SPEC_PIPELINE.md §Autopilot mode` (Task 4), `agents/spec-pipeline.md` (Task 5),
`scripts/autopilot-decisions.sh` (Task 6), `scripts/autopilot-report.sh` (Task 7),
`scripts/autopilot-preflight.sh` (Task 8), `scripts/record-gate-run.sh` (Task 9),
`scripts/check-stop-and-ask-matrix.sh` (Task 10), `scripts/check-audit-trail.sh`
(Task 11), the bats suite (Task 12), `docs/adr/0013-autopilot-mode.md` +
`docs/adr/README.md` (Task 13). Two changes deserve an explicit justification and are
accounted for:

- `agents/spec-ux.md` — gains an `# Autopilot mode` section. This is required by Task
  10's AC-035-32: `spec-ux.md` carries ask phrases (`BLOCKED —`, `ask one question`), so
  without the autopilot-conversion reference the static scan would (correctly) FAIL it.
- `scripts/tests/typed-judgment-integration.bats` — the AC-029-74 "consumer files carry
  zero changes" assertion is narrowed so `agents/spec-ux.md` may change only additively
  and only with an `Autopilot mode` block, while `skills/ci-triage/SKILL.md` stays
  byte-identical. This is a test-contract update made necessary by the in-scope
  `spec-ux.md` change, not new behavior.

No production logic, flag, or artifact appears that no task or scenario accounts for.

---

## Targeted checks requested by the orchestrator

### Matrix is 12 rows, and the gate enforces all 12

Row counts (data rows, header and separator excluded):

```
Stop-and-Ask decision matrix table: 12
Autopilot mode disposition table:   12
ROW_CONDITIONS in check-stop-and-ask-matrix.sh: 12
```

The previously omitted `Deploy verification fails` row is now enforced in the base matrix
list. Scratch copy with only that base row deleted (`/tmp/opencode/verify035/a`):

```
command: scripts/check-stop-and-ask-matrix.sh /tmp/opencode/verify035/a
exit: 1

FAIL matrix row missing or altered: condition [Deploy verification fails] action [Route per fix-routing rule; on ambiguous failure, STOP and escalate to human; never guess]
FAIL AC-009-01-03 — at least one of the 12 matrix rows is missing or altered
```

A scratch copy missing the `## Autopilot mode` section (`/tmp/opencode/verify035/c`)
FAILs AC-035-30 and exits 1:

```
FAIL AC-035-30 — docs/SPEC_PIPELINE.md is missing the '## Autopilot mode' section
FAIL AC-035-31 — no autopilot disposition for matrix condition [Working tree dirty]
...
FAIL AC-035-31 — no autopilot disposition for matrix condition [Deploy verification fails]
FAIL AC-035-31 — at least one of the 12 matrix conditions has no autopilot disposition
FAIL AC-009-04-02 — 14 violation(s); script exits 1
```

A scratch copy missing only the `Deploy verification fails` autopilot disposition
(`/tmp/opencode/verify035/b`) FAILs AC-035-31 naming that exact condition and exits 1:

```
FAIL AC-035-31 — no autopilot disposition for matrix condition [Deploy verification fails]
FAIL AC-035-31 — at least one of the 12 matrix conditions has no autopilot disposition
FAIL AC-009-04-02 — 2 violation(s); script exits 1
```

### The unconditional-question static scan bites

Planted `Ask the user before continuing.` in a scratch copy of
`agents/spec-coder.md` (the real tree is untouched). The scan FAILs AC-035-32 and exits 1:

```
FAIL AC-035-32 — spec-coder.md contains the unconditional question phrase [ask the user] with no 'Autopilot mode' conversion reference
FAIL AC-035-32 — at least one pipeline agent may still ask unconditionally in autopilot
FAIL AC-009-04-02 — 2 violation(s); script exits 1
```

Control: the same phrase planted in `agents/spec-ux.md`, which does reference the
autopilot conversion, keeps the check green (`PASS AC-035-32`, exit 0) — so the scan is
conditioned on the reference, not a blanket phrase ban.

### Hard stops and the never-list

`docs/SPEC_PIPELINE.md §Autopilot mode` lists all six hard stops verbatim
(dirty tree outside the current spec folder; no repo / no `00-informal.md` / no way to
establish requirements; phase-1 or phase-2 budget exhausted; deploy failure after 3
attempts; `30-report.md` missing or not green at PR time; any never-list action) and all
nine refusals (no merge; no git tag; no push to `main`/`master`; no force-push; no branch
deletion; no gate-threshold change; no secret creation/rotation; no writes outside the
target repo; no `git init`/submodule scaffolding), with the explicit statement that
these are refusals, not decisions. `agents/spec-pipeline.md` restates all nine as hard
refusals and states a never-list action is a hard stop, never a decision.

Enforced by test: `autopilot-doc-section.bats` AC-035-13 asserts each hard stop and the
"never converts a hard stop into a guess" sentence; AC-035-14 asserts each of the nine
refusals and "refusals, not decisions"; `autopilot-orchestrator.bats` AC-035-16 asserts
the nine refusals in the orchestrator plus "hard stop" / "never a decision". Both passed
in both full suite runs.

No autopilot path can merge, tag, or push `main`: the nine refusals are unconditional,
the commit-and-push carve-out is unchanged and still limited to `spec/NNN-slug`, and no
new script or command contains a merge/tag/push-main command. There is no such FAIL.

### `45-decisions.md` contract

Live smoke of the deterministic writer (`/tmp/opencode/vdec`):

```
$ scripts/autopilot-decisions.sh add 45-decisions.md --condition 'Acceptance criteria ambiguous' \
    --options 'conservative; rewrite' --chosen 'conservative' --why 'reversible' \
    --reversibility 'high' --at 2026-10-26T03:14:07Z
exit 0
Condition: Acceptance criteria ambiguous
Options: conservative; rewrite
Chosen: conservative
Why: reversible
Reversibility: high
At: 2026-10-26T03:14:07Z

$ scripts/autopilot-decisions.sh count 45-decisions.md
1

$ scripts/autopilot-decisions.sh mark-report 45-decisions.md 30-report.md
# Report
Final status: green

Autopilot: true
Autopilot decisions: 1

$ scripts/autopilot-decisions.sh none empty-run.md
No autopilot decisions were required          # exactly 1 line, wc -l = 1

$ scripts/autopilot-decisions.sh add bad.md ... --at '26-10-2026'
autopilot-decisions: At must be an ISO-8601 UTC timestamp YYYY-MM-DDTHH:MM:SSZ (got '26-10-2026')
exit 1
no file written (correct)
```

The six labels, ISO-8601 `At`, the exact single-line clean-run artifact, and
`Autopilot: true` / `Autopilot decisions: N` are all present and tested (AC-035-18/19/20
pass). Audit-trail requirement when `30-report.md` says `Autopilot: true`: the gate's own
selftest passes `AC-035-33` twice (missing and empty `45-decisions.md` both exit 1),
`AC-035-34` (non-empty → exit 0), and `AC-035-35` (optional without the marker, present
and absent → exit 0); `check-audit-trail.bats` repeats the same three cases and passed.

### Trigger: whole token only

Direct execution of `scripts/autopilot-trigger.sh` (all exits 0, output is the verdict):

```
token=autopilot      -> autopilot
token=AUTOPILOT      -> autopilot
token=AutoPilot      -> autopilot
token=--autopilot    -> normal
token=myautopilot    -> normal
token=autopilot-mode -> normal
token=autopilot.js   -> normal
SPEC_AUTOPILOT=1     -> autopilot
SPEC_AUTOPILOT=0     -> normal
SPEC_AUTOPILOT=true  -> normal
SPEC_AUTOPILOT=yes   -> normal
SPEC_AUTOPILOT=''    -> normal
SPEC_AUTOPILOT=01    -> normal
unset                -> normal
```

`--autopilot` and `myautopilot` do not trigger; only the literal `1` is truthy for
`SPEC_AUTOPILOT`. `autopilot-trigger.bats` AC-035-01..05 asserts the same set (including
`myautopilot`, `autopilot-mode`, `--autopilot`, `autopilot.js`, `mode-autopilot`).

### Preflight is fail-fast and offline-safe

`scripts/autopilot-preflight.sh` checks in the documented order and `die`s on the first
failure (`preflight: <reason>` to stderr, non-zero, later checks do not run).
`autopilot-preflight.bats` is hermetic: `gh` is a stub on `PATH`
(`cat > "$STUB/gh" <<'SH' … exit "${GH_STUB_EXIT:-0}"`), tokens are literals, and the
optional judgment backend is probed only against `http://127.0.0.1:1` (instant refusal).
No test invokes live `gh`, and the suite passed in both full runs. AC-035-24..27 pass.

### ADR 0013

`docs/adr/0013-autopilot-mode.md` exists and carries `## Title`, `## Status` (body
`Accepted`), `## Context`, `## Decision`, `### Alternatives Considered` (table),
`## Consequences`, `## Compliance` (naming `check-stop-and-ask-matrix.sh` and
`check-audit-trail.sh`), and `## Notes`. `docs/adr/README.md` has the row
`| 0013 | [Autopilot mode: choose-default-record-continue for unattended pipeline queue runs](0013-autopilot-mode.md) | Accepted |`.
It does not reuse 0011/0012: no `0011-*` or `0012-*` file exists, and the Notes record
that 0011 (PR #99) and 0012 (PR #101) are reserved, with 0013 the next free number.
AC-035-37/38 pass.

---

## Warnings and notes (non-blocking)

- **WARN — pre-existing full-tree design-principles FAIL:** `skills/hallmark/site/examples/cobalt-01/script.js` (CC=10) fails the unscoped gate and reproduces identically on `main`. It is untouched by this branch and out of scope; flagged to the Architect as a follow-up. The change-scoped gate is clean.
- **WARN — pre-existing doc-size hint:** `make validate-all` reports `skills/hallmark/SKILL.md` body 562 lines (>500 recommended). Unrelated to this spec; unchanged.
- **NOTE — executable bit:** `scripts/record-gate-run.sh` is not executable in this checkout, so `./scripts/record-gate-run.sh` exits 126; telemetry was appended with the documented bash form `bash scripts/record-gate-run.sh` (exit 0). Same pre-existing shape recorded by earlier specs, not introduced here.
- **NOTE — `make validate-all`** (extra, not one of the five contract checks) exit 0: required files present, all cross-references valid, all SKILL.md files valid (1 pre-existing warning). `scripts/check-orchestration.sh` exit 0: all agent, skill, script, and doc references resolve.

## Telemetry

Appended one record to `runs.jsonl` via `bash scripts/record-gate-run.sh` after the checks
completed (exit 0, `runId` generated by the script, `loopCount`/`phase1Retries`/
`phase2Retries` from the orchestrator's exported `SPEC_LOOP_COUNT=1`,
`SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`):

```
{"specSlug":"035-autopilot-mode","gatesFailed":[],"warnings":["pre-existing full-tree design-principles FAIL in untouched skills/hallmark/site/examples/cobalt-01/script.js reproduces unchanged on main; change-scoped gate clean","validate-all: skills/hallmark/SKILL.md body 562 lines exceeds 500-line recommendation"],"durationSec":649,"outcome":"pass","runId":"d64bcb6e-8046-4664-ab73-7fc7f198e56d","loopCount":1,"phase1Retries":0,"phase2Retries":0}
```

## Verdict

**PASS.** All five contract gates ran and produced no findings against the change:
traceability exit 0, `make test-scripts` exit 0 twice (529 ok / 0 not ok both times),
complexity exit 0, design-principles change-scoped exit 0. The spot check found the
tested assertions match their scenarios. The one unscoped design-principles FAIL is
pre-existing on `main` in an untouched vendored example and is recorded above rather
than hidden. The Architect may proceed.
