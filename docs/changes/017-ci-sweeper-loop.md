# 017-ci-sweeper-loop

> Spec pipeline archive. Original source: `specs/017-ci-sweeper-loop/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# CI Sweeper loop (react to failing CI, diagnose, propose, escalate)

A loop that watches CI on this repo's branches and PRs, reacts to failures
quickly, proposes minimal fixes, and escalates when it can't confidently resolve.
Brings the ci-sweeper pattern from cobusgreyling/loop-engineering.

## What it must provide

1. **Trigger.** GitHub Actions self-ci on push + PR; the loop reacts to a failing
   run on a feature branch or PR. Event-driven (workflow_run on failure) or a
   short-cadence scheduled `opencode run` (cron/systemd) — choose the mechanism
   that exists in this repo, do not invent a scheduler.

2. **Triage skill.** `skills/ci-triage/SKILL.md` — parse the failing job's logs,
   identify failing job/step, classify the failure: flake vs real regression vs
   infrastructure vs config. Flake (seen before, intermittent, passed on retry
   with no code change) → Watch, never auto-fix.

3. **Minimal fix.** Only the smallest change that addresses the specific failure.
   In an isolated worktree; verifier checks: fix addresses the failure, no
   unrelated changes, tests/lint pass.

4. **Bounded remediation.** Circuit breaker per failure: max 3 attempts, tracked
   in `loop-run-log.md` (or loop-ledger.json). Same failure recurs N× or attempts
   exceed max → escalate to human with pruned context, never loop forever.

5. **Escalation conditions.** Infrastructure failure (runner OOM, registry down,
   secrets missing), failure touching >5 files or core architecture, security
   sensitive, max attempts exceeded, intermittent flakes needing quarantine.

6. **State.** `STATE.md` CI Sweeper section: last run, failing commit SHA, failing
   job, attempt count, worktree/PR link, outcome. Prune resolved failures.

## Acceptance criteria

- AC-001: a CI-triage skill exists with the classify output format (flake /
  regression / infra / config) and the flake rule (never auto-fix).
- AC-002: the loop reacts to a failing CI run — the trigger mechanism is named
  and wired in this repo's `.github/workflows/`.
- AC-003: fix attempts run in an isolated worktree and are verified by a separate
  checker before proposing a PR/comment.
- AC-004: remediation is bounded (max 3 attempts per failure); exhaustion
  escalates to the human with the failing job + last log evidence.
- AC-005: STATE.md CI Sweeper section is updated each run and pruned on resolve.
- AC-006: cost guidance documented (early exit when CI is green; no full sweep on
  a no-op run).

## Tasks

# Tasks — CI Sweeper loop (react to failing CI, diagnose, propose, escalate)

Formalization of `specs/017-ci-sweeper-loop/00-informal.md`. Goal: a standalone,
recurring loop that watches the repo's CI on its branches and PRs, reacts to
failures, triages them (flake vs regression vs infra vs config), proposes minimal
fixes from an isolated worktree, and escalates to a human when it cannot resolve
confidently. The loop is event-driven from GitHub Actions — the only automation
surface this repo has — and builds on spec 016's loop foundation files and safety
rules without re-specifying them. This is a prompts/docs + workflow spec: it adds
one skill, one workflow, and one check script; it adds no new agent and no new
scheduler.

## Grounded reality (verified against this repo)

- **Which CI fails, and when.** The repo's only CI that runs on a feature branch
  or its PR is `.github/workflows/self-ci.yml`, workflow name **Self CI**. Its
  `on:` block triggers on `push` (branches `**`) and `pull_request` (branches
  `**`), so every branch push and every PR — including `spec/NNN-slug` pipeline
  branches — starts a Self CI run. It has a single job, `Validate`: committed-blob
  CRLF check, `bash -n` over `scripts/*.sh templates/*.sh`, `make validate-all`,
  `make lint`, shellcheck (continue-on-error), and a YAML-syntax check over
  `.github` and `ci`. `.github/workflows/release.yml` fires only on push to
  `master`, and `.github/workflows/archive-spec.yml` only on `pull_request:
  closed` to `main` — neither runs on a feature branch or PR. So "failing CI on
  this repo's branches/PRs" means a failing Self CI run.
- **The trigger mechanism that exists here.** GitHub Actions is the repo's only
  automation surface. There is no cron, no systemd unit, no external scheduler in
  this repo. Therefore the event-driven mechanism is a `workflow_run` trigger in a
  new `.github/workflows/ci-sweeper.yml` reacting to the **Self CI** workflow's
  `completed` event, gated to `conclusion == 'failure'`. This uses the mechanism
  that exists; a scheduled `opencode run` on cron/systemd would invent a scheduler
  this repo does not have.
- **The failing-log read that exists here.** `gh` CLI (v2.96.0) is installed and
  authenticated against `github.com` with `repo` scope (established in spec 014);
  remote is `git@github.com:RexiAI/my-engineering-standards.git`. Failing logs
  come from `gh run list --workflow "Self CI"` then `gh run view <RUN-ID>
  --log-failed`. This is the same read 014 grounds; 017 reuses it, not a new tool.
- **`workflow_run` reads the trigger from the default branch.** A workflow with a
  `workflow_run` trigger only activates after its own file is merged to `main`; it
  cannot be exercised on the PR that introduces it. This is a real constraint and
  is stated in the task so the sweeper's first effective run is post-merge.
- **Skill format.** `skills/<name>/SKILL.md` carries YAML frontmatter
  (`name`, `description`, `license`, `allowed-tools`) and sections such as "When
  to use", "Invocation", and a "What it does" body. Precedent: `skills/bootstrap`,
  `skills/check-principles`. `skills/ci-triage/` does not exist yet.
- **Spec 016 is NOT built.** `specs/016-loop-engineering-foundation/00-informal.md`
  exists but has no `10-tasks.md`; `docs/LOOP_ENGINEERING.md`, `STATE.md`,
  `loop-run-log.md`, and `loop-budget.md` do not exist anywhere in the repo. 016's
  informal defines those files and the safety rules: `STATE.md` durable loop state
  (prune resolved items each run), `loop-run-log.md` append-only JSON
  `{ run_id, pattern, duration_s, items_found, actions_taken, escalations,
  tokens_estimate, outcome }` pruned after 30 days, `loop-budget.md` token caps,
  readiness levels L0–L3, "a new pattern never skips L1 on a production repo",
  path denylist, and default no auto-merge. **017 consumes these by reference and
  must not re-specify them.** Consequence: until 016 lands, the sweeper has no
  `STATE.md` or `loop-run-log.md` to write, so it operates at **L1 (report only)**
  — it triages and reports, and does not run unattended fixes.
- **Relationship to spec 014.** 014 is the pipeline-integrated, synchronous
  post-PR CI check: the Verifier queries CI inside `/build`, the Coder/Refactorer
  fix, the loop is bounded, and the verdict lands in `25-verification.md`. 017 is
  the standalone **recurring** sweeper: a separate cadence, its own triage skill,
  worktree-based fixes, and `STATE.md` tracking. Boundary: the sweeper owns CI
  failures 014's pipeline never handled (any run after the pipeline ended), and it
  defers when `STATE.md` shows an in-flight remediation of the same failure on the
  same branch — no double-handling of a `spec/NNN-slug` branch 014 is already
  fixing. 017's **max 3** is the loop's own circuit breaker, independent of both
  014's round counter and spec 008's pipeline budget (008 defines the budget for
  the pipeline; 017 does not restate it).
- **Traceability precedent.** Docs-content specs are validated by a shell check
  script wired into self-ci that carries the AC-NNN-NN IDs and greps the required
  strings in the touched files (016's AC-005 names `scripts/check-loop-files.sh`;
  014 open question 1 proposes the same shape). 017's is
  `scripts/check-ci-sweeper.sh`. It doubles as the traceability citation for the
  scenario IDs, satisfying `scripts/check-scenario-traceability.sh`.
- **Escalation surface.** The repo's human handoff channel is GitHub. The
  recommended escalation artifact is a GitHub issue carrying pruned context
  (failing job name, run link, last log excerpt). Confirmed as an open question
  below.
- **No version tags, no direct push to main, no auto-merge.** AGENTS.md forbids
  direct push to `main`/`master` and manual tag creation; 016's safety rules forbid
  auto-merge by default. The sweeper workflow's token is least-privilege
  (`contents: read`, `actions: read`, `issues: write`) and never carries merge or
  push-to-main powers.

## Tasks

### Task 1 — Create `skills/ci-triage/SKILL.md`: failure classification and the flake rule

Create the triage skill that parses a failing Self CI run's logs and classifies
the failure. This is the loop's entry point.

Acceptance criteria:
- `skills/ci-triage/SKILL.md` exists with repo-convention frontmatter
  (`name: ci-triage`, `description`, `license`, `allowed-tools` following the
  demonstrated `Bash(<pattern>:*)` form of existing skills) and "When to use" /
  "Invocation" sections.
- The skill names the failing-log read used by this repo: `gh run list --workflow
  "Self CI"` then `gh run view <RUN-ID> --log-failed`, and notes the Self CI
  workflow has a single job, `Validate`.
- The skill defines a classification output with exactly one of the four classes
  `flake` / `regression` / `infra` / `config`, plus the failing job/step and the
  evidence (log line, file:line, or step name) that drove the classification.
- The skill gives a decision guide for the four classes, with the flake criteria
  (seen before, intermittent, passed on retry with no code change) stated.
- The skill states the flake rule verbatim: flake → **Watch**, **never auto-fix**;
  a flake is logged and routed to quarantine, not fixed.
- The skill states that `infra` and `config` failures are not code defects
  (runner OOM, registry down, secrets missing, workflow syntax) and are routed to
  escalation, never "fixed" by editing code.

Scenarios: `20-acceptance/AC-017-01-ci-triage-skill.md`

### Task 2 — Extend `skills/ci-triage/SKILL.md`: isolated fix flow and bounded remediation

Add the sweep's fix-and-remediate procedure to the same skill: minimal fix in an
isolated worktree, a separate checker, and the loop's own circuit breaker.

Acceptance criteria:
- The skill states fixes are the smallest change that addresses the specific
  failure and are made in an isolated worktree (`git worktree add`), never on the
  branch being swept and never on `main`.
- The skill states a maker/checker split: the fixing pass (maker) and a separate
  checking pass (checker) are distinct; the checker confirms before any PR or
  comment is proposed that (a) the fix addresses the failure, (b) there are no
  unrelated changes, and (c) tests and lint pass (local suite plus `make
  validate-all` / `make lint`).
- The skill states remediation is bounded: at most **3 attempts** per failure,
  each attempt recorded in `loop-run-log.md` (spec 016's append-only file, `run_id`
  per failure). The counter is the loop's own circuit breaker, independent of spec
  008's pipeline budget and 014's round counter.
- The skill states that on attempt exhaustion the loop escalates to a human with
  pruned context — the failing job, the run link, and the last log excerpt — and
  never loops forever.
- The skill enumerates the escalation conditions: infrastructure failure (runner
  OOM, registry down, secrets missing), a failure touching more than 5 files or
  core architecture, security-sensitive failures, max attempts exceeded, and
  intermittent flakes needing quarantine.
- The skill states the sweeper defers when `STATE.md` shows an in-flight
  remediation of the same failure on the same branch (the 014-owned `spec/NNN-slug`
  case), rather than competing with it.

Scenarios: `20-acceptance/AC-017-02-sweep-fix-loop.md`

### Task 3 — Create `.github/workflows/ci-sweeper.yml`: event-driven trigger with early exit

Wire the loop's trigger into the repo's only existing automation surface, GitHub
Actions. No new scheduler.

Acceptance criteria:
- `.github/workflows/ci-sweeper.yml` exists with `on: workflow_run`,
  `workflows: ["Self CI"]`, `types: [completed]`.
- The job runs only when `github.event.workflow_run.conclusion == 'failure'`; on a
  green run the job is skipped and the workflow exits no-op — the early exit when
  CI is green (informal AC-006).
- The job captures the failing-run context from the `workflow_run` event (run id,
  `head_sha`, `head_branch`) and passes it into the sweep invocation.
- The job invokes the sweep: a headless `opencode run` that loads
  `skills/ci-triage` and receives the failing-run context. (Exact install/runner
  plumbing is the Coder's; see open question 1.)
- The workflow uses least-privilege permissions: `contents: read`, `actions:
  read` (log fetch), `issues: write` (escalation only). It has no merge, no
  push-to-`main`, no tag-creation capability (AGENTS.md + 016 safety).
- The workflow does not auto-merge and does not push to `main`/`master`.
- The workflow notes it activates only after merging to `main` (the
  `workflow_run` default-branch constraint) and that until spec 016 lands it runs
  report-only (L1), so it must not attempt unattended auto-fixes.

Scenarios: `20-acceptance/AC-017-03-trigger-workflow.md`

### Task 4 — Extend `skills/ci-triage/SKILL.md`: STATE.md CI Sweeper section and cost guidance

Define the CI Sweeper state contract and the loop's cost discipline. The section
lives in 016's `STATE.md`; 017 defines only the sweeper's section of it.

Acceptance criteria:
- The skill defines the **CI Sweeper** section of `STATE.md` (spec 016's durable
  state file, consumed by reference, not re-specified) with these fields: last run
  timestamp, failing commit SHA, failing job, attempt count, worktree/PR link,
  outcome.
- The skill states the prune rule: resolved failures are removed from the CI
  Sweeper section each run; in-flight failures are retained.
- The skill states the dependency explicitly: `STATE.md` and `loop-run-log.md` are
  spec 016's files; the CI Sweeper section is operative only after 016 lands, and
  until then the loop records state at L1 (report) and never runs unattended.
- The skill documents cost guidance: early exit when CI is green; no full sweep on
  a no-op run (no code change since the last sweep, or the failure is already
  resolved); per-run token estimate recorded per 016's `loop-run-log.md` schema.

Scenarios: `20-acceptance/AC-017-04-state-and-cost.md`

### Task 5 — Create `scripts/check-ci-sweeper.sh` and wire it into self-ci

The traceability precedent: a shell check script carrying every AC-017-NN-NN ID
that greps the required strings in the touched files and gates CI.

Acceptance criteria:
- `scripts/check-ci-sweeper.sh` exists, is executable, and exits 0 only when every
  AC-017 content assertion holds.
- The script cites every scenario ID (`AC-017-01-01` … `AC-017-05-NN`) and greps
  each scenario's required string in the relevant artifact (`skills/ci-triage/
  SKILL.md` and `.github/workflows/ci-sweeper.yml`), so it doubles as the
  traceability citation for the scenario IDs.
- The script exits non-zero when a required string is absent (e.g. the skill lacks
  `never auto-fix`, or the workflow lacks `workflow_run`). A `--self-test` mode
  validates this against a temporary fixture so CI can prove the gate actually
  fails closed.
- The script is wired into `.github/workflows/self-ci.yml` as a step (near the
  existing CRLF / YAML-syntax checks), so the sweeper's own deliverables are
  validated by the CI they watch.

Scenarios: `20-acceptance/AC-017-05-traceability-script.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 ci-triage skill, classify output (flake/regression/infra/config), flake → never auto-fix | 1 | `AC-017-01-ci-triage-skill.md` |
| AC-002 loop reacts to a failing CI run; trigger named and wired in `.github/workflows/` | 3 | `AC-017-03-trigger-workflow.md` |
| AC-003 fix attempts in an isolated worktree, verified by a separate checker | 2 | `AC-017-02-sweep-fix-loop.md` |
| AC-004 remediation bounded (max 3 per failure); exhaustion escalates with failing job + last log evidence | 2 | `AC-017-02-sweep-fix-loop.md` |
| AC-005 STATE.md CI Sweeper section updated each run and pruned on resolve | 4 | `AC-017-04-state-and-cost.md` |
| AC-006 cost guidance: early exit when CI green; no full sweep on a no-op run | 3, 4 | `AC-017-03-trigger-workflow.md`, `AC-017-04-state-and-cost.md` |

## Open questions (need a human answer before /build)

1. **Agent-in-CI vs CI-notifies-local-loop.** The trigger is a `workflow_run` job,
   but two execution models are possible: (a) the job runs `opencode run` directly
   on the Actions runner (self-contained, fully event-driven, no cron — my
   recommendation), or (b) the job only opens a triage issue / writes a dispatch
   file that a locally-run opencode loop picks up. Model (b) keeps the agent
   outside CI but introduces a manual/local cadence that borders on the scheduler
   the informal says not to invent. Confirm (a).
2. **Escalation surface.** "Escalate to the human with pruned context" — the repo
   has no existing escalation channel. I assume a GitHub issue (with a stable
   label) carrying the failing job name, run link, and last log excerpt, since
   issues are the repo's human handoff surface and 016's safety rules already
   forbid the loop from acting without human gates. Confirm, or name a different
   surface (draft PR, comment on the run).
3. **State files do not exist (016 not built).** 017 defines the CI Sweeper
   section contract inside the skill and keeps the loop at L1 (report-only) until
   016 lands. Confirm 017 should not block on 016 and should not create
   `STATE.md`/`loop-run-log.md` itself (that would re-specify 016).
4. **Flake quarantine ledger.** The informal wants flakes escalated "needing
   quarantine." I assume a `docs/ci-flakes.md` quarantine ledger (flake signature +
   evidence + first/last seen) that the triage skill consults for "seen before,"
   appended to on each flake. This is a new doc, not new infrastructure. Confirm
   the name, or fold quarantine into `loop-run-log.md` entries instead.
5. **Max-3 independence.** Confirm 017's max-3 per failure is the loop's own
   circuit breaker and shares no counter with 014's post-PR loop or spec 008's
   pipeline budget (a sweeper that runs tomorrow must not be capped by a
   pipeline-budget that ran today).

## Relationship to 014 and 016

- **014 (pipeline-integrated post-PR CI check)** stays exactly as specified: a
  synchronous bounded loop inside `/build` where the Verifier queries CI and the
  Coder/Refactorer fix. 017 does not duplicate those mechanics — it reuses the
  same `gh` log-read commands, but as a standalone recurring sweep with its own
  trigger, triage skill, and worktree procedure. On `spec/NNN-slug` branches the
  sweeper defers to 014's in-flight loop via the `STATE.md` check in task 2.
- **016 (loop engineering foundation)** supplies `STATE.md`, `loop-run-log.md`,
  `loop-budget.md`, `docs/LOOP_ENGINEERING.md`, and the safety rules 017 consumes.
  017 references them and adds only the CI Sweeper section contract and the
  loop-specific procedure inside `skills/ci-triage/SKILL.md`. 017 does not create
  or re-specify any 016 file. 016 is not built; 017 records the dependency and
  stays at L1 until 016 lands.

## Acceptance scenarios

## AC-017-01-01 — The skill file exists with repo-convention frontmatter (AC-001)
## AC-017-01-02 — The failing-log read is grounded in this repo's CI
## AC-017-01-03 — The classification output format is defined (AC-001)
## AC-017-01-04 — The four classes have a decision guide
## AC-017-01-05 — The flake rule forbids auto-fix (AC-001)
## AC-017-01-06 — Infra and config are not code defects
## AC-017-02-01 — Fixes are minimal and isolated in a worktree (AC-003)
## AC-017-02-02 — A separate checker verifies before any PR or comment (AC-003)
## AC-017-02-03 — Remediation is bounded at max 3 attempts (AC-004)
## AC-017-02-04 — Exhaustion escalates to the human with pruned context (AC-004)
## AC-017-02-05 — Escalation conditions are enumerated (AC-004)
## AC-017-02-06 — The sweeper defers to an in-flight remediation on the same failure
## AC-017-03-01 — The trigger is a workflow_run on Self CI (AC-002)
## AC-017-03-02 — The loop reacts only to failure and exits early when green (AC-006)
## AC-017-03-03 — The failing-run context is passed to the sweep
## AC-017-03-04 — The sweep is invoked through the repo's agent tooling
## AC-017-03-05 — Permissions are least-privilege (AC-002)
## AC-017-03-06 — The activation constraint and readiness are documented
## AC-017-04-01 — The STATE.md CI Sweeper section contract is defined (AC-005)
## AC-017-04-02 — Resolved failures are pruned (AC-005)
## AC-017-04-03 — The dependency on spec 016's state files is explicit
## AC-017-04-04 — Cost guidance is documented (AC-006)
## AC-017-05-01 — The script exists and exits 0 only when the assertions hold
## AC-017-05-02 — The script carries every AC-017-NN-NN scenario ID
## AC-017-05-03 — The script fails closed when a required string is missing
## AC-017-05-04 — The script is wired into the CI it watches

## Verification

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

## Quality gates

# Report — 017 CI Sweeper loop

**Stage 5a (Mutation Runner)** — spec `017-ci-sweeper-loop`, branch
`spec/017-ci-sweeper-loop`. `00-informal.md` not read.

---

## Verifier's verdict (carried forward)

**PASS** — `specs/017-ci-sweeper-loop/25-verification.md` exists and its overall
verdict is PASS: AC-017 traceability clean (5 groups, 26 sub-IDs, no dangles),
full relevant suite green, complexity ≤3 on every changed function, single-sourced
pin, shared install script, design-principles gate exit 1 entirely pre-existing
`ci/templates/*` state, spot-checked scenarios match their Given/When/Then,
negative fixture fails closed.

## Mutation score

**skipped — mvp tier.** This repo conforms at `mvp` (no `AGENTS_*.md`;
`check-code-principles.sh` auto-detects `tier: mvp`). Per
`docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier
gate and does not run at `mvp`. The changed code is bash + skill markdown + workflow
YAML; no mutation tooling for shell exists in this repo.

## Complexity summary (carried from the Refactorer, re-confirmed by Verifier)

- `scripts/check-ci-sweeper.sh`: `fail()` CC 1, `pass()` CC 1, `verify_grep()` CC 3,
  `self_test()` CC 2 — all ≤3.
- `scripts/install-opencode.sh`: no functions, straight-line under `set -euo
  pipefail` — CC 1.
- **Pin in one place:** `VERSION="v1.18.18"` occurs exactly once in the change set
  (`scripts/install-opencode.sh:14`); no literal version in either workflow.
- **Shared install script:** both workflows invoke `bash scripts/install-opencode.sh`
  (self-ci.yml, ci-sweeper.yml); self-ci's inline curl/tar block removed in favor of
  the shared script; installs to `/tmp/opencode-bin` (matches
  `model-env.runtime-check.sh` expectations).

## Equivalent mutants

**None.** Mutation testing not run (mvp tier); no survivors to evaluate.

## Architect note (carried from the Verifier)

`docs/ci-flakes.md` is cited by `skills/ci-triage/SKILL.md` as the flake-quarantine
ledger, but the file does not exist. Verifier judgment: consistent with the task
text — no acceptance scenario requires the file to exist now; `10-tasks.md` open
question 4 names it as the *assumed* ledger name pending human confirmation. The
skill committing to that name is write-on-first-use, not a missing deliverable.
Record the open-question-4 answer (ledger name) so the named file is not surprising
post-merge.

## Final test status

Re-run in full one final time (stage 5a re-check; Verifier had already confirmed
once — no new test code was written at this stage since mutation testing was
skipped):

| Command | Result |
|---|---|
| `./scripts/check-ci-sweeper.sh` | exit 0 — 26 PASS, 0 FAIL |
| `./scripts/check-ci-sweeper.sh --self-test` | exit 0 — gate fails closed on broken fixture |
| `bash -n scripts/check-ci-sweeper.sh scripts/install-opencode.sh` | exit 0 — no syntax errors |
| `scripts/check-orchestration.sh` | exit 0 — all orchestration references valid |
| `make validate-all` | exit 0 — 35 required files + cross-refs valid; SKILL.md scan passes (only pre-existing hallmark WARN) |
| `scripts/check-loop-files.sh` | exit 0 — all AC-016 PASS lines, loop foundation present |
| `specs/017-ci-sweeper-loop/25-verification.md` | exists, verdict PASS |

**All green.** Ready for stage 5b (PR Opener).

Mutation Runner: spec-mutation-runner (stage 5a). Writes: this file only.
