# Verification — 017 CI Sweeper loop

**Stage 4 (Verifier)** — spec `017-ci-sweeper-loop`, branch `spec/017-ci-sweeper-loop`.
Verified against `10-tasks.md` and `20-acceptance/` only. `00-informal.md` not read.
Change set under test (branch tip = `main` tip 3013d8d; deliverables uncommitted
working-tree changes, staged by stage 5b): `M .github/workflows/self-ci.yml`,
`?? .github/workflows/ci-sweeper.yml`, `?? scripts/check-ci-sweeper.sh`,
`?? scripts/install-opencode.sh`, `?? skills/ci-triage/SKILL.md`.

---

## 1. Scenario traceability — PASS (AC-017 scope clean)

**Command:** `bash scripts/check-scenario-traceability.sh` (script not executable —
mode `-rw-r--r--`; invoked via `bash`; per self-ci it is `bash`-invoked too).

- **Full-repo exit code: 1** (126 violations). Every violation is a sibling-spec
  artifact, none from 017: AC-007-01..AC-014-04 "scenario defined but no test
  references it" (in-flight specs whose tests do not exist yet) and AC-020/021/022
  "referenced in a test but no matching scenario heading" (stale citations from
  already-archived specs). Known mid-pipeline condition, as expected.
- **AC-017-scoped result:** all 5 groups traced, zero dangles:
  - `PASS AC-017-01 — traced to a test`
  - `PASS AC-017-02 — traced to a test`
  - `PASS AC-017-03 — traced to a test`
  - `PASS AC-017-04 — traced to a test`
  - `PASS AC-017-05 — traced to a test`
  - No `AC-017` appears in any FAIL/dangling line of the full run.
- **26 sub-IDs:** 6+6+6+4+4 = 26 (`AC-017-01-01…06`, `02-01…06`, `03-01…06`,
  `04-01…04`, `05-01…04`), matching the Coder's count. The sub-ID level is carried
  by `scripts/check-ci-sweeper.sh`'s own citation array (all 26 present) — verified
  independently by reading the array and confirmed by check 2's `AC-017-05-02`
  PASS line.

Judgment: AC-017 scope is clean; the exit 1 is entirely sibling-spec noise.

## 2. Full relevant suite — PASS

All commands executed locally; exit codes real.

| Command | Result |
|---|---|
| `bash -n scripts/check-ci-sweeper.sh` | exit 0 |
| `bash -n scripts/install-opencode.sh` | exit 0 |
| `bash -n` over all `scripts/*.sh templates/*.sh` | exit 0 (no parse failures) |
| `./scripts/check-ci-sweeper.sh` | **exit 0 — 26 PASS, 0 FAIL** (exactly the claimed 26) |
| `./scripts/check-ci-sweeper.sh --self-test` | **exit 0** — `PASS AC-017-05-03: --self-test — gate fails closed on a broken fixture` |
| `scripts/check-orchestration.sh` | exit 0 — "All orchestration references valid." |
| `make validate-all` | exit 0 — all 35 required files + cross-refs valid; SKILL.md scan passes with only the pre-existing `skills/hallmark` >500-line WARN |
| `make lint` | exit 0 — YAML validation includes `.github/workflows/ci-sweeper.yml [OK]` and `self-ci.yml [OK]` |
| `scripts/check-loop-files.sh` | exit 0 — all AC-016 PASS lines; loop foundation files present (016 landed) |
| `scripts/check-skills.sh` | exit 0 — `skills/ci-triage` compliant; only pre-existing hallmark WARN |

**Workflow parse + trigger + permissions (PyYAML, `yaml.safe_load`):**
- `.github/workflows/ci-sweeper.yml` and `.github/workflows/self-ci.yml` both parse.
- Trigger (dumped via the boolean `on` key PyYAML 1.1 produces):
  `{"workflow_run": {"workflows": ["Self CI"], "types": ["completed"]}}`
- Job gate: `if: ${{ github.event.workflow_run.conclusion == 'failure' }}` — green
  runs skipped, no-op (AC-017-03-02).
- Permissions (parsed object): `{"contents": "read", "actions": "read", "issues": "write"}`
  — exactly least-privilege; no `contents: write`, no `pull-requests: write`, no
  `id-token: write`; no `gh pr merge`, no auto-merge step; `persist-credentials:
  false` on checkout (AC-017-03-05). No tags, no push to main anywhere.
- Context passed into the sweep: env `SWEEPER_RUN_ID`, `SWEEPER_HEAD_SHA`,
  `SWEEPER_HEAD_BRANCH` from `github.event.workflow_run.{id,head_sha,head_branch}`;
  checkout pinned to `ref: workflow_run.head_sha` (AC-017-03-03).
- Self-ci wiring: new step `Check CI sweeper deliverables` (runs the script + its
  `--self-test`) sits directly after the CRLF check and before `bash -n`, not
  `continue-on-error` — matches AC-017-05-04 "alongside the existing CRLF and
  YAML-syntax checks".

## 3. Complexity gate — PASS

This repo has no language linter for bash (no golangci/pmd/eslint); the
mechanical complexity gate is `check-code-principles.sh` (run in 3.5 — it flagged
nothing in the 017 files). Manual decision-point count of every function in the
changed bash scripts:

- `scripts/check-ci-sweeper.sh`: `fail()` CC 1, `pass()` CC 1, `verify_grep()` CC 3
  (1×for + 1×if), `self_test()` CC 2 (2×if) — all ≤3, claim holds.
- `scripts/install-opencode.sh`: no functions, straight-line under `set -euo
  pipefail` — CC 1.
- **Pin in one place:** `VERSION="v1.18.18"` occurs exactly once in the change set
  (`scripts/install-opencode.sh:14`); no literal version in either workflow.
- **Shared install script:** both workflows invoke `bash scripts/install-opencode.sh`
  (`self-ci.yml:101`, `ci-sweeper.yml:46`); self-ci's inline curl/tar block was
  removed in favor of the shared script (visible in the diff). The Refactorer's
  extraction claim holds, and `model-env.runtime-check.sh /tmp/opencode-bin/opencode`
  still resolves because the shared script installs to `/tmp/opencode-bin`.

## 3.5. Design-principles gate — exit 1, all FAIL/WARN pre-existing, none from 017

**Command:** `bash scripts/check-code-principles.sh` (default mode, repo root, tier
auto-detected).

**Exit code: 1** — `✘ Design-principles check: 5 FAIL(s), 17 WARN(s).`

Every FAIL and WARN line, verbatim (paths all under `ci/templates/`):

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
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

**Judgment:** zero 017 files appear in any FAIL/WARN line — the 5 FAILs and all 17
WARNs are confined to `ci/templates/*` (saga/outbox gate templates from a prior
spec, untouched by 017). This is exactly the known pre-existing repo-root state.
**No FAIL/WARN is attributable to spec 017.** The exit 1 therefore does not stop
this pipeline; it is recorded state for the Architect.

Also confirmed: tier auto-detected `mvp` (`Checking design principles in: . (tier:
mvp)`), property tests skipped (`Property tests: skipped (project tier is mvp —
production+ required)`) — correct for this repo (no `AGENTS_*.md`; see check 5).

## 4. Scenario-to-behavior spot check — PASS (4 scenarios + negative fixture)

Picked at random from `20-acceptance/` and matched against the artifacts:

**AC-017-01-02 (failing-log read grounded)** — `skills/ci-triage/SKILL.md:21-28`:
the exact two commands `gh run list --workflow "Self CI"` then
`gh run view <RUN-ID> --log-failed` (order: list, then view), names the **Self CI**
workflow and its single job **Validate**. Matches the Given/When/Then fully.

**AC-017-02-03 (max-3 own circuit breaker)** — `SKILL.md:86-90`: "at most **3
attempts** per failure", "Each attempt is recorded in `loop-run-log.md` (spec
016's append-only file, one `run_id` per failure)", "This counter is the loop's
own **circuit breaker**, independent of spec 008's pipeline budget and 014's
round counter". The 008/014 independence is stated in the loop's own file — not
borrowed from 008/014. Matches.

**AC-017-03-05 (least-privilege)** — `.github/workflows/ci-sweeper.yml:20-23` and
the parsed PyYAML permissions object: exactly `contents: read`, `actions: read`,
`issues: write`; no merge, no push-to-`main`, no tag capability, no auto-merge
step anywhere in the file (also asserted by the script's BROADER scan, PASS in the
26). Matches.

**AC-017-03-04 (headless opencode sweep)** — the `Sweep the failing run with the
ci-triage skill` step runs `/tmp/opencode-bin/opencode run --print-logs` with a
prompt that loads `skills/ci-triage` and carries the failing-run context; no
`--auto` flag (comment: "the sweep is L1 report-only"). Matches, including
AC-017-03-06's L1/report-only documentation.

**Negative fixture (fails closed, then cleaned):** built a temp fixture copying the
real script/self-ci/workflow and a skill with the exact phrase `never auto-fix`
replaced by `never under any circumstances auto-fix` (0 exact occurrences).
Result:
```
NEG_FIXTURE_EXIT=1
FAIL AC-017-01-05: flake rule: Watch, never auto-fix — missing: never auto-fix
PASS_COUNT=25
```
The gate flags the injected wrong string precisely and exits non-zero — a false
green is impossible. Fixture removed afterwards (`rm -rf`); verified gone.

## 5. No unaccounted behavior — PASS (with notes)

Diff skim: every changed/added file traces to tasks 1–5:
- `skills/ci-triage/SKILL.md` — tasks 1, 2, 4 (frontmatter `name: ci-triage`,
  `allowed-tools: Bash(gh:*) Bash(git worktree add:*)` matching the demonstrated
  `Bash(<pattern>:*)` precedent; `check-skills.sh` validated it, exit 0).
- `.github/workflows/ci-sweeper.yml` — task 3; `scripts/check-ci-sweeper.sh` —
  task 5; self-ci.yml hunks — task 5 wiring + shared-install refactor.
- `scripts/install-opencode.sh` — helper extracted from self-ci's pre-existing
  inline curl/tar block; task 3 explicitly leaves "install/runner plumbing" to the
  Coder, so this is accounted-for helper behavior, not scope creep.

**`docs/ci-flakes.md` absence (Refactorer note, confirmed):** the skill cites it
as the flake-quarantine ledger (`SKILL.md:56-59`, "append the flake signature …
to the quarantine ledger `docs/ci-flakes.md`") but the file does not exist.
Judgment: **consistent with the task text.** No acceptance scenario requires the
file to exist now — AC-017-01-04 requires the flake criteria ("seen before …
already in the quarantine ledger") and AC-017-02-05 requires enumerating
"intermittent flakes needing quarantine" as an escalation condition; both are
satisfied by the skill's wording. `10-tasks.md` open question 4 names
`docs/ci-flakes.md` as the *assumed* ledger name and asks for human confirmation;
the skill committing to that name is write-on-first-use, not a missing
deliverable. Review note for the Architect: record the open-question-4 answer
(ledger name) in `30-report.md` / the archive so the named file is not
surprising post-merge.

**mvp-tier claim confirmed:** no `AGENTS_*.md` exists at the repo root (glob
`AGENTS_*.md` — none), and `check-code-principles.sh` auto-detected `tier: mvp`
and skipped the property-test gate. The property-test/mutation skips in
Refactorer/Architect are correct.

**Open-question resolutions observed in the implementation (recorded, all
consistent with 10-tasks.md's stated recommendations):** (1) agent-in-CI model (a)
— `opencode run` executes on the Actions runner; (2) escalation surface = GitHub
issue with stable label `ci-sweeper`; (3) 017 creates no `STATE.md`/`loop-run-log.md`
— state contract lives in the skill only, loop runs at L1; (5) max-3 is the loop's
own counter (verified in check 4).

---

## Overall verdict: **PASS** — Architect may proceed

Reasons:
1. AC-017 traceability clean (all 5 groups traced, 26 sub-IDs cited, no dangles);
   full-repo exit 1 is sibling-spec noise only.
2. Full suite green: check-ci-sweeper 26/26, self-test fails-closed, orchestration,
   validate-all, lint, loop-files, skills check, PyYAML parse, trigger gating, and
   least-privilege permissions all verified by execution.
3. Complexity ≤3 on every changed function; single-sourced pin; shared install
   script — Refactorer claims hold under inspection.
4. Design-principles gate exit 1 is pre-existing `ci/templates/*` state; zero
   FAIL/WARN attributable to spec 017.
5. Spot-checked scenarios match their Given/When/Then; negative fixture proves the
   gate fails closed (cleaned up).
6. No unaccounted behavior; `docs/ci-flakes.md` write-on-first-use is consistent
   with tasks (Architect review note above); mvp tier confirmed.

Verifier: spec-verifier (stage 4). Writes: this file only.
