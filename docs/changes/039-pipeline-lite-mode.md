# 039-pipeline-lite-mode

> Spec pipeline archive. Original source: `specs/039-pipeline-lite-mode/` (deleted by this script).
> Archived: 2026-11-05

## Original ask

# Lite mode for small specs

Problem: every /build runs coder, refactorer, verifier, mutation runner, PR opener (+ deployer, ux, two remediation loops up to 3 rounds each). For a small spec (docs-only, single script, <N lines changed) this is mostly overhead.

Want: a `lite` mode (argument token or auto-classified by a deterministic script on spec size/surface) that runs coder -> verifier -> PR opener, skipping refactorer, mutation runner, ux, deployer. Verifier gates that are hard requirements (tests green, secrets scan, principles FAIL) still run. Classification is mechanical, logged in 45-decisions.md, and overridable by the human. Never usable on conformance tier `production` code paths. Requires an ADR per docs/GOVERNANCE.md (changes pipeline roles).

## Tasks

# 039 — Pipeline lite mode: tasks

Lite mode runs Coder → Verifier → PR Opener and skips Refactorer, Mutation
Runner, UX Designer, and Deploy Verifier. Selection is mechanical (explicit
token or deterministic classifier), logged in `45-decisions.md`, overridable by
the human, and refused on conformance tier `production`.

## Open questions (must be answered before `/build`)

- **Q1 — size threshold N (BLOCKED).** The informal spec says "<N lines
  changed" without a value, and also mentions "docs-only, single script".
  Exactly which mechanical inputs decide `lite`? Proposed default, pending human
  confirmation: `lite` iff every path named in `10-tasks.md` is under `docs/`,
  `specs/`, or is a `*.md` file, OR the spec names exactly one file under
  `scripts/`; and the summed acceptance-scenario count is ≤ 5. Scenarios in
  AC-039-02 are written against these named inputs and must be re-pinned if Q1
  changes them.
- **Q2 — tier scope (BLOCKED).** The informal spec forbids lite on tier
  `production`. Does the refusal also apply to `multi-service` (a superset of
  `production` gates per `docs/CONFORMANCE_TIERS.md`)? Scenarios currently
  refuse `production` only; AC-039-03-03 is marked pending Q2.
- **Q3 — tier source.** Which file/command yields the repo's tier for the
  classifier? If undetectable, the Stop-and-Ask matrix default (`mvp`) applies —
  but defaulting to `mvp` could permit lite on an undeclared production repo.
  Scenarios assume: undetectable tier ⇒ lite refused (conservative). Confirm.

## Task 1 — Lite trigger detection script

`scripts/lite-trigger.sh` (plus `.ps1` twin if the repo convention requires one)
answers: did the human request a mode explicitly?

- Exit/stdout contract: prints exactly one of `lite`, `full`, `auto`.
- Any single argv element equal to `lite` case-insensitively ⇒ `lite`.
- Any single argv element equal to `full` case-insensitively ⇒ `full`.
- Both present ⇒ non-zero exit, stderr names the conflict, prints nothing on stdout.
- Neither ⇒ `auto`.
- Whole-token match only: `--lite`, `lite-mode`, `mylite` do not match.
- Commands and agents must call this script; no re-implementation of the match
  (grep-checkable: no other file matches the token comparison).

## Task 2 — Deterministic size/surface classifier

`scripts/classify-spec-size.sh specs/NNN-slug` prints `lite` or `full` and one
`Reason:` line on stdout.

- Inputs are only files inside the spec folder (`10-tasks.md`, `20-acceptance/`);
  no network, no model call, no clock dependence.
- Same input files ⇒ byte-identical output across runs.
- Rule per Q1 (pending). `full` whenever any rule input is missing or unparsable.
- Missing spec folder ⇒ non-zero exit with stderr message.

## Task 3 — Tier guard

Lite is never selected on tier `production`.

- Resolved mode is `full` whenever the detected tier is `production`, even if
  the human passed `lite`; the refusal is reported (stderr) and recorded.
- Undetectable tier ⇒ `full` (per Q3, pending).
- `mvp` tier ⇒ mode follows Task 4 resolution.
- Guard lives in one script (resolution in Task 4); no agent re-implements it.

## Task 4 — Mode resolution and decision logging

`scripts/resolve-pipeline-mode.sh specs/NNN-slug [ARG ...]` combines Task 1–3
and writes one entry to `specs/NNN-slug/45-decisions.md` using the existing
six-line format (`Condition:`, `Options:`, `Chosen:`, `Why:`,
`Reversibility:`, `At:`) via `scripts/autopilot-decisions.sh` or the same format.

- Precedence: tier guard > explicit human token (Task 1) > classifier (Task 2).
- Explicit `full` overrides a classifier `lite`; explicit `lite` overrides a
  classifier `full` (human override), subject to the tier guard.
- `Chosen:` is `lite` or `full`; `Why:` names the deciding input
  (`tier`, `argument`, or `classifier` + its `Reason:`).
- Exactly one entry appended per invocation; existing entries untouched.
- Writes only inside `specs/NNN-slug/`.

## Task 5 — `/build` stage selection in lite mode

`commands/build.md` (and orchestration wiring it references) runs stages per the
resolved mode.

- `lite`: stages run in order Coder → Verifier → PR Opener (5b) → Archiver (5d).
  Refactorer, Mutation Runner, UX Designer, Deploy Verifier are not invoked.
- `full`: stage list unchanged from current behaviour.
- PR Opener precondition in lite: requires Verifier PASS; `30-report.md` records
  `Pipeline mode: lite` and lists skipped stages with `skipped (lite)`; the
  mutation section reads `skipped (lite)` rather than missing, so the "report
  green" check still passes.
- `scripts/check-orchestration.sh` exits 0 after the change.

## Task 6 — Verifier hard gates unchanged in lite

- In lite mode the Verifier still runs: full test suite, secrets scan
  (`scripts/check-no-hardcoded-secrets.sh`), `scripts/check-code-principles.sh`
  (FAIL blocks), scenario traceability.
- A FAIL from any of these yields Verifier FAIL and the pipeline STOPs per the
  Stop-and-Ask matrix; no PR opened.
- Remediation budget rules unchanged.

## Task 7 — Documentation and ADR

- New ADR `docs/adr/NNNN-pipeline-lite-mode.md` from `templates/ADR.md`, status
  `Proposed`, listed in `docs/adr/README.md`.
- `docs/SPEC_PIPELINE.md` gains a `## Lite mode` section stating: trigger tokens,
  classifier script, precedence, tier refusal, skipped stages, retained gates,
  `45-decisions.md` logging, and a link to the ADR.
- `docs/SPEC_PIPELINE.md §Conformance tiers` table gains a lite column or note.
- `scripts/check-orchestration.sh` and `scripts/check-skills.sh` exit 0.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Q1: small = only docs/, specs/, *.md, or exactly one scripts/ file, AND <=5 scenarios.
- Q2: lite refused on `multi-service` too.
- Q3: unknown tier => lite refused.

## Acceptance scenarios

## AC-039-01-01 — Explicit lite token
## AC-039-01-02 — Explicit full token
## AC-039-01-03 — No token
## AC-039-01-04 — Partial tokens do not match
## AC-039-01-05 — Conflicting tokens
## AC-039-02-01 — Docs-only small spec is lite
## AC-039-02-02 — Single-script spec is lite
## AC-039-02-03 — Scenario count above boundary is full
## AC-039-02-04 — Two scripts is full
## AC-039-02-05 — Missing inputs fall back to full
## AC-039-02-06 — Missing spec folder
## AC-039-02-07 — Determinism
## AC-039-03-01 — Production refuses explicit lite
## AC-039-03-02 — Production refuses classifier lite
## AC-039-03-03 — Multi-service
## AC-039-03-04 — Undetectable tier refuses lite
## AC-039-03-05 — MVP permits lite
## AC-039-04-01 — Classifier decides when no token
## AC-039-04-02 — Human full overrides classifier lite
## AC-039-04-03 — Human lite overrides classifier full
## AC-039-04-04 — Tier refusal is logged
## AC-039-04-05 — Entry format and append-only
## AC-039-04-06 — Writes stay in spec folder
## AC-039-05-01 — Lite stage list
## AC-039-05-02 — Full stage list unchanged
## AC-039-05-03 — Report records lite mode
## AC-039-05-04 — Orchestration check passes
## AC-039-06-01 — Hard gates run in lite
## AC-039-06-02 — Principles FAIL stops lite run
## AC-039-06-03 — Secrets finding stops lite run
## AC-039-07-01 — ADR exists and is indexed
## AC-039-07-02 — SPEC_PIPELINE documents lite mode
## AC-039-07-03 — Standards checks pass

## Verification

# 039 — Pipeline lite mode: verification

- **Attempt:** 1, phase 1 (first full run; no prior re-verification)
- **Verifier:** stage 4, independent re-execution. Coder and Refactorer claims treated as unverified until re-run.
- **Worktree:** `/home/dbueno/.local/share/opencode/worktree/471827/spec-039` (detached HEAD, stacked on `spec/037-split-spec-pipeline-doc`)
- **Resolved pipeline mode for this run:** `full` — no `Conformance tier:` declaration is reachable from `specs/039-pipeline-lite-mode` (AGENTS.md, AGENTS_*.md, and every parent directory declare nothing), so the Task-3 guard refuses `lite`; independently the classifier returns `full` (`Reason: 7 files named under scripts/ — lite allows at most one`). The full stage list therefore applies to this run.
- **Verdict:** **FAIL** — gate `spot-check`.
- **Current verdict (attempt 2, phase 1): PASS** — see §Round 2. The attempt-1 verdict below is historical: the relative-path defect it records was fixed and re-verified.

## Gate summary

| # | Check | Result |
|---|---|---|
| 1 | Scenario traceability | PASS |
| 2 | Full test suite | PASS |
| 3 | Complexity gate | PASS |
| 3.5 | Design-principles gate | PASS (1 WARN in a changed file) |
| 4 | Scenario-to-behavior spot check | **FAIL** |
| 5 | No unaccounted behavior | finding lines below (not a gate) |

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-01T16:19:17Z

{
  "checks": [1, 2],
  "passes": ["AC-039-01 — traced to a test", "AC-039-02 — traced to a test", "AC-039-03 — traced to a test", "AC-039-04 — traced to a test", "AC-039-05 — traced to a test", "AC-039-06 — traced to a test", "AC-039-07 — traced to a test"],
  "fails": []
}

$ bash scripts/check-scenario-traceability.sh
Scenario IDs found: 7 live, 489 archived

PASS AC-039-01 — traced to a test
PASS AC-039-02 — traced to a test
PASS AC-039-03 — traced to a test
PASS AC-039-04 — traced to a test
PASS AC-039-05 — traced to a test
PASS AC-039-06 — traced to a test
PASS AC-039-07 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

## Evidence: full test suite

command: make test
exit: 0
at: 2026-11-01T16:19:42Z

Checking bats assertions are not vacuous...
PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..806
[... 806 TAP lines omitted, all `ok` ...]
ok 804 unit: a cap smaller than the marker still never exceeds the cap
ok 805 unit: state exactly at the cap is not truncated and emits no reason
ok 806 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

$ grep -cE '^ok [0-9]+' /tmp/opencode/039-test.log
806
$ grep -E '^not ok|# skip' /tmp/opencode/039-test.log
ok 2 AC-001-02: Failing bats test fails the target (not ok)
$ grep -nE '^# (skip|SKIP)' /tmp/opencode/039-test.log | wc -l
0

(806 of 806 `ok`; the single `not ok` substring is part of the *name* of an
existing passing test; zero skips. Finished 2026-11-01T16:29:29Z.)

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh --gates complexity --json scripts
exit: 0
at: 2026-11-01T16:35:58Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}

$ shellcheck -x scripts/lite-trigger.sh scripts/classify-spec-size.sh scripts/resolve-pipeline-mode.sh scripts/tests/ac-031-doc-section.bash
(no output)

$ echo $?
0

(Repository language is bash: `shellcheck` is the real linter, run against every
new/changed shell file — clean. The design-principles cyclomatic gate on
`scripts/` — the tree every changed script lives in — reports zero findings.)

## Evidence: design-principles gate

command: bash scripts/check-code-principles.sh --json
exit: 0
at: 2026-11-01T16:29:32Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" }, { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" }, { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:111:242::KISS_LINES=38", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "111" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" }, { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" }, { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" }, { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" }, { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.selftest.sh:641)", "file": "./scripts/check-code-principles.selftest.sh", "line": "641" }, { "message": "Comments: section-divider comment (./scripts/check-code-principles.selftest.sh:639)", "file": "./scripts/check-code-principles.selftest.sh", "line": "639" }, { "message": "Comments: comment restates the following line (./scripts/tests/gate-telemetry.selftest.sh:150)", "file": "./scripts/tests/gate-telemetry.selftest.sh", "line": "150" }, { "message": "Comments: commented-out code (./scripts/check-bats-assertions.sh:21)", "file": "./scripts/check-bats-assertions.sh", "line": "21" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/gate-clean-code-lib.sh:97)", "file": "./scripts/gate-clean-code-lib.sh", "line": "97" }, { "message": "Comments: commented-out code (./scripts/verify-production-deploy.sh:30)", "file": "./scripts/verify-production-deploy.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:58)", "file": "./scripts/check-code-principles.sh", "line": "58" }, { "message": "Comments: commented-out code (./scripts/check-code-principles.sh:121)", "file": "./scripts/check-code-principles.sh", "line": "121" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-code-principles.sh:57)", "file": "./scripts/check-code-principles.sh", "line": "57" }, { "message": "Comments: attribution comment (./scripts/check-code-principles.sh:59)", "file": "./scripts/check-code-principles.sh", "line": "59" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:139)", "file": "./scripts/check-remediation-budget.sh", "line": "139" }, { "message": "Comments: comment restates the following line (./scripts/check-remediation-budget.sh:209)", "file": "./scripts/check-remediation-budget.sh", "line": "209" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:13)", "file": "./scripts/lint-outbox-schema.sh", "line": "13" }, { "message": "Comments: commented-out code (./scripts/lint-outbox-schema.sh:22)", "file": "./scripts/lint-outbox-schema.sh", "line": "22" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-timeouts.sh:185)", "file": "./scripts/check-saga-timeouts.sh", "line": "185" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:51)", "file": "./scripts/ci-smoke-test.sh", "line": "51" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:53)", "file": "./scripts/ci-smoke-test.sh", "line": "53" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:90)", "file": "./scripts/ci-smoke-test.sh", "line": "90" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:92)", "file": "./scripts/ci-smoke-test.sh", "line": "92" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:132)", "file": "./scripts/ci-smoke-test.sh", "line": "132" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:134)", "file": "./scripts/ci-smoke-test.sh", "line": "134" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:149)", "file": "./scripts/ci-smoke-test.sh", "line": "149" }, { "message": "Comments: section-divider comment (./scripts/ci-smoke-test.sh:151)", "file": "./scripts/ci-smoke-test.sh", "line": "151" }, { "message": "Comments: commented-out code (./scripts/check-loop-files.sh:10)", "file": "./scripts/check-loop-files.sh", "line": "10" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:6)", "file": "./scripts/init-ci.sh", "line": "6" }, { "message": "Comments: section-divider comment (./scripts/init-ci.sh:43)", "file": "./scripts/init-ci.sh", "line": "43" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:39)", "file": "./scripts/check-loop-triage.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:49)", "file": "./scripts/check-loop-triage.sh", "line": "49" }, { "message": "Comments: commented-out code (./scripts/check-loop-triage.sh:67)", "file": "./scripts/check-loop-triage.sh", "line": "67" }, { "message": "Comments: commented-out code (./scripts/token-stats.sh:10)", "file": "./scripts/token-stats.sh", "line": "10" }, { "message": "Comments: commented-out code (./scripts/classify-spec-size.sh:28)", "file": "./scripts/classify-spec-size.sh", "line": "28" }, { "message": "Comments: commented-out code (./scripts/guard-env.sh:21)", "file": "./scripts/guard-env.sh", "line": "21" }, { "message": "Comments: commented-out code (./scripts/check-ci-sweeper.sh:37)", "file": "./scripts/check-ci-sweeper.sh", "line": "37" }, { "message": "Comments: commented-out code (./scripts/check-security-hardening.sh:39)", "file": "./scripts/check-security-hardening.sh", "line": "39" }, { "message": "Comments: commented-out code (./scripts/judgment-preflight.sh:16)", "file": "./scripts/judgment-preflight.sh", "line": "16" }, { "message": "Comments: commented-out code (./scripts/check-model-env.sh:30)", "file": "./scripts/check-model-env.sh", "line": "30" }, { "message": "Comments: commented-out code (./scripts/gate-stats.sh:20)", "file": "./scripts/gate-stats.sh", "line": "20" }, { "message": "Comments: commented-out code (./scripts/check-pr-babysitter.sh:56)", "file": "./scripts/check-pr-babysitter.sh", "line": "56" }, { "message": "Comments: TODO/FIXME without an issue reference (./scripts/check-saga-tests.sh:85)", "file": "./scripts/check-saga-tests.sh", "line": "85" }, { "message": "Naming: boolean flag parameter (hasDedupStore) (./ci/templates/archunit/OutboxArchRules.java:197)", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "197" }, { "message": "Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "147" }, { "message": "Naming: boolean flag parameter (hasStateStore) (./ci/templates/archunit/SagaArchRules.java:201)", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "201" }, { "message": "Naming: more than three parameters (Fprintf) (./ci/templates/go-saga-lint.go:61)", "file": "./ci/templates/go-saga-lint.go", "line": "61" }, { "message": "Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "65" }]
}

$ bash scripts/check-code-principles.sh --json > /tmp/opencode/039-cp.json; jq -r '.fails[]?, (.warns[]? | select(.file|test("lite-trigger|classify-spec-size|resolve-pipeline-mode|ac-039|ac-031-doc-section|autopilot-decisions")))' /tmp/opencode/039-cp.json
{
  "message": "Comments: commented-out code (./scripts/classify-spec-size.sh:28)",
  "file": "./scripts/classify-spec-size.sh",
  "line": "28"
}

$ jq '{fails:(.fails|length), warns:(.warns|length), tier}' /tmp/opencode/039-cp.json
{
  "fails": 0,
  "warns": 59,
  "tier": "mvp"
}

(0 FAIL. 59 WARN, 58 of them pre-existing findings in files this spec does not
touch. 1 WARN is in a changed file: `scripts/classify-spec-size.sh:28` —
`#   0 — a classification was produced (\`lite\` or \`full\`)`, the exit-code line
of the script's own usage banner, matched by the commented-out-code heuristic.
Heuristic false positive; no action implied, recorded per contract.)

## Evidence: scenario-to-behavior spot check

command: timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite
exit: 124
at: 2026-11-01T16:35:26Z

(cwd: /tmp/opencode/rel39 — a fixture repo with `specs/s/10-tasks.md` naming
`docs/FOO.md`, `specs/s/20-acceptance/a.md` holding one scenario, and NO
`Conformance tier:` declaration anywhere at or above it. Command timed out
after 5 s with empty stdout and empty stderr: the resolver never returns.)

$ timeout 5 bash scripts/resolve-pipeline-mode.sh "$PWD/specs/s" lite
resolve-pipeline-mode: lite mode refused — conformance tier 'undetectable' does not permit it
full
rc=0

$ timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite
rc=124

$ bats --tap -f 'AC-039-02-06|AC-039-02-07|AC-039-05-01|AC-039-03-04' scripts/tests/ac-039-lite-mode.bats scripts/tests/ac-039-lite-wiring.bats
1..4
ok 1 AC-039-02-06: a missing spec folder exits non-zero naming the path
ok 2 AC-039-02-07: the classifier is byte-identical across runs
ok 3 AC-039-03-04: an undetectable tier refuses an explicit lite token
ok 4 AC-039-05-01: lite runs Coder, Verifier, PR Opener, Archiver and nothing else

### Scenarios checked

Random draw (3): `AC-039-02-06`, `AC-039-02-07`, `AC-039-05-01`.

- **AC-039-02-06 — Missing spec folder.** Test asserts exit != 0 and stderr
  contains the offending path. Live: `scripts/classify-spec-size.sh specs/nope`
  → stderr `classify-spec-size: spec folder not found: specs/nope`, exit 2.
  Assertions match the scenario. PASS.
- **AC-039-02-07 — Determinism.** Test builds a fixture, runs the classifier
  twice with `sleep 1` between (so a clock-dependent implementation would
  diverge) and compares whole output. Live on the real spec: two runs both
  produced `full` / `Reason: 7 files named under scripts/ — lite allows at most
  one`. Assertions match the scenario. PASS.
- **AC-039-05-01 — Lite stage list.** Test asserts the flattened
  `commands/build.md` contains the literal chain
  `` `spec-coder` → `spec-verifier` → `spec-pr-opener` (5b) → `spec-pr-opener` (5d) ``,
  which pins the order, and that the document names the four skipped stages and
  `not invoked`. The real text does tie them together (“skip the rest;
  `spec-refactorer`, `spec-mutation-runner`, `spec-ux`, and `spec-deployer` are
  not invoked.”), but the assertion does not couple the four names to that
  sentence — the document could name them elsewhere and still pass. Weak
  coupling, not a false green here. PASS with note.

Additional live check of the tier guard against the human review decisions
(`10-tasks.md §Human review decisions`), run on absolute paths so it terminates:

    tier=production    token=lite  -> mode=full   stderr: lite mode refused — tier 'production'
    tier=production    token=full  -> mode=full   stderr: (none)
    tier=production    token=none  -> mode=full   stderr: lite mode refused — tier 'production'
    tier=multi-service token=lite  -> mode=full   stderr: lite mode refused — tier 'multi-service'
    tier=multi-service token=full  -> mode=full   stderr: (none)
    tier=multi-service token=none  -> mode=full   stderr: lite mode refused — tier 'multi-service'
    tier=mvp           token=lite  -> mode=lite   stderr: (none)
    tier=mvp           token=full  -> mode=full   stderr: (none)
    tier=mvp           token=none  -> mode=lite   stderr: (none)
    tier=undetectable  token=lite  -> mode=full   stderr: lite mode refused — tier 'undetectable'
    tier=undetectable  token=full  -> mode=full   stderr: (none)
    tier=undetectable  token=none  -> mode=full   stderr: lite mode refused — tier 'undetectable'

**FAIL — the spot check found a live behavior defect.** With the *relative*
spec path — the form used in the resolver's own usage line
(`scripts/resolve-pipeline-mode.sh specs/NNN-slug [ARG ...]`) and in every doc
that names it — an undetectable tier does not resolve to `full`; the process
loops forever and must be killed. AC-039-03-04 (“Given no detectable tier …
Then resolved mode is `full`”) is violated for the documented invocation form.

Root cause: `detect_tier` walks upward with
`while [ -n "$dir" ] && [ "$dir" != "/" ]` and `dir="$(dirname "$dir")"`.
For a relative input the walk reaches `.`, and `dirname .` is `.` — the loop
never terminates. Passing an absolute path, or having any `Conformance tier:`
declaration reachable before `.`, hides the defect. The suite cannot see it:
every resolver fixture in `scripts/tests/ac-039-lite-mode.bats` is built from an
absolute `$TMPDIR_HELPER` path, so `test AC-039-03-04` is a false green for the
documented usage.

Trace of the loop (2 s of a run that would not otherwise stop):

    $ timeout 2 bash -x scripts/resolve-pipeline-mode.sh specs/s lite 2>&1 | grep -E 'tier_in_dir|dirname|dir=' | tail -6
    +++ tier_in_dir .
    +++ dirname .
    ++ dir=.
    +++ tier_in_dir .
    +++ dirname .
    ++ dir=.

    $ timeout 2 bash -x scripts/resolve-pipeline-mode.sh specs/s lite 2>&1 | grep -c 'dirname'
    374

(374 upwards steps in two seconds, all of them `tier_in_dir .` → `dirname .` →
`dir=.`: the walk never reaches `/` because a relative path bottoms out at `.`.)

## Evidence: no unaccounted behavior

(recorded as findings, not a command)

- `scripts/resolve-pipeline-mode.sh:detect_tier` — the relative-path infinite
  loop above. Unaccounted for by Task 3's contract (“Undetectable tier ⇒
  `full`”) and by AC-039-03-04. **Blocks.**
- `specs/039-pipeline-lite-mode/45-decisions.md` does not exist. Task 4 requires
  one appended entry per resolution, and `commands/build.md` /
  `agents/spec-pipeline.md` both require the orchestrator to resolve the mode
  before delegating — yet this run (Coder, Refactorer, now Verifier) logged
  nothing. No mode resolution was executed for this spec. Combined with the
  hang above, the logging path is unproven end-to-end: it works when a caller
  happens to pass an absolute path, and it is exactly the undetectable-tier
  branch that hangs when a caller follows the documented relative form. The
  Verifier did not create the file (out of scope for this stage).
- `20-acceptance/AC-039-02-classifier.md` header still reads “(Inputs pending
  Q1; re-pin if Q1 changes the rule.)”, and `AC-039-03-03` / `AC-039-03-04`
  titles still carry “(pending Q2)” / “(pending Q3)”, although
  `10-tasks.md §Human review decisions (2026-10-30)` records all three as
  decided and the tests are written against the decided behaviour. Stale
  annotations only; no behavioral divergence.
- `scripts/measure-stage-read-cost.sh` is unchanged by this spec, but the
  budget it enforces is thin for the stage this spec edits:
  `pr-opener 25346 0.498 ok` against a 50 % (= 25418 B) ceiling — 72 bytes of
  headroom. `docs/spec-pipeline/pr-opener.md` gained a 6-line `## Lite mode`
  section in this change and the gate is still green (`exit 0`), but the next
  addition to that file or to its `Must read` set flips it. No budget failure;
  flagged to the Architect.
- Refactorer's `scripts/tests/ac-031-doc-section.bash` change (extracting
  `section_of` out of `section`) is behavior-preserving: the two ac-031 bats
  files were not modified, and `bats --tap scripts/tests/ac-031-*.bats` →
  `1..78`, every line `ok`, exit 0. Combined rerun of `ac-031-*.bats` +
  `ac-037-*.bats`: `1..104`, all `ok`. No ac-031 regression.

## Behavior vs structural

**Behaviorally verified (real executions, absolute-path inputs):**
`scripts/lite-trigger.sh` (5 scenarios + conflict path: exit 2, empty stdout,
stderr names both tokens), `scripts/classify-spec-size.sh` (7 scenarios +
live runs on the real spec and on missing paths), `scripts/resolve-pipeline-mode.sh`
(5 tier-guard scenarios + 6 logging scenarios; live single-entry check: three
invocations → exactly 3 `Condition:` entries, conflicting tokens → exit 2 and
the count unchanged; live refusal path → `Chosen: full`, `Why: tier: …`).

**Behaviorally failed:** `scripts/resolve-pipeline-mode.sh` with a relative spec
path and no reachable tier declaration (hang; see above).

**Structurally verified only** (assertions read documents; no lite pipeline has
ever been run end to end): Task 5 stage selection (`commands/build.md`,
`agents/spec-pipeline.md`), Task 6 retained gates (`docs/spec-pipeline/verifier.md`,
`lite-mode.md`), Task 7 docs/ADR (`docs/SPEC_PIPELINE.md §Lite mode`,
`docs/adr/0020-pipeline-lite-mode.md` + index row,
`docs/spec-pipeline/coder.md` tier table). Supporting checks, both exit 0:
`scripts/check-orchestration.sh` (“All orchestration references valid.”) and
`scripts/check-skills.sh` (“All SKILL.md files valid (1 warning(s))” — the
warning is the pre-existing `skills/hallmark/SKILL.md` body-length one).

## Verdict

**FAIL** — gate `spot-check`. `scripts/resolve-pipeline-mode.sh` never returns
on the documented relative invocation when the tier is undetectable, so
AC-039-03-04 does not hold in the form callers are told to use. Pipeline stops;
phase 1 attempt 1 of 3. Route the fix to `spec-coder` (behavior failure): make
the tier walk terminate for relative inputs (normalise the spec path to an
absolute one before walking, or stop on `.`), and add a relative-path fixture
to `scripts/tests/ac-039-lite-mode.bats` so the case is covered.

---

# Round 2 — scoped re-verification (attempt 2, phase 1)

- **Attempt:** 2, phase 1 (first re-verification; prior verdict FAIL on `spot-check`)
- **Scope:** only the gate that failed (`spot-check`, the relative-path scenario
  `AC-039-03-04`), plus the two gates whose input the fix changed (`full test
  suite`, `scenario traceability`). Gates 3 and 3.5 stand from attempt 1 and
  were additionally spot-run on `scripts/` as supporting evidence below.
- **Fix under test:** `spec_dir` is canonicalised with `cd -P -- "$dir" && pwd`
  before the tier walk; `detect_tier` returns when `dirname` makes no progress
  (`next == dir`) or bottoms out at `.`; a relative-path bats test with a
  `timeout` guard was added; the stale `(pending Qn)` annotations and the
  lite-inert-without-tier note were fixed.
- **Verdict:** **PASS**.

## Round 2 gate summary

| # | Check | Result |
|---|---|---|
| 1 | Scenario traceability (re-run) | PASS |
| 2 | Full test suite (re-run) | PASS (807/807 `ok`, 0 skips) |
| 3 | Complexity gate (supporting re-run on `scripts/`) | PASS |
| 3.5 | Design-principles gate | stands from attempt 1 (0 FAIL); scoped re-run on `scripts/` also 0 FAIL |
| 4 | Scenario-to-behavior spot check (re-run) | PASS |
| 5 | No unaccounted behavior | finding lines below (not a gate) |

## Evidence: scenario traceability

command: bash scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-05T11:58:23Z

{
  "checks": [1, 2],
  "passes": ["AC-039-01 — traced to a test", "AC-039-02 — traced to a test", "AC-039-03 — traced to a test", "AC-039-04 — traced to a test", "AC-039-05 — traced to a test", "AC-039-06 — traced to a test", "AC-039-07 — traced to a test"],
  "fails": []
}

$ bash scripts/check-scenario-traceability.sh
Scenario IDs found: 7 live, 489 archived

PASS AC-039-01 — traced to a test
PASS AC-039-02 — traced to a test
PASS AC-039-03 — traced to a test
PASS AC-039-04 — traced to a test
PASS AC-039-05 — traced to a test
PASS AC-039-06 — traced to a test
PASS AC-039-07 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

## Evidence: full test suite

command: make test
exit: 0
at: 2026-11-05T11:58:17Z

(Started 2026-11-05T11:58:17Z; finished 2026-11-05T12:05:36Z — 439 s wall
clock. Full log: `/tmp/opencode/039-r2-test.log`.)

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..807
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
[... 801 TAP lines omitted, all `ok` ...]
ok 805 unit: a cap smaller than the marker still never exceeds the cap
ok 806 unit: state exactly at the cap is not truncated and emits no reason
ok 807 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

$ grep -cE '^ok [0-9]+' /tmp/opencode/039-r2-test.log
807
$ grep -cE '^not ok' /tmp/opencode/039-r2-test.log
0
$ grep -cE '^# (skip|SKIP)' /tmp/opencode/039-r2-test.log
0
$ grep -n 'relative spec path' /tmp/opencode/039-r2-test.log
245:ok 240 unit: a relative spec path with an undetectable tier resolves full and terminates

(807 of 807 `ok`; the plan grew from attempt 1's `1..806` by exactly the one new
relative-path test. Zero `not ok`, zero skips.)

## Evidence: complexity gate

command: bash scripts/check-code-principles.sh --gates complexity,dry,yagni,solid,comments,naming,null-discipline --json scripts
exit: 0
at: 2026-11-05T12:06:38Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": [{ "message": "Comments: commented-out code (scripts/check-code-principles.selftest.sh:641)", "file": "scripts/check-code-principles.selftest.sh", "line": "641" }, { "message": "Comments: section-divider comment (scripts/check-code-principles.selftest.sh:639)", "file": "scripts/check-code-principles.selftest.sh", "line": "639" }, [...] }]
}

$ jq '{fails:(.fails|length), warns:(.warns|length), tier}' /tmp/opencode/039-r2-cx.json
{
  "fails": 0,
  "warns": 39,
  "tier": "mvp"
}

$ shellcheck -x scripts/resolve-pipeline-mode.sh scripts/lite-trigger.sh scripts/classify-spec-size.sh
(no output)
$ echo $?
0

(Scoped supporting re-run: the fix touched `scripts/resolve-pipeline-mode.sh`, so
the gates whose input changed were re-run over `scripts/`. 0 FAIL. All 39 WARN
entries are pre-existing comment-heuristic findings in files this spec does not
touch, including the known `classify-spec-size.sh:28` usage-banner false
positive recorded in attempt 1; `[...]` elides the remaining 37 entries of the
verbatim array (full object at `/tmp/opencode/039-r2-cx.json`). `shellcheck`,
the real bash linter, is clean on the changed script.)

## Evidence: scenario-to-behavior spot check

command: timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite
exit: 0
at: 2026-11-05T12:05:44Z

(cwd: `/tmp/opencode/rel39-final` — the same fixture shape attempt 1 used:
`specs/s/10-tasks.md` naming `docs/FOO.md`, `specs/s/20-acceptance/a.md` holding
one scenario, and NO `Conformance tier:` declaration at or above it. This is the
exact command form that hung in attempt 1, run here with the documented relative
path.)

$ timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite
resolve-pipeline-mode: lite mode refused — conformance tier 'undetectable' does not permit it
full
rc=0

$ timeout 5 bash scripts/resolve-pipeline-mode.sh ./specs/s lite
resolve-pipeline-mode: lite mode refused — conformance tier 'undetectable' does not permit it
full
rc=0

$ timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s/ lite
resolve-pipeline-mode: lite mode refused — conformance tier 'undetectable' does not permit it
full
rc=0

$ timeout 2 bash -x scripts/resolve-pipeline-mode.sh specs/s lite 2>&1 | grep -c 'dirname'
7

$ sed -n '1,6p' specs/s/45-decisions.md
Condition: Pipeline mode for /tmp/opencode/rel39-final/specs/s
Options: lite, full
Chosen: full
Why: tier: undetectable refuses lite mode
Reversibility: append a new entry with an explicit lite or full token
At: 2026-11-05T12:05:44Z

(Attempt 1's trace showed 374 unbounded `tier_in_dir .` → `dirname .` steps in
2 s. The bounded walk is now 7 `dirname` calls for the whole run — the five
upward moves from the canonical spec path to `/`, the terminal `dirname /` call
that trips the no-progress guard, and the script's own `SCRIPT_DIR` resolution —
and each of the three invocation forms terminates with exit 0, `full` on stdout,
and one appended decision entry. Three invocations produced exactly three
entries.)

Regression checks on the same fix (the canonicalisation must not break upward
tier detection or the permit path):

    cwd=/tmp/opencode/rel39-mvp            # repo root declares `## Conformance tier: mvp`
    specs/s == `See docs/FOO.md.` + 1 scenario (classifier: lite)

    $ timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s        -> lite  rc=0
    $ timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s full   -> full  rc=0
    $ timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite   -> lite  rc=0
    $ grep '^Chosen:' specs/s/45-decisions.md
    Chosen: lite
    Chosen: full
    Chosen: lite

    $ cd /tmp/opencode/rel39-link                  # alias -> /tmp/opencode/rel39-mvp
    $ timeout 5 bash scripts/resolve-pipeline-mode.sh alias/specs/s lite -> lite rc=0

(An `mvp` declaration above the spec is still found after `cd -P`, for both the
permitting and the refusing branches; a symlinked parent still canonicalises to
the physical path and resolves `lite`.)

### Scenarios checked (re-check of the previously failing one)

- **AC-039-03-04 — Undetectable tier refuses lite.** Scenario: *Given no
  detectable tier / And argv contains `lite` / When mode resolution runs / Then
  resolved mode is `full`.* Test
  `unit: a relative spec path with an undetectable tier resolves full and
  terminates` (`scripts/tests/ac-039-lite-mode.bats:185`) builds the fixture,
  `cd`s into it, and runs the resolver on the **relative** path under
  `timeout 10`; it asserts exit 0, stdout `full`, stderr naming the tier, and
  `Chosen: full` in `45-decisions.md`. A hang is a failure, not a stall: if the
  walk loops, `timeout` returns 124 and the `[ "$status" -eq 0 ]` assertion
  fails. Assertions match the Given/When/Then. Live run above matches the test.
  **PASS.**
- **AC-039-03-05 — MVP permits lite** (neighbour check that the fix did not
  invert the guard). Same fixture with a reachable `mvp` tier: relative path →
  `lite`, exit 0, `Chosen: lite`. Assertions match the scenario. **PASS.**

### Supporting: audit-trail parse of this report (in-flight)

command: bash scripts/check-audit-trail.sh 039-pipeline-lite-mode
exit: 1
at: 2026-11-05T12:07:12Z

PASS 039-pipeline-lite-mode: 10-tasks.md present and non-empty
PASS 039-pipeline-lite-mode: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 039-pipeline-lite-mode: 25-verification.md present and non-empty
FAIL 039-pipeline-lite-mode: missing 30-report.md (AC-015-12)
PASS 039-pipeline-lite-mode: evidence block 'scenario traceability' — command: bash scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-01T16:19:17Z
PASS 039-pipeline-lite-mode: evidence block 'full test suite' — command: make test, exit: 0, at: 2026-11-01T16:19:42Z
PASS 039-pipeline-lite-mode: evidence block 'complexity gate' — command: bash scripts/check-code-principles.sh --gates complexity --json scripts, exit: 0, at: 2026-11-01T16:35:58Z
PASS 039-pipeline-lite-mode: evidence block 'design-principles gate' — command: bash scripts/check-code-principles.sh --json, exit: 0, at: 2026-11-01T16:29:32Z
PASS 039-pipeline-lite-mode: evidence block 'scenario-to-behavior spot check' — command: timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite, exit: 124, at: 2026-11-01T16:35:26Z
✘ Audit-trail check: 1 violation(s).

(The single violation is the expected in-flight state: `30-report.md` is written
by the Mutation Runner after a Verifier PASS, so it cannot exist yet. All five
evidence blocks parse. `check-audit-trail.sh` takes the first block per check,
which is attempt 1's — that is why its parsed spot-check line still shows the
historical exit 124; the current evidence is the Round 2 block above.)

## Round 2 — no unaccounted behavior

(recorded as findings, not a command)

- **Delta is exactly the claimed five files.** `find . -newermt '2026-11-05
  00:00'` returns only: `scripts/resolve-pipeline-mode.sh`,
  `scripts/tests/ac-039-lite-mode.bats`, `docs/spec-pipeline/lite-mode.md`,
  `20-acceptance/AC-039-02-classifier.md`,
  `20-acceptance/AC-039-03-tier-guard.md`. Each maps to the remediation:
  resolver fix → Task 3 / AC-039-03-04; bats test → the same scenario's
  regression guard; the two scenario files and `lite-mode.md` → the WARN fixes
  (stale annotations, inert-without-tier note). Nothing else changed.
- **WARN (not blocking):** `20-acceptance/AC-039-03-tier-guard.md:17` now reads
  `## AC-039-03-03 — Multi-service` — a bare noun after the `(pending Q2)`
  suffix was removed, where its siblings carry a verb (`Production refuses …`,
  `Undetectable tier refuses lite`). Cosmetic, ID-stable, no behavioral
  divergence; flagged to the Architect. The `AC-039-02` header and the
  `AC-039-03-04` title are clean.
- `45-decisions.md` still does not exist for this spec's own run, and this
  Verifier did not create it (out of scope). The resolver now records entries
  correctly for any canonicalisable path (three live entries above), but the
  orchestrator still did not invoke it for `039-pipeline-lite-mode`. Unchanged
  from attempt 1; an orchestrator-side gap, not a code defect.
- Attempt-1 side findings that remain open and unchanged: the
  `pr-opener` read-cost margin (0.498 of a 0.500 budget, 72 bytes) and the
  pre-existing `classify-spec-size.sh:28` comments WARN. Neither is a gate
  failure.

## Round 2 — verdict

**PASS.** All three re-run gates are green with real executions: traceability
exit 0 (`7 live`, `fails: []`), full suite exit 0 (`1..807`, 807 `ok`, 0 skips),
and the previously failing spot check now terminates and resolves `full` for
the documented relative invocation, matching AC-039-03-04's assertions. Gates 3
and 3.5 stand from attempt 1 (0 FAIL) and were re-run over `scripts/` with 0
FAIL. Phase 1 attempt 2 of 3; no budget exhaustion. The pipeline may proceed to
stage 5a (Mutation Runner).

## Quality gates

# 039 — Pipeline lite mode: mutation and final report

- **Stage:** 5a, Mutation Runner.
- **Worktree:** `/home/dbueno/.local/share/opencode/worktree/471827/spec-039` (detached HEAD, `f0188e6`).
- **Pipeline mode for this run:** `full` — carried from `25-verification.md` attempt 2. No `Conformance tier:` declaration exists, so the tier guard refuses `lite`; independently the classifier returns `full` (`Reason: 7 files named under scripts/ — lite allows at most one`). All stages run, including this one.
- **Conformance tier:** `mvp` (repo declares no tier; `mvp` is the floor per `docs/CONFORMANCE_TIERS.md`).
- **Mutation score:** **skipped — `mvp` tier** (`production`-tier gate, not run by policy; see §Evidence: mutation score).
- **Final test status:** **PASS — 807/807 `ok`, 0 `not ok`, 0 skips** (`make test`, exit 0).
- **Report verdict:** **GREEN**.

## Verifier verdict (carried forward, not re-derived)

`25-verification.md` attempt 2 (phase 1) reads:

- `- **Verdict:** **PASS**.` (§Verdict, round 2)
- Gate summary: traceability PASS, full suite PASS (807/807 `ok`, 0 skips), complexity PASS, design-principles PASS (0 FAIL), scenario-to-behavior spot check PASS.
- Attempt 1 (`FAIL`, gate `spot-check`) is historical: the relative-path non-termination in `scripts/resolve-pipeline-mode.sh` was fixed and re-verified in round 2.

This stage treats that verdict as the precondition, not as its own result. It re-ran the
full suite independently below because the Verifier's PASS predates this stage.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-11-05T12:14:41Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

Per `docs/SPEC_PIPELINE.md §Conformance tiers` and `docs/spec-pipeline/coder.md
§Conformance tiers`, mutation testing is a `production`-tier gate. This repo
declares no tier, so the ruling is `mvp` and mutation testing is a recorded
skip, not a gap.

Tier evidence:

```
$ shopt -s nullglob; files=(AGENTS.md AGENTS_*.md); grep -rn "Conformance tier: production" "${files[@]}"
(no output)
exit: 1

$ grep -rn "Conformance tier: mvp" "${files[@]}"
(no output)
exit: 1
```

Neither `mvp` nor `production` is declared anywhere at the repo root, which is
exactly the state `docs/spec-pipeline/lite-mode.md` documents as "lite is inert
here by design" (an undeclared repo is treated as possibly production). The
`make mutation` target's own tier probe and the design-principles gate's
`"tier": "mvp"` (recorded in `25-verification.md`, both attempts) agree.

Secondary confirmation that no mutation engine could run even at a higher tier:
this change set is bash + markdown + bats. Changed-path extensions are `19 md`,
`3 sh`, `2 bats`, `1 bash`, `1 jsonl` (`runs.jsonl` telemetry), plus the
untracked `specs/` folder. There is no `pom.xml`, `package.json`, `go.mod`,
`stryker.conf.*`, or `gremlins.yaml` in the tree — no PiTest, gremlins, or
Stryker target exists to point at the change. Per the stage instruction this
tooling gap is reported, not used to block.

### Equivalent mutants

**None.** No mutation engine ran, so no mutant was generated, survived, or was
judged equivalent. There is no un-killable-mutant list to name. No mutation-kill
tests were written, so this stage added no test code to the suite.

## Complexity summary (carried from the Refactorer)

The Refactorer leaves no report artifact by design (`docs/SPEC_PIPELINE.md
§What each stage leaves behind`), and the orchestrator's loop summary carries no
per-function complexity table for this run. Nothing is invented here; the
values below are the ones the Verifier re-recorded, plus this stage's own
scoped re-measurement.

- **Verifier's re-recorded complexity (attempt 2, scoped to `scripts/`):** 0 FAIL,
  39 WARN, all pre-existing comment-heuristic findings in files this spec does
  not touch; `shellcheck -x` clean on the three new scripts.
- **This stage, `scripts/check-code-principles.sh --gates complexity --json scripts`:**
  `{"tier":"mvp","gates":["complexity"],"fails":[],"warns":[]}` — exit 0.
- **Refactorer's one recorded structural change** was behavior-preserving:
  `scripts/tests/ac-031-doc-section.bash` extracted `section_of` out of
  `section`; the ac-031 bats files were untouched and re-ran 78/78 `ok`
  (`25-verification.md` attempt 1, §no unaccounted behavior).

## Evidence: final test status

command: make test
exit: 0
at: 2026-11-05T12:22:34Z

```
Checking bats assertions are not vacuous...
PASS check-bats-assertions: 77 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..807
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
[... 804 TAP lines omitted, all `ok` ...]
ok 807 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
```

```
$ grep -m1 -E '^1\.\.' /tmp/opencode/039-r3-final-test.log
1..807
$ grep -cE '^ok [0-9]+' /tmp/opencode/039-r3-final-test.log
807
$ grep -cE '^not ok' /tmp/opencode/039-r3-final-test.log
0
$ grep -cE '^# (skip|SKIP)' /tmp/opencode/039-r3-final-test.log
0
$ grep -n 'relative spec path' /tmp/opencode/039-r3-final-test.log
245:ok 240 unit: a relative spec path with an undetectable tier resolves full and terminates
```

Started `2026-11-05T12:22:34Z`, finished `2026-11-05T12:29:39Z` (425 s wall
clock). This run was made *after* `30-report.md` was written, so the recorded
final status matches the exact artifact state the PR Opener will see. 807 of 807
`ok`; the single `not ok` substring is part of the *name* of an existing passing
test (`AC-001-02`), not a failure — `grep -cE '^not ok'` is 0. The relative-path
regression test added by the phase-1 fix is present and green.

An earlier independent run on the same source tree (before the report existed,
`2026-11-05T12:14:44Z` → `12:21:44Z`, log
`/tmp/opencode/039-r3-test.log`) produced the same result: `1..807`, 807 `ok`,
0 `not ok`, 0 skips, exit 0. Two consecutive green runs, identical plan.

Because mutation testing was skipped, this stage added no tests; the full suite
here is the same plan the Verifier saw (`1..807`), re-executed independently
after the Verifier's run.

## Evidence: read-cost gate (supporting, WARN)

command: bash scripts/measure-stage-read-cost.sh
exit: 0
at: 2026-11-05T12:22:02Z

```
Stage read cost — baseline 50836 bytes, budget 50% (= 25418 bytes)
stage               bytes   ratio  verdict
specifier           15092   0.296  ok
ux                  14315   0.281  ok
coder               16286   0.320  ok
refactorer          14317   0.281  ok
verifier            22250   0.437  ok
mutation-runner     21414   0.421  ok
pr-opener           25346   0.498  ok
deployer            16483   0.324  ok
```

Gate is green (exit 0), but `pr-opener` sits at **0.498 of the 0.500 ceiling —
72 bytes of headroom**. `docs/spec-pipeline/pr-opener.md` gained a `## Lite mode`
section in this change set. The next line added to that file, or to its
`Must read` set, flips the gate red. Recorded as a WARN for the Architect /
next spec; not a FAIL, not fixed here.

## Evidence: audit-trail gate (supporting)

command: bash scripts/check-audit-trail.sh 039-pipeline-lite-mode
exit: 0
at: 2026-11-05T12:29:51Z

```
PASS 039-pipeline-lite-mode: 10-tasks.md present and non-empty
PASS 039-pipeline-lite-mode: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 039-pipeline-lite-mode: 25-verification.md present and non-empty
PASS 039-pipeline-lite-mode: 30-report.md present and non-empty
PASS 039-pipeline-lite-mode: 45-decisions.md optional without an 'Autopilot: true' marker (AC-035-35)
PASS 039-pipeline-lite-mode: evidence block 'scenario traceability' — command: bash scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-11-01T16:19:17Z
PASS 039-pipeline-lite-mode: evidence block 'full test suite' — command: make test, exit: 0, at: 2026-11-01T16:19:42Z
PASS 039-pipeline-lite-mode: evidence block 'complexity gate' — command: bash scripts/check-code-principles.sh --gates complexity --json scripts, exit: 0, at: 2026-11-01T16:35:58Z
PASS 039-pipeline-lite-mode: evidence block 'design-principles gate' — command: bash scripts/check-code-principles.sh --json, exit: 0, at: 2026-11-01T16:29:32Z
PASS 039-pipeline-lite-mode: evidence block 'scenario-to-behavior spot check' — command: timeout 5 bash scripts/resolve-pipeline-mode.sh specs/s lite, exit: 124, at: 2026-11-01T16:35:26Z
✔ Audit-trail check: specs/039-pipeline-lite-mode complete, verifier evidence recorded.
```

The gate is green. Its parsed spot-check line shows attempt 1's historical
`exit: 124` because `check-audit-trail.sh` takes the **first** block per check
name and `25-verification.md` carries attempt 1 before round 2; the current
evidence is round 2's `exit: 0` block (`at: 2026-11-05T12:05:44Z`). The gate
therefore passes on a folder whose printed spot-check evidence is a superseded
FAIL — see WARN 6.

## WARNs flagged to the Architect (not FAILs, not fixed)

1. **Read-cost headroom is 72 bytes** on `pr-opener` (0.498 / 0.500). This
   change set added the `## Lite mode` section to that stage document. The next
   addition to it, or to its Must-read set, breaks the gate.
2. **Lite mode is inert in this repo until a tier declaration exists.** No
   `Conformance tier:` heading is reachable from `specs/039-pipeline-lite-mode`,
   so the guard refuses `lite` on every run and the classifier independently
   returns `full`. That is the documented conservative behavior (an undeclared
   repo is treated as possibly production), not a defect — but it means this
   spec's feature cannot activate here until someone adds
   `## Conformance tier: mvp`, and no pipeline run exercises the lite path end
   to end. The lite path is covered by tests and document assertions only.
3. **`specs/039-pipeline-lite-mode/45-decisions.md` does not exist.** The
   orchestrator never invoked `scripts/resolve-pipeline-mode.sh` for this
   spec's own run (unchanged from both Verifier attempts). The resolver writes
   correct entries when called (three live entries reproduced by the Verifier);
   the gap is orchestrator-side wiring. This stage did not create the file
   (out of scope, and inventing a resolution record would falsify the audit
   trail).
4. **Cosmetic:** `20-acceptance/AC-039-03-tier-guard.md:17` title is a bare noun
   (`## AC-039-03-03 — Multi-service`) after the `(pending Q2)` suffix was
   removed; siblings carry verbs. ID-stable, no behavioral divergence.
5. **Heuristic false positive:** `scripts/classify-spec-size.sh:28` is flagged
   as commented-out code; it is the exit-code line of the script's own usage
   banner. 0 FAIL, recorded per contract.
6. **Tooling observation (out of scope, follow-up candidate):**
   `scripts/check-audit-trail.sh` takes the first evidence block per check name.
   After a phase-1 remediation rewrites the same check, the gate reports the
   superseded block — here it prints `spot check … exit: 124` (attempt 1's
   FAIL) while passing. It never inspects the exit code, so this does not
   mask a regression today, but the printed line misrepresents current evidence.
   Proposed follow-up: parse the last block per check, or assert `exit: 0`.

## Remediation record

One BLOCK occurred during this spec's run, before this stage:

| BLOCK | Phase | Resolved at attempt | Evidence |
|---|---|---|---|
| Gate `spot-check` FAIL — `scripts/resolve-pipeline-mode.sh` never returns on the documented relative invocation when the tier is undetectable (AC-039-03-04 violated) | 1 (pre-PR) | **attempt 2 of 3** | `25-verification.md` attempt 1 §Verdict (`FAIL`, route to `spec-coder`); round 2 (`attempt 2, phase 1`) `PASS` after the canonicalisation fix + relative-path bats regression test. `runs.jsonl` loop summary agrees: `247cedc9…` `outcome: fail`, `loopCount: 1`, `phase1Retries: 0` → `a63e512c…` `outcome: pass`, `loopCount: 2`, `phase1Retries: 1`. |

No phase-2 (post-PR) or phase-3 (deploy) BLOCK exists yet — the PR is not open,
so those loops have not run. Budgets not exhausted (1 of 3 phase-1 attempts used
beyond the original run).

This stage (5a) itself raised no BLOCK: mutation testing is a policy skip and
the final suite is green.

## Working tree state

`git status --porcelain` is dirty, and every dirty path belongs to this spec's
change set or its telemetry — the expected pre-commit state for stage 5a, left
untouched for the PR Opener (stage 5b):

- modified: `agents/spec-pipeline.md`, `commands/build.md`, `docs/SPEC_PIPELINE.md`,
  `docs/adr/README.md`, `docs/spec-pipeline/{coder,pr-opener,verifier}.md`,
  `scripts/tests/ac-031-doc-section.bash`, `runs.jsonl` (orchestrator telemetry)
- untracked: `docs/adr/0020-pipeline-lite-mode.md`,
  `docs/spec-pipeline/lite-mode.md`, `scripts/{classify-spec-size,lite-trigger,resolve-pipeline-mode}.sh`,
  `scripts/tests/ac-039-{lite-mode,lite-wiring}.bats`, `specs/`

Nothing was stashed, committed, pushed, or opened as a PR by this stage. No
gate threshold was changed.

## Verdict

**GREEN.** Verifier PASS carried forward; mutation score `skipped — mvp tier`
with the tier ruling evidenced; no equivalent mutants exist to name; the full
suite re-ran green at 807/807 with 0 failures and 0 skips; the only findings are
the six non-blocking WARNs above. Stage 5b (the PR Opener) may proceed.

## PR

PR: https://github.com/RexiAI/my-engineering-standards/pull/114
Commits: 9

## 40-deploy.md

# 039 — Pipeline lite mode: deploy verification

- **Stage:** 5c, Deploy Verifier.
- **Draft PR:** https://github.com/RexiAI/my-engineering-standards/pull/114
- **Repo class:** non-frontend — no `vercel.json`, no `package.json` declaring a frontend framework dependency, and no connected Vercel Git integration. This is a standards/documentation repository; there is no deploy lane.
- **Deploy URL:** not applicable — deploy verification does not apply to this repo.
- **Build status:** SKIPPED
- **Health check status:** SKIPPED
- **E2E verdict:** SKIPPED
- **Phase-3 attempt count:** 0
- **At:** 2026-11-05T12:32:19Z

## Verdict

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

No `vercel deploy` was run. No deployment was created or observed. Stage 5d (the
Archiver) may proceed.
