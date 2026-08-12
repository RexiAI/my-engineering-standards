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
