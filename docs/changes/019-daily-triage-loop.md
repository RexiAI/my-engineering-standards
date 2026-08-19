# 019-daily-triage-loop

> Spec pipeline archive. Original source: `specs/019-daily-triage-loop/` (deleted by this script).
> Archived: 2026-08-19

## Original ask

# Daily Triage loop (report-only L1 cadence over repo state)

A low-cost loop that runs on a daily cadence, triages the repo's state (open PRs,
specs awaiting build, CI health, open questions), writes outcomes to STATE.md +
loop-run-log.md, and reports — it takes no automatic action in week one. Brings
the daily-triage pattern from cobusgreyling/loop-engineering. This is the
**L1 report-only** entry loop every new pattern must start as.

## What it must provide

1. **Schedule.** Daily (weekdays) via a scheduled GitHub Actions workflow
   (`schedule: cron`) running `opencode run` headlessly against a triage prompt,
   OR a cron/systemd `opencode run` — use the mechanism that exists in this repo.
   Durable, survives restarts; first run fires immediately.

2. **Triage skill.** `skills/loop-triage/SKILL.md` with a tight output format:
   - Open PRs needing action (failing CI, changes requested, ready to merge).
   - Specs under `specs/` awaiting `/build` or stuck at a gate.
   - CI health from self-ci; any red on a feature branch.
   - Open questions from the last run still unresolved.
   - Anything ambiguous → surface to human, never guess.

3. **State.** Read STATE.md at start, write outcomes + timestamp at end. Update
   `loop-run-log.md` (append-only JSON entry). Prune resolved items.

4. **Report-only (L1).** No auto-fix, no auto-PR in week one. Human reviews the
   report (issue or STATE.md section) and decides actions. Escalate only what
   truly needs a human.

5. **Budget + kill switch.** Daily token cap in `loop-budget.md`; kill switch
   (`loop-pause-all` label or STATE.md flag); early exit when nothing actionable.

## Acceptance criteria

- AC-001: a scheduled daily workflow exists in `.github/workflows/` (or the
  documented cron) running the triage loop.
- AC-002: `skills/loop-triage/SKILL.md` exists with the tight output format and
  the never-guess rule.
- AC-003: each run reads + writes STATE.md and appends one loop-run-log.json
  entry with the required fields.
- AC-004: the loop is report-only — no code change, no PR, no merge, in week one.
- AC-005: budget cap + kill switch documented and honored; early exit when
  nothing actionable.
- AC-006: human is notified only when action is required, not on every run.

## Tasks

# Tasks — Daily Triage loop (report-only L1 cadence over repo state)

Formalization of `specs/019-daily-triage-loop/00-informal.md`. Brings the
daily-triage pattern from cobusgreyling/loop-engineering to this repo as the
**L1 report-only** entry loop: a scheduled, weekday, headless `opencode run`
that triages open PRs, specs awaiting build, and CI health, writes outcomes to
`STATE.md` + `loop-run-log.md`, and notifies a human only when an item needs a
decision. It takes no automatic action in week one.

This spec consumes the loop foundation from `specs/016-loop-engineering-foundation`
(`docs/LOOP_ENGINEERING.md`, `templates/STATE.md`, `templates/loop-run-log.md`,
`templates/loop-budget.md`, `templates/LOOP.md`, `templates/loop-constraints.md`,
`templates/gate.yaml`, the readiness levels, and the kill-switch convention).
Where 016 and 019 disagree, 016's durable-file shapes win.

This repo has no JVM/Go/Node test suite. Per the established precedent
(specs 009, 010, 015, 016), the shipped shell check script is the test carrier:
it must reference every task-level scenario ID (`AC-019-01`…`AC-019-07`) so
`scripts/check-scenario-traceability.sh` resolves them. The script is the only
"test" this spec produces; runtime behaviors (a real run creating an issue) are
procedurally verified during the week-one live runs, not by the script.

## Grounded reality (verified against this repo)

- **Scheduling.** This repo has **no scheduled workflow of its own today**.
  `.github/workflows/` contains `self-ci.yml`, `archive-spec.yml`, `release.yml`,
  and `shared/ci-toolchain-bump.yml` — the last is a reusable `workflow_call`
  that *documents* the consumer-side cron pattern (`0 6 * * 1`, weekly) but is
  not scheduled in this repo. `daily-triage.yml` is therefore this repo's **first**
  `on: schedule` workflow. GitHub Actions `schedule:` (cron) + `workflow_dispatch`
  is the mechanism that exists in this repo's ecosystem (standard GHA, cron shown
  in the shared workflow) — no cron/systemd host process is used.
- **`opencode run` headless invocation is verified, not assumed.** `opencode run
  [message]` (opencode 1.18.16) runs non-interactively, supports `--agent`,
  `--dir`, `--format json|default`, and loads provider keys from env vars or a
  project `.env`. It is invoked from the workflow exactly like the repo's own
  agents are. Two CI-facing requirements follow from this (see Decisions):
  (1) the runner must install opencode, and (2) provider credentials must be
  supplied as a GitHub Actions secret — the workflow cannot reuse a developer's
  logged-in `~/.local/share/opencode/auth.json`.
- **Triage sources are real and named:**
  - Open PRs: `gh pr list --state open`. Today: PR #13
    (`chore/spec-conformance-audit`).
  - Per-PR checks: `gh pr checks <n>`. Today: PR #13 has two `Validate` checks,
    both pass.
  - CI health: `gh run list --workflow self-ci.yml`. `self-ci.yml` (`name: Self
    CI`, job `Validate`) is the repo's real CI; it runs on push/PR to every
    branch. "Red on a feature branch" = a `failed` Self CI run on a non-`main`
    branch.
  - Specs awaiting build / stuck at a gate: a scan of `specs/`. Today's
    inventory: 006–015 formalized (`10-tasks.md` + `20-acceptance/` present, no
    `25-verification.md` → awaiting `/build`); 016–019 informal (`00-informal.md`
    only → awaiting `/spec`). All ten formalized specs carry an `## Open
    questions` section in `10-tasks.md` → each needs a human answer before
    `/build`. The triage derives state from the files, never a hardcoded
    inventory (the inventory is live — 016 was being formalized concurrently).
  - Gate signals are file-based: `25-verification.md` with a FAIL verdict =
    stuck at the Verifier gate; `30-report.md` with a failed gate = stuck at the
    Architect gate; `10-tasks.md` containing `## Open questions` = awaiting a
    human answer.
- **Foundation files.** `docs/LOOP_ENGINEERING.md` and the six `templates/`
  loop files do not exist yet (016 is not built). 019 consumes them; the loop
  bootstraps root-level `STATE.md`, `loop-run-log.md`, `loop-budget.md` from the
  016 templates when they exist, and otherwise creates minimal copies matching
  016's documented shapes (see Tasks 3 and 5, and Open question 3).
- **State shapes (from 016).** `STATE.md` has `## High Priority`, `## Watch
  List`, `## Recent Noise` sections plus a `KILL SWITCH:` line (`off`/`on`) that
  every loop checks at run start. `loop-run-log.md` is append-only JSON lines:
  `{ run_id, pattern, duration_s, items_found, actions_taken, escalations,
  tokens_estimate, outcome }`, entries pruned after 30 days. `loop-budget.md`
  documents per-loop daily token caps, max sub-agent spawns/run, on-exceed
  actions, and the kill switch.
- **Commit/push constraints (AGENTS.md).** Direct push to `main` is forbidden
  with no exceptions; every commit requires explicit instruction except the
  Architect's `spec/NNN-slug` carve-out. `archive-spec.yml` is a real precedent
  of a workflow committing and pushing to `main` (post-merge archive commit),
  but it collides with the letter of AGENTS.md. The loop therefore persists its
  two state files on a **`loop-state` branch that never touches `main`**, which
  needs no carve-out (see Decision 3).
- **Notification mechanism.** `gh` CLI is preinstalled on GitHub-hosted runners.
  The workflow grants `issues: write`; the triage run creates/updates a `Daily
  Triage` issue only when the run's outcome is `action_required`. No issue is
  ever created on a clean run.
- **L1 definition (016).** "L1 Report — loop runs on a schedule and writes only
  its own state files (`STATE.md`, `loop-run-log.md`); it makes no changes to
  tracked code or infra. A new pattern never skips L1 on a production repo."

## Decisions (mechanism choices the informal spec left open)

1. **Scheduler: GitHub Actions `schedule:` cron + `workflow_dispatch`.** Weekdays
   06:00 UTC → `0 6 * * 1-5`, plus `workflow_dispatch: {}` so the first run
   fires immediately and humans can re-run on demand. This is the repo's first
   scheduled workflow; noted rather than assumed to exist. The `schedule:`
   trigger's delivery is best-effort (no exact-time guarantee) — acceptable for
   a daily triage cadence.
2. **Headless invocation: `opencode run` in the workflow, verified invocable.**
   The workflow installs opencode, checks out the default branch, seeds the two
   state files from `loop-state`, runs `opencode run` with a triage prompt that
   says "read `skills/loop-triage/SKILL.md` and follow it exactly", then commits
   `STATE.md` + `loop-run-log.md` to `loop-state`. Permissions for the run come
   from the skill's `allowed-tools` frontmatter (the `archive-spec` skill is the
   precedent) — the run is NOT granted `--auto`.
3. **State persistence: dedicated `loop-state` branch, never `main`.** The
   alternative — the workflow committing state to `main` like `archive-spec.yml`
   does — is rejected: it collides with AGENTS.md's "no direct push to main, no
   exceptions" and "no PR" (AC-004) rules. A `loop-state` branch that only ever
   carries the two state files needs no carve-out, no PR, and no merge, and keeps
   `main` untouched. Branch is created on the first run if absent.
4. **Provider credentials: GitHub Actions secret.** The workflow needs an API
   key for the models the repo's `opencode.json` pins (`opencode-go/*`). The
   Coder must verify the exact environment variable name for the configured
   provider (opencode loads provider keys from env vars / project `.env`) and
   document it; the secret is added by the human. Without the secret the
   workflow exits with a clear "not configured" message instead of failing
   loudly.
5. **Notification: the run itself creates the issue via `gh`.** The skill
   instructs the agent to create/update the `Daily Triage` issue (body = the
   skill's tight report format) only when `ACTION_REQUIRED`, using
   `gh issue create`/`gh issue edit`. Deterministic gating (workflow parses
   run-log `outcome`) was considered and rejected as fragile — the agent already
   holds the report in context; it writes the issue directly. The workflow's
   `issues: write` permission is the mechanism that exists (gh + GHA).
6. **Budget: advisory cap, enforced as early-exit.** `opencode run` has no native
   token cap, so the cap in `loop-budget.md` is honored as an early exit: the
   run sums today's `tokens_estimate` from `loop-run-log.md`, and if the next run
   would exceed the daily cap it appends an `outcome: budget_exceeded` entry and
   exits before triaging. Same mechanism as the kill switch (checked first).
7. **No commit/push by the agent.** The agent edits `STATE.md` and
   `loop-run-log.md` locally and never runs `git commit`/`git push`. Persisting
   those files to `loop-state` is the workflow's job, so the run needs no commit
   carve-out.

## Tasks

### Task 1 — `.github/workflows/daily-triage.yml`: scheduled weekday loop

Maps informal AC-001 (a scheduled daily workflow running the triage loop).

**Acceptance criteria**

- `.github/workflows/daily-triage.yml` exists with `on: schedule` containing
  `cron: '0 6 * * 1-5'` and `on: workflow_dispatch: {}`.
- `permissions:` grants `contents: write` (commit state to `loop-state`),
  `issues: write` (create/update the triage issue), `pull-requests: read`
  (`gh pr list`), `actions: read` (`gh run list`).
- The job checks out the default branch (`actions/checkout@v4`), then
  `git fetch origin loop-state` and copies `STATE.md` + `loop-run-log.md` from
  `origin/loop-state` into the worktree when they exist (missing on first run is
  fine — the files are created from the 016 templates or 016-documented shapes).
- A step installs opencode (documented installer; the Coder must verify the
  pinned install command and add an `opencode --version` sanity check).
- A step runs `opencode run` headlessly with a triage prompt that names
  `skills/loop-triage/SKILL.md` and instructs reading it first (the prompt text
  lives in the workflow and is reproduced in the check script's scope for
  static verification).
- Provider credentials are supplied from a GitHub Actions secret exposed as the
  provider's documented env var (Decision 4). When the secret is absent, the
  workflow exits 0 with a "not configured" message — it must not fail the branch.
- A final step commits only `STATE.md` and `loop-run-log.md` to `loop-state`
  (`git add` limited to those two paths) and pushes. If neither file changed,
  it skips the commit. `main` is never pushed to.
- A step creates no issue itself — issue creation is the run's job (Decision 5).
- The workflow is the repo's first `on: schedule` workflow; a comment in the file
  states the 016 L1 basis and the cron best-effort caveat.

Scenarios: `20-acceptance/AC-019-01-scheduled-workflow.md`

### Task 2 — `skills/loop-triage/SKILL.md`: tight output format, never-guess rule

Maps informal AC-002 (skill exists with tight output format and never-guess).

**Acceptance criteria**

- `skills/loop-triage/SKILL.md` exists with frontmatter mirroring the house skill
  style (`name`, `description`, `license`, `allowed-tools`). `allowed-tools`
  grants only what an L1 report loop needs: read/glob/grep, `Bash(gh:*)`,
  and edit/write scoped to `STATE.md`, `loop-run-log.md`, and `loop-budget.md`.
  No `--auto` and no commit/push tools.
- A "When to use" section states this is the **L1 report-only** triage loop per
  `docs/LOOP_ENGINEERING.md §Readiness levels` (016).
- A "Pre-flight" section: read `STATE.md` (check `KILL SWITCH:` first),
  `loop-budget.md`, and the last `loop-run-log.md` entries; if the kill switch is
  `on` or today's budget is exhausted, append a run-log entry and exit early
  (Tasks 3/5 contract).
- The **tight output format** section defines exactly these sections, in order,
  each rendered as a `-` bullet list:
  1. `OPEN PRS NEEDING ACTION` — from `gh pr list --state open` + `gh pr checks
     <n>`: PR number, branch, check state (pass/fail/pending/**absent**), and
     the one-line reason it needs action (failing CI, changes requested, ready
     to merge). Absent checks are never reported as green.
  2. `SPECS AWAITING BUILD OR STUCK` — from the `specs/` scan: slug, current
     state (informal / formalized / stuck-at-gate), and the exact gate
     (`awaiting /spec`, `awaiting /build`, `verifier FAIL`, `architect FAIL`,
     `open questions need a human answer`).
  3. `CI HEALTH` — Self CI run states per branch (`gh run list --workflow
     self-ci.yml`); any red on a feature branch is called out explicitly.
  4. `UNRESOLVED OPEN QUESTIONS` — carried from the previous run's STATE.md plus
     `## Open questions` found in any `specs/*/10-tasks.md`; each is either
     still-open or marked resolved this run.
  5. `AMBIGUOUS — NEVER GUESS` — anything the run could not classify or verify;
     each entry states what is known and what a human must decide. The skill
     states verbatim: **anything ambiguous is surfaced to the human, never
     guessed**.
  6. `ACTION_REQUIRED: yes|no` plus the item list.
- A "Report-only (L1)" section states verbatim: **no code change, no PR, no
  merge — in week one the loop only reports.** No auto-fix, no auto-PR.
- An "Output" section: every run writes outcomes to `STATE.md` and appends one
  `loop-run-log.md` JSON entry (fields per 016); when `ACTION_REQUIRED: yes`,
  create or update the `Daily Triage` issue via `gh` with this report as the
  body, signed `Loop Engineering — Daily Triage`.

Scenarios: `20-acceptance/AC-019-02-triage-skill.md`

### Task 3 — State read/write and run-log append

Maps informal AC-003 (each run reads/writes STATE.md and appends a loop-run-log
entry with required fields).

**Acceptance criteria**

- Each run reads `STATE.md` at start (kill switch, high-priority, watch list,
  open questions from the prior run) and writes outcomes at end: `## High
  Priority` and `## Watch List` updated, resolved items moved to `## Recent
  Noise` (or dropped — never carried forever), open questions reconciled.
- Each run appends exactly one JSON line to `loop-run-log.md` with the 016
  fields: `{ run_id, pattern: "daily-triage", duration_s, items_found,
  actions_taken, escalations, tokens_estimate, outcome }`. `run_id` is
  `YYYY-MM-DD-HHMMSS` (UTC). `outcome` is one of `nothing_actionable`,
  `report_only`, `action_required`, `budget_exceeded`, `paused`.
- The append is a true append: prior entries are never edited or deleted in a
  run; entries older than 30 days are pruned.
- Missing state files are bootstrapped from the 016 templates when present;
  otherwise created with the 016-documented shapes (`KILL SWITCH:` line, the
  three sections, the JSON-line log contract). The workflow does not fail the
  run for a missing file it can create.
- Only `STATE.md` and `loop-run-log.md` are written by the run. No other file in
  the repo changes (Task 4 enforces this).

Scenarios: `20-acceptance/AC-019-03-state-management.md`

### Task 4 — Report-only (L1) enforcement

Maps informal AC-004 (report-only: no code change, no PR, no merge in week one).

**Acceptance criteria**

- The skill's allowed-tools and the workflow's permission set make code edits,
  PR creation, and merge impossible: the workflow has no `pull-requests: write`
  beyond read, the run has no edit/write scope outside the three loop files, and
  `--auto` is never passed to `opencode run`.
- `loop-state` commits are restricted to `STATE.md` + `loop-run-log.md`; a
  `git status` check before commit makes any other change fail the workflow.
- The triage prompt and skill contain no instruction to fix, patch, open a PR,
  or merge — only to report.
- Escalation stays human-owned: an item that needs a decision is listed under
  `ACTION_REQUIRED`/`AMBIGUOUS` and surfaced via the issue; it is never acted on
  by the loop.

Scenarios: `20-acceptance/AC-019-04-report-only.md`

### Task 5 — Budget cap, kill switch, early exit

Maps informal AC-005 (budget cap + kill switch documented and honored; early
exit when nothing actionable).

**Acceptance criteria**

- `loop-budget.md` (bootstrapped from the 016 template, else created) documents
  the `daily-triage` daily token cap, max sub-agent spawns/run (0 at L1), and
  on-exceed actions (slow → pause → kill).
- Kill switch is honored in both forms: the `loop-pause-all` label on the repo
  (`gh label list` / label presence check) and `STATE.md` `KILL SWITCH: on`.
  Either form makes the run exit early with an `outcome: paused` entry and no
  triage.
- Budget is honored as an early exit: today's `tokens_estimate` sum from
  `loop-run-log.md` compared against the cap; on exceed the run appends
  `outcome: budget_exceeded` and exits before triaging.
- Early exit when nothing actionable: zero PRs needing action, zero specs
  awaiting build/stuck, CI green → append `outcome: nothing_actionable`, prune,
  and skip issue creation. The run does not fabricate work to justify running.
- Pre-flight order is fixed: kill switch → budget → triage.

Scenarios: `20-acceptance/AC-019-05-budget-kill-switch.md`

### Task 6 — Notify human only when action is required

Maps informal AC-006 (human is notified only when action is required).

**Acceptance criteria**

- The run creates a `Daily Triage` issue (`gh issue create`, title e.g.
  `Daily Triage — YYYY-MM-DD`, body = the skill's report) **only** when
  `ACTION_REQUIRED: yes` or `AMBIGUOUS` entries exist.
- On a clean run no issue is created and no notification is sent — the run-log
  entry is the only artifact.
- De-duplication: if a `Daily Triage` issue is already open, the run updates it
  (`gh issue edit` / comment) instead of creating a duplicate; the skill's
  report body records the run date.
- The issue is signed `Loop Engineering — Daily Triage` (per the 018 identity
  convention).

Scenarios: `20-acceptance/AC-019-06-notify-only-when-action.md`

### Task 7 — `scripts/check-loop-triage.sh` carrying AC-019-01…07, wired into self-ci

Traceability carrier per the 009/010/015/016 precedent — the shell check is the
only "test" this spec produces.

**Acceptance criteria**

- `scripts/check-loop-triage.sh` follows the house style (`#!/bin/bash`,
  `set -euo pipefail`, header comment with checks/usage/exit codes/standards
  reference, `PASS`/`FAIL` lines, violation counter, summary, non-zero exit on
  violations), and references every task-level ID `AC-019-01`…`AC-019-07` so
  `check-scenario-traceability.sh` resolves them.
- Checks that `.github/workflows/daily-triage.yml` exists, contains a `schedule:`
  with a weekday cron (`1-5`), contains a step running `opencode run`, references
  `skills/loop-triage/SKILL.md`, and grants `issues: write`.
- Checks that `skills/loop-triage/SKILL.md` exists and contains: the never-guess
  rule, the `ACTION_REQUIRED:` output section, the verbatim no-code-change/no-PR/
  no-merge L1 statement, `allowed-tools`, and `allowed-tools` absent of
  commit/push tools.
- Checks that `.github/workflows/self-ci.yml` references `check-loop-triage.sh`
  (wiring in Task 7) and that the script exits 0 on the compliant repo.
- Negative cases (missing workflow, missing skill, missing never-guess line,
  missing schedule) are exercised against a temp fixture, not dead code.
- Passes `bash -n` and shellcheck. Read-only: running it against a compliant
  repo modifies no files.
- On the real repo, the script is green **only after tasks 1–6** are complete —
  like 006's clean-repo pass, it is the aggregate gate.

Scenarios: `20-acceptance/AC-019-07-check-script.md`

## Acceptance criteria mapping

| Informal AC | Task | Scenario file |
|---|---|---|
| AC-001 scheduled daily workflow | 1 | `AC-019-01-scheduled-workflow.md` |
| AC-002 triage skill with tight output + never-guess | 2 | `AC-019-02-triage-skill.md` |
| AC-003 read/write STATE.md + append loop-run-log entry | 3 | `AC-019-03-state-management.md` |
| AC-004 report-only, no auto-fix/PR/merge in week one | 4 | `AC-019-04-report-only.md` |
| AC-005 budget cap + kill switch + early exit | 5 | `AC-019-05-budget-kill-switch.md` |
| AC-006 notify only when action required | 6 | `AC-019-06-notify-only-when-action.md` |
| (traceability precedent) check script + self-ci wiring | 7 | `AC-019-07-check-script.md` |

## Open questions (need a human answer before /build)

1. **Credential source for CI runs.** The workflow runs real `opencode` calls and
   needs a provider API key as a repo secret. Which key should fund the week-one
   runs — a dedicated OpenCode Go key, or a per-provider key for the models in
   `opencode.json`? The Coder must verify the exact env var name for the
   configured provider before finalizing Task 1; confirm that is in scope.
2. **State-persistence branch vs. the `archive-spec.yml` precedent.**
   `archive-spec.yml` already commits and pushes to `main` from a workflow.
   Decision 3 deliberately avoids that (keeps AGENTS.md's no-direct-push rule
   intact) using a `loop-state` branch. Confirm the branch approach is
   acceptable — it is the one design that needs no carve-out.
3. **016 ordering.** 019 consumes the 016 foundation (templates, STATE.md
   shapes, L1 rule) which is not built yet. If 019 lands before 016, Task 3/5
   bootstrap the root state files from the 016-documented shapes instead of the
   templates. Confirm the loop may self-bootstrap those files on first run.
4. **`outcome` vocabulary.** Task 3 fixes `outcome` to a small enum
   (`nothing_actionable`, `report_only`, `action_required`, `budget_exceeded`,
   `paused`). 016's run-log field is untyped. Confirm the enum is acceptable
   (it is what makes the kill-switch and notify gating deterministic).
5. **The informal spec says `loop-run-log.json` (AC-003) while 016 defines
   `loop-run-log.md`.** This spec follows 016's `loop-run-log.md` (append-only
   JSON lines). Confirm the `.json` wording in the informal AC-003 is the same
   file, not a second artifact.

## Acceptance scenarios

## AC-019-01-01 — The workflow exists with a weekday schedule
## AC-019-01-02 — The workflow grants the least privilege it needs
## AC-019-01-03 — The workflow seeds loop state from the loop-state branch
## AC-019-01-04 — The workflow invokes opencode run headlessly against the triage skill
## AC-019-01-05 — The workflow commits only the two state files to loop-state
## AC-019-01-06 — The workflow itself never creates the notification issue
## AC-019-01-07 — The workflow is the repo's first scheduled workflow and says so
## AC-019-02-01 — The skill exists with house-style frontmatter and scoped tools
## AC-019-02-02 — The skill declares itself the L1 report-only loop
## AC-019-02-03 — The output format names every real triage source
## AC-019-02-04 — The never-guess rule is stated verbatim
## AC-019-02-05 — The report-only (L1) rule is stated verbatim
## AC-019-02-06 — The skill defines the run's output contract
## AC-019-03-01 — The run reads STATE.md before triaging
## AC-019-03-02 — The run writes triage outcomes to STATE.md at the end
## AC-019-03-03 — Each run appends exactly one JSON entry with the required fields
## AC-019-03-04 — The log is append-only
## AC-019-03-05 — Missing state files are bootstrapped, not fatal
## AC-019-03-06 — Only the two state files are written by the run
## AC-019-04-01 — The run cannot edit code
## AC-019-04-02 — The run cannot create a PR or merge
## AC-019-04-03 — State persistence touches only loop-state, never main
## AC-019-04-04 — The triage prompt and skill contain no fix/PR/merge instruction
## AC-019-05-01 — loop-budget.md documents the daily cap for the loop
## AC-019-05-02 — The repo-label kill switch pauses the loop
## AC-019-05-03 — The STATE.md kill-switch flag pauses the loop
## AC-019-05-04 — The budget cap is honored as an early exit
## AC-019-05-05 — The loop exits early when nothing is actionable
## AC-019-05-06 — Pre-flight order is fixed
## AC-019-06-01 — An issue is created only when action is required
## AC-019-06-02 — No issue and no notification on a clean run
## AC-019-06-03 — An open triage issue is updated, not duplicated
## AC-019-06-04 — The run records the notification outcome in its log entry
## AC-019-07-01 — The script exists in house style and is the traceability carrier
## AC-019-07-02 — The script verifies the workflow shape (AC-001)
## AC-019-07-03 — The script verifies the skill shape (AC-002, AC-004)
## AC-019-07-04 — The script is wired into self-ci (AC-001, AC-003, AC-005, AC-006 aggregate gate)
## AC-019-07-05 — The clean repo passes
## AC-019-07-06 — Negative cases are genuinely exercised
## AC-019-07-07 — The script is read-only and parses clean

## Verification

# Verification — spec 019 Daily Triage loop

- Verifier: spec-verifier (stage 4), independent re-run of Coder/Refactorer claims.
- Date: 2026-08-19. Branch: `spec/019-daily-triage-loop`.
- Scope: `10-tasks.md` + `20-acceptance/` only. `00-informal.md` not read (information barrier).
- Changed/new files under review: `.github/workflows/daily-triage.yml` (new),
  `.github/workflows/self-ci.yml` (modified, +5 lines), `skills/loop-triage/SKILL.md` (new),
  `scripts/check-loop-triage.sh` (new), `loop-budget.md` (new, repo root).

## Gate-script format note

The verifier instructions reference `--json` transcripts for the two script gates. This
repo's versions of both scripts do **not** implement `--json` or `--checks/--gates`
flags (probed: `check-code-principles.sh --help` → `Unknown option: --help`, exit 2;
`check-scenario-traceability.sh --usage` → treated `--usage` as a directory). Both were
run with their real supported invocations and their stdout is reproduced verbatim below;
exit codes are the contract.

---

## Check 1 — Scenario traceability

Command: `bash scripts/check-scenario-traceability.sh` (repo defaults: SPECS_DIR=specs, SOURCE_DIR=.)
**Exit code: 1** (full repo). Transcript (verbatim, ANSI codes stripped):

```
Scenario IDs found: 77

FAIL AC-007-01 … AC-015-16 — 50 scenarios in specs/*/20-acceptance/ with no test reference
   (AC-007-01..04, AC-008-01..05, AC-009-01..02, AC-010-01..06, AC-011-01..03, AC-012-01..08,
    AC-013-01..06, AC-014-01..05, AC-015-01..16)
FAIL AC-017-01..05, AC-018-01..08 — 13 more scenarios with no test reference
PASS AC-019-01 — traced to a test
PASS AC-019-02 — traced to a test
PASS AC-019-03 — traced to a test
PASS AC-019-04 — traced to a test
PASS AC-019-05 — traced to a test
PASS AC-019-06 — traced to a test
PASS AC-019-07 — traced to a test

FAIL AC-001-01..06, AC-002-01..05, AC-003-01..05, AC-004-01..04, AC-005-01..04, AC-006-01..06 —
   referenced in a test but no matching scenario heading exists in specs/*/20-acceptance/
   (legacy archived-spec refs; check-2 template text: "referenced in a test but no matching
   scenario heading exists in specs/*/20-acceptance/. Stale ID after a rename, or a typo.")
FAIL AC-016-01..05 — same check-2 template (016's own test carrier check-loop-files.sh cites
   AC-016-0N; 016's scenario headings are not in specs/ because 016 is archived/in-flight)
FAIL AC-020-01..07, AC-021-01..08, AC-022-01..04 — same check-2 template (sibling in-flight specs)
✘ Scenario traceability check: 124 violation(s).
```

**Scoped AC-019 result: clean.**
- All 7 task-level IDs traced: `PASS AC-019-01` … `PASS AC-019-07`.
- Sub-ID count: 40 headings under `specs/019-daily-triage-loop/20-acceptance/` (AC-019-01 has 7,
  AC-019-02 has 6, AC-019-03 has 6, AC-019-04 has 4, AC-019-05 has 6, AC-019-06 has 4, AC-019-07
  has 7) — matches the Coder's "40 sub-IDs" claim. The script's check 1 dedupes sub-IDs to the
  7 task-level IDs, which is the script's contract.
- Zero AC-019 references appear in check 2 (no dangling `AC-019-*` refs anywhere in the repo).
- All 124 violations are attributable to sibling in-flight specs (007–018 check 1; 001–006 legacy,
  016/020/021/022 in-flight check 2). None touch AC-019.

**Check 1 verdict: PASS (AC-019 scope clean; full-repo exit 1 is the known pre-existing sibling state).**

---

## Check 2 — Full relevant suite

| Command | Exit | Result |
|---|---|---|
| `./scripts/check-loop-triage.sh` | 0 | all checks pass, `✔ Daily Triage loop check: every check passed.` |
| `./scripts/check-loop-triage.sh --selftest` | 0 | all 4 negative-case fixtures caught (missing workflow, missing skill, no never-guess, schedule-less) |
| `bash -n scripts/check-loop-triage.sh` | 0 | parses clean |
| `bash scripts/check-orchestration.sh` | 0 | all agent/skill/script/doc references resolve |
| `make validate-all` | 0 | all validations passed (1 pre-existing WARN: skills/hallmark/SKILL.md 562 lines > 500) |
| `make lint` | 0 | all 41 YAML files OK, incl. `.github/workflows/self-ci.yml` and `.github/workflows/daily-triage.yml` |
| `bash scripts/check-loop-files.sh` | 0 | 016 foundation bundle present; `✔ Loop files check: every check passed.` |
| `bash scripts/check-skills.sh` | 0 | `All SKILL.md files valid (1 warning(s))` (pre-existing hallmark WARN) |
| PyYAML: `yaml.safe_load` on both workflows | 0 | `.github/workflows/daily-triage.yml PARSE OK`, `.github/workflows/self-ci.yml PARSE OK` |

Workflow shape (read from `.github/workflows/daily-triage.yml`):
- `on: schedule` with `cron: '0 6 * * 1-5'` and `workflow_dispatch: {}` — AC-019-01-01 ✓
- `permissions:` = `contents: write`, `issues: write`, `pull-requests: read`, `actions: read`;
  no `pull-requests: write`, no `id-token`, no admin — AC-019-01-02 ✓
- Seeds `STATE.md` + `loop-run-log.md` from `origin/loop-state`; missing branch on first run
  handled ("will bootstrap from 016 templates/shapes") — AC-019-01-03 ✓
- Installs pinned opencode v1.18.18 with `--version` sanity check; `opencode run` with prompt
  naming `skills/loop-triage/SKILL.md`; no `--auto` — AC-019-01-04 ✓
- Missing-secret path: `Check provider key is configured` step emits `::warning::Daily Triage
  not configured: the OPENCODE_GO_API_KEY secret is absent. Skipping the run.` and sets
  `not-configured=true`; run + commit steps are gated `if: … != 'true'`, so the job exits 0
  with a "not configured" message — AC-019-01-04 ✓
- Commit step: `git status` check fails on any change outside the two state files; `git add
  STATE.md loop-run-log.md` only (no `git add -A`); push `origin HEAD:loop-state`, never main;
  skips commit when unchanged — AC-019-01-05, AC-019-04-03 ✓
- No `gh issue create`/`gh issue edit` in the workflow — AC-019-01-06 ✓
- Header comment documents 016 L1 basis + `schedule:` best-effort caveat — AC-019-01-07 ✓
- Pinned opencode v1.18.18 matches self-ci's own pinned release (self-ci.yml line 93) — the
  workflow's comment claim "Same pinned release the repo's own self-ci uses" is accurate.

Self-ci wiring (`.github/workflows/self-ci.yml` diff, +5 lines):
```
+      # Daily Triage loop gate (spec 019): the check script doubles as the
+      # spec's test carrier, so a missing deliverable fails the Validate job.
+      - name: Check Daily Triage loop deliverables
+        run: ./scripts/check-loop-triage.sh
```
Step present inside the Validate job, **no `continue-on-error`** — AC-019-07-04 ✓

`loop-budget.md` exists at repo root (31 lines): per-run cap 150_000, per-day cap 300_000,
max sub-agent spawns 0, on-exceed slow→pause→kill, kill switch (`KILL SWITCH: on` in STATE.md +
`loop-pause-all` label) — AC-019-05-01 ✓

**Check 2 verdict: PASS.**

---

## Check 3 — Complexity gate

Tool-scoped linters (pmd/golangci/eslint) cover java/go/node only; this spec ships bash +
markdown + YAML, no application code in those languages. `check-code-principles.sh` likewise
analyzes java/go/node only (see Check 3.5 — zero findings on 019 files). Bash complexity
spot-checked manually against the Refactorer's claim ("all functions ≤2; worst offender
require_grep/require_grepE CC 2"):

- `require_file` — `if [ -f "$2" ] … then/else` → 1 decision point → CC 1
- `require_grep` — `if [ -f "$2" ] && grep -qF …` → if + && → CC 2
- `require_grepE` — same shape → CC 2
- `fail` / `pass` — one-liners → CC 1
- The script's main flow is top-level sequential `if` blocks (no nested functions); the
  `--selftest` block is sequential case-ifs, each CC 1–2.

Claim holds: no function exceeds CC 2; worst offenders are `require_grep`/`require_grepE` at
CC 2; bash is out of scope for the tool-scoped gate. **Check 3 verdict: PASS.**

---

## Check 3.5 — Design-principles gate

Command: `bash scripts/check-code-principles.sh` (default SOURCE_DIR=.)
**Exit code: 1.** Transcript (verbatim, ANSI codes stripped):

```
Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7

--- DRY ---
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): }
 /return violations
 /}
 /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): type: "problem", /docs: { /description: /meta: {
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): schema: [], /}, /create(context) { /},
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): return violations
 /}
 /
 /}
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): for _, file := range pkg.Files {
 /for _, decl := range file.Decls {
 /fn, ok := decl.(*ast.FuncDecl)
 /
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): }, /create(context) { /return { /schema: [],
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): }
 /}
 /}
 /violations++
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): }
 /}
 /return violations
 /}
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): violations++
 /}
 /}
 /pos, fn.Name.Name)
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {

--- YAGNI ---
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
PASS YAGNI (go): no premature abstractions detected
PASS YAGNI (node): no premature abstractions detected

--- SOLID ---
PASS SOLID-SRP (java): no oversized files
PASS SOLID-SRP (go): no oversized files
PASS SOLID-SRP (node): no oversized files
PASS SOLID-OCP (java): no large type-dispatch chains
PASS SOLID-OCP (go): no large type-dispatch chains
PASS SOLID-OCP (node): no large type-dispatch chains
PASS SOLID-LSP (java): no heavy instanceof dispatch
PASS SOLID-LSP (node): no heavy instanceof dispatch
PASS SOLID-ISP (java): no fat interfaces
PASS SOLID-ISP (node): no fat interfaces
PASS SOLID-DIP (java): no domain→infrastructure imports
PASS SOLID-DIP (go): no domain→infrastructure imports
PASS SOLID-DIP (node): no domain→infrastructure imports

--- Property tests ---
Property tests: skipped (project tier is mvp — production+ required)
Property tests: skipped (project tier is mvp — production+ required)
Property tests: skipped (project tier is mvp — production+ required)

---------------------------------------------
✘ Design-principles check: 5 FAIL(s), 17 WARN(s).
  Reference: docs/CODING_CONVENTIONS.md §Design Principles, docs/ARCHITECTURE.md, docs/TESTING.md
```

**Judgment:** all 5 FAILs and all 17 WARNs are confined to `ci/templates/*`
(`go-saga-lint.go`, `eslint-saga-rules/saga-compensation.js`, `archunit/*.java`) — pre-existing
state, zero attributable to spec 019. Every file this spec ships (`.github/workflows/daily-triage.yml`,
`skills/loop-triage/SKILL.md`, `scripts/check-loop-triage.sh`, `loop-budget.md`, the self-ci
diff) produced no FAIL and no WARN. Tier auto-detected `mvp` → property-test checks correctly
skipped (consistent with no `AGENTS_*.md` — see mvp note below). **Check 3.5 verdict: PASS
for spec 019's files; the gate's repo-root exit 1 is entirely pre-existing `ci/templates/*`
state.** (WARNs remain review hints for the Architect: pre-existing, not 019's.)

**mvp-tier confirmation:** no `AGENTS_*.md` exists in the repo (glob returns nothing), so the
mvp tier claim holds; property-test skips in the principles gate and the mvp mutation skip for
the Architect are correct.

---

## Check 4 — Scenario-to-behavior spot check

Three scenarios manually checked against real content (not just ID presence):

**AC-019-02 (skill contract) → `skills/loop-triage/SKILL.md`** — PASS
- Frontmatter `name`/`description`/`license`/`allowed-tools` present; allowed-tools grants
  Read/Glob/Grep, `Bash(gh:*)`, Edit/Write scoped to `STATE.md`, `loop-run-log.md`,
  `loop-budget.md`; no commit/push tool (AC-019-02-01).
- "When to use" states L1 report-only per `docs/LOOP_ENGINEERING.md §Readiness levels`
  (AC-019-02-02).
- Output format defines all six sections verbatim: `OPEN PRS NEEDING ACTION`, `SPECS AWAITING
  BUILD OR STUCK`, `CI HEALTH`, `UNRESOLVED OPEN QUESTIONS`, `AMBIGUOUS — NEVER GUESS`,
  `ACTION_REQUIRED: yes|no`; sources named (`gh pr list --state open`, `gh pr checks`,
  `gh run list --workflow self-ci.yml`); "Absent checks are never reported as green"
  (AC-019-02-03).
- Never-guess verbatim: "Anything ambiguous is surfaced to the human, never guessed."
  (AC-019-02-04).
- Report-only verbatim: "No code change, no PR, no merge — in week one the loop only
  reports." (AC-019-02-05).
- Output contract: one `loop-run-log.md` JSON entry with the 016 fields; outcome enum
  `nothing_actionable | report_only | action_required | budget_exceeded | paused`; issue via
  `gh issue create`/`gh issue edit` signed `Loop Engineering — Daily Triage` only when
  `ACTION_REQUIRED: yes` (AC-019-02-06).
- Pre-flight order fixed: kill switch → budget → triage (AC-019-05-06). Budget early-exit,
  `outcome: paused` (label + `KILL SWITCH: on`), `nothing_actionable` no-fabricate rule, 30-day
  prune, bootstrap-from-templates, only-two-files-written — all present.

**AC-019-05 (budget + kill switch) → `loop-budget.md`** — PASS
- Exists at repo root; documents daily-triage per-run cap (150_000) and per-day cap (300_000),
  max sub-agent spawns 0 at L1, on-exceed slow→pause→kill, kill switch in both forms
  (STATE.md `KILL SWITCH: on` + `loop-pause-all` label) (AC-019-05-01..03).

**AC-019-01-04 (missing secret) → workflow** — PASS
- Guard step exits the job successfully with a "not configured" warning when the secret is
  absent; run/commit steps skipped (verified in the YAML, AC-019-01-04).

**AC-019-07 (check script) → independent negative fixture** — PASS (mechanism works)
- My own fixture (not just `--selftest`): copied the workflow, skill, templates, budget, and
  script into `/tmp/opencode/neg-fixture`, injected a wrong string
  (`Anything ambiguous is surfaced to the human, never guessed.` → `REMOVED NEVER-GUESS RULE`).
  Ran `bash scripts/check-loop-triage.sh <fixture>` → exit 1, isolated
  `FAIL AC-019-02-04: AMBIGUOUS — NEVER GUESS does not state the never-guess rule verbatim`.
  Fixture deleted after the run; repo untouched (verified via `git status`).
- The script's own `--selftest` (4 fixtures: missing workflow, missing skill, no never-guess,
  schedule-less) passes, exit 0.
- Script house style verified: `#!/bin/bash`, `set -euo pipefail`, header comment, PASS/FAIL
  lines, violation counter, summary, non-zero exit; references all 7 task-level IDs
  (AC-019-01..07, verified by grep); read-only on the real repo (only greps; fixtures live in
  `mktemp -d` with EXIT trap).

**Check 4 verdict: PASS.**

---

## Check 5 — No unaccounted behavior

Diff skimmed (self-ci.yml +5 lines; new: daily-triage.yml, SKILL.md, check-loop-triage.sh,
loop-budget.md). Every behavior traces to a task/scenario:
- Workflow steps (seed, install opencode pinned v1.18.18 + `--version`, provider-key guard,
  `opencode run` prompt, commit-to-loop-state with git-status gate) → Task 1 / AC-019-01.
- Skill sections (pre-flight, report-only, output format, output, "what it is not") → Tasks 2–6
  / AC-019-02..06.
- `loop-budget.md` (caps, spawns, on-exceed, kill switch) → Task 5 / AC-019-05.
- Check script blocks → Task 7 / AC-019-07; self-ci step → Task 7.
- The `git config user.name/email` lines in the workflow are required for the persistence
  commit (Task 1) — legitimate, not unaccounted.
- 016 foundation files exist (confirmed by `check-loop-files.sh`), so the "bootstrap from 016
  templates" references in skill/workflow resolve to real files — resolves 10-tasks.md Open
  question 3 in the delivered artifact.

**Check 5 verdict: PASS — with one FAIL-class defect found by runtime verification, below.**

---

## FAIL — Provider env var name contradicted by the pinned runtime (Task 1 / AC-019-01-04)

10-tasks.md Task 1 acceptance criterion and Decision 4 require the Coder to **verify the exact
environment variable name** the configured provider reads. The workflow documents:

> `OPENCODE_GO_API_KEY` … exposed to the run as the `OPENCODE_GO_API_KEY` env var that the
> opencode-go provider reads.

I verified this against the actual pinned binary the workflow installs (v1.18.18 from
`https://github.com/anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz` —
downloaded, `opencode --version` → `1.18.18`):

```
$ grep -aoE '"opencode-go":\{[^}]*\}' opencode | head -1
"opencode-go":{id:"opencode-go",env:["OPENCODE_API_KEY"],npm:"@ai-sdk/openai-compatible",api:"https://opencode.ai/zen/go/v1",name:"OpenCode Go",...}

$ grep -acE "OPENCODE_GO_API_KEY" opencode
0
```

The binary's provider registry for `opencode-go` reads **`OPENCODE_API_KEY`**; the string
`OPENCODE_GO_API_KEY` occurs **zero** times in the binary. Consequences:

1. A human following the workflow's documentation adds the secret `OPENCODE_GO_API_KEY`. The
   guard step then sees the var set (non-empty), so `not-configured` is **not** set and the
   run proceeds — but `opencode run` never sees a key for the opencode-go provider (it reads
   `OPENCODE_API_KEY`), so the triage run fails at runtime with a provider auth error on every
   scheduled run, with no human watching.
2. Alternatively, a human adds `OPENCODE_API_KEY` (what the runtime actually reads) — the
   guard sees `OPENCODE_GO_API_KEY` empty and the loop skips forever as "not configured".
   Either way the configured path can never authenticate.
3. `scripts/check-loop-triage.sh` AC-019-01-04 asserts the presence of `OPENCODE_GO_API_KEY`
   in the workflow, so the check script is green while the workflow is broken — the assertion
   targets the wrong string (the negative-fixture mechanism itself works; the asserted string
   is wrong).

This is exactly the failure class the Verifier exists to catch (SPEC_PIPELINE.md §Why a
separate Verifier stage: "config files that looked correct on read but failed the moment they
were actually executed"). The fix (Coder/Refactorer, not Verifier): rename the documented
secret/env var to `OPENCODE_API_KEY` in `daily-triage.yml` (comment, guard, run-step env) and
update the check script's AC-019-01-04 assertion to match; then re-run the blocked gates.

---

## Overall verdict

# FAIL

Pipeline stops. Reasons (single defect):

1. **FAIL — Task 1 / AC-019-01-04:** the workflow documents and gates on env var
   `OPENCODE_GO_API_KEY`, but the pinned opencode v1.18.18 binary's `opencode-go` provider
   reads `OPENCODE_API_KEY` (`env:["OPENCODE_API_KEY"]` in the provider registry; the string
   `OPENCODE_GO_API_KEY` does not exist in the binary). The documented secret can never
   authenticate the headless run. The check script encodes the same wrong string, so the gate
   is a false green on this point.

All other checks pass: traceability (AC-019 scope clean, 7/7 task IDs, 40 sub-IDs, no dangles),
full suite (all gates exit 0; PyYAML parses both workflows; cron `0 6 * * 1-5`; least-privilege
permissions; pushes only to `loop-state`; self-ci step present without `continue-on-error`;
`loop-budget.md` present), complexity (all functions ≤2, bash out of tool-scoped scope),
design-principles (repo-root exit 1 = pre-existing `ci/templates/*` FAILs/WARNs, zero
attributable to 019), spot checks (skill rules, outcome enum, missing-secret path, negative
fixture), no unaccounted behavior, mvp tier confirmed (no `AGENTS_*.md` → property-test/mutation
skips correct).

Per AC-007-02, when the defect is fixed, re-run only the blocked gate(s) — at minimum the
workflow env-var portion of Check 4/5 (re-run `check-loop-triage.sh` and the runtime grep
against the pinned binary) — appending to this report.

---

# Re-verification after fix (2026-08-19)

Verifier re-invoked after the Coder fixed the single FAIL (Task 1 / AC-019-01-04 env-var
mismatch). The original FAIL record above is preserved verbatim. Per AC-007-02, the re-run
appends to this report; the prior full run's content above stands except where re-run below.

## 0. The fix itself — verified independently

**`.github/workflows/daily-triage.yml`** — `OPENCODE_GO_API_KEY` occurs **0 times**;
`OPENCODE_API_KEY` is used consistently across all six sites:

```
:21 # Actions repository secret `OPENCODE_API_KEY`, exposed to the run as the
:22 # `OPENCODE_API_KEY` env var that the opencode-go provider reads. The human
:82           if [ -z "${OPENCODE_API_KEY:-}" ]; then
:83             echo "::warning::Daily Triage not configured: the OPENCODE_API_KEY secret is absent. Skipping the run."
:87           OPENCODE_API_KEY: ${{ secrets.OPENCODE_API_KEY }}      (guard step env)
:95           OPENCODE_API_KEY: ${{ secrets.OPENCODE_API_KEY }}      (run step env)
```

Secret placeholder + guard + run-step env all use `OPENCODE_API_KEY`; the "not configured"
exit-0 path is intact.

**`scripts/check-loop-triage.sh`** — AC-019-01-04 now asserts the correct string:
`require_grep "AC-019-01-04" "$WORKFLOW_FILE" "OPENCODE_API_KEY"` (line 184) and
`require_grepE ... 'OPENCODE_API_KEY.*==.*.|secrets.OPENCODE_API_KEY'` (line 186).

**Pinned binary (independently re-downloaded, not taken on trust):**
`curl -sSL .../anomalyco/opencode/releases/download/v1.18.18/opencode-linux-x64.tar.gz`,
extracted, `opencode --version` → `1.18.18`. Grep of the binary:

```
$ grep -aoE '"opencode-go":\{[^}]*\}' opencode | head -1
"opencode-go":{id:"opencode-go",env:["OPENCODE_API_KEY"],npm:"@ai-sdk/openai-compatible",api:"https://opencode.ai/zen/go/v1",name:"OpenCode Go",...}

$ grep -aoE 'OPENCODE_API_KEY' opencode | sort | uniq -c
      3 OPENCODE_API_KEY
$ grep -aoE 'OPENCODE_GO_API_KEY' opencode | sort | uniq -c
(0 — absent)
```

The provider the workflow pins reads `OPENCODE_API_KEY`; `OPENCODE_GO_API_KEY` is absent
from the binary. (Coder claimed "0 wrong / 2 right" — wrong-count confirmed; my independent
count finds 3 right-string occurrences, a trivial counting difference, substance identical.)
**Fix is real: the documented secret now matches the runtime.**

**No real API key committed:** `grep -rnE 'sk-[A-Za-z0-9_-]{16,}'` over the working tree
(excluding `.git`) hits only `.opencode/node_modules/effect/dist/Config.d.ts` — a doc-comment
placeholder (`API_KEY: "sk-1234567890abcdef"`) in a gitignored (`git check-ignore` exit 0),
untracked (`git ls-files` count 0) dependency. `git diff` (self-ci.yml) has zero `sk-` hits.

## 1. Check 1 — Scenario traceability (re-run)

Command: `bash scripts/check-scenario-traceability.sh` → **exit code 1** — byte-identical
violation set to the prior full run: 124 violations, all in sibling/legacy state
(check 1: AC-007..015, AC-017..018; check 2: AC-001..006, AC-016, AC-020..022). AC-019 scope:
all seven task IDs pass (`PASS AC-019-01` … `PASS AC-019-07`), zero `AC-019-*` references in
check 2. **PASS for AC-019 scope** (repo-root exit 1 = pre-existing sibling state, unchanged).

## 2. Check 2 — Full relevant suite (re-run)

| Command | Exit | Result |
|---|---|---|
| `./scripts/check-loop-triage.sh` | 0 | every check passed, incl. fixed `AC-019-01-04: provider credentials come from the OPENCODE_API_KEY secret env var` and `AC-019-01-04: a 'not configured' path exits 0 when the secret is absent` |
| `./scripts/check-loop-triage.sh --selftest` | 0 | all 4 negative-case fixtures caught |
| `bash -n scripts/check-loop-triage.sh` | 0 | parses clean |
| `bash scripts/check-orchestration.sh` | 0 | all agent/skill/script/doc references valid |
| `bash scripts/check-loop-files.sh` | 0 | 016 foundation bundle present |
| PyYAML `yaml.safe_load` on both workflows | 0 | `daily-triage.yml PARSE OK`, `self-ci.yml PARSE OK` |
| `make validate-all` | 0 | all validations passed (1 pre-existing WARN: skills/hallmark/SKILL.md 562 lines) |
| `make lint` | 0 | all YAML OK |
| `bash scripts/check-skills.sh` | 0 | `All SKILL.md files valid (1 warning(s))` (pre-existing hallmark WARN) |

**PASS.**

## 3. Check 3 — Complexity gate (re-check)

The fix changed no control flow: in `check-loop-triage.sh` only grep *argument strings*
changed (lines 184–186); the `require_grep`/`require_grepE` function bodies are untouched,
so the prior CC analysis holds (max CC 2 — `require_grep`/`require_grepE` at CC 2, everything
else ≤1). In the workflow, the guard condition is still a single `-z` test (CC 1). Tool-scoped
linters (pmd/golangci/eslint) do not cover bash/YAML/markdown. **PASS.**

## 3.5. Check 3.5 — Design-principles gate (re-run)

Command: `bash scripts/check-code-principles.sh` → **exit code 1**. Transcript is byte-identical
to the prior full run's verbatim transcript above. Every FAIL/WARN line, verbatim:

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
WARN Possible duplication (10 DRY lines, all ./ci/templates/go-saga-lint.go / eslint-saga-rules/saga-compensation.js)
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

Summary line verbatim: `✘ Design-principles check: 5 FAIL(s), 17 WARN(s).`

All 5 FAILs and all 17 WARNs are confined to `ci/templates/*` — pre-existing state, zero
attributable to spec 019 (the same set as the prior full run). Every file this spec ships
produced no FAIL and no WARN. **PASS for spec 019's files** (gate's repo-root exit 1 is entirely
pre-existing `ci/templates/*` state; WARNs remain review hints for the Architect, pre-existing).

## 4. Check 4 — Scenario-to-behavior spot check (re-run, incl. fix region)

**AC-019-01-04 → `.github/workflows/daily-triage.yml`** — PASS (this is the fixed gate):
- Then: "runs `opencode run` with a prompt that names `skills/loop-triage/SKILL.md` and
  instructs reading it first" → run step (line 99): `"Read skills/loop-triage/SKILL.md first
  and follow it exactly for this run of the Daily Triage loop."` ✓
- Then: "the run is not passed `--auto`" → no `--auto` on the run step ✓
- Then: "provider credentials come from a GitHub Actions secret" → `env: OPENCODE_API_KEY:
  ${{ secrets.OPENCODE_API_KEY }}` on both guard (87) and run (95) steps; secret name now
  matches the pinned binary's provider env (`env:["OPENCODE_API_KEY"]`, verified §0) ✓
- Then: "when the secret is absent the job exits 0 with a 'not configured' message" → guard
  (82–85) warns + sets `not-configured=true`; run/commit steps gated `!= 'true'` → job exits 0 ✓
- Given: "opencode run is verified invocable non-interactively" → Install step runs
  `opencode --version` sanity check (line 74) ✓

**AC-019-03-03 → `skills/loop-triage/SKILL.md`** — PASS:
- Then: exactly one JSON line with keys `run_id, pattern, duration_s, items_found,
  actions_taken, escalations, tokens_estimate, outcome` → SKILL.md:63 verbatim
  `{ run_id, pattern: "daily-triage", duration_s, items_found, actions_taken, escalations,
  tokens_estimate, outcome }` ✓
- Then: `run_id` UTC `YYYY-MM-DD-HHMMSS`; `pattern` is `daily-triage`; outcome enum → line 63
  verbatim: `run_id` is a UTC timestamp of the form `YYYY-MM-DD-HHMMSS`; `outcome` is one of
  `nothing_actionable`, `report_only`, `action_required`, `budget_exceeded`, `paused` (all 5
  values, incl. `report_only`, which the check script does not grep — verified directly) ✓

**Regression fixture for the fix (my own, not the script's selftest):** copied workflow +
skill + templates into a temp dir, injected the *old* wrong string
(`sed 's/OPENCODE_API_KEY/OPENCODE_GO_API_KEY/g'`), ran `bash scripts/check-loop-triage.sh
<fixture>` → **exit 1**, with:
```
FAIL AC-019-01-04: provider credentials come from the OPENCODE_API_KEY secret env var (expected "OPENCODE_API_KEY" in ...)
FAIL AC-019-01-04: a 'not configured' path exits 0 when the secret is absent (expected pattern "OPENCODE_API_KEY.*==.*.|secrets.OPENCODE_API_KEY" in ...)
✘ Daily Triage loop check: 4 violation(s). Fix before merging.
```
The gate now catches exactly the defect it previously encoded as a false green. Fixture
deleted after the run; repo untouched (verified via `git status` — only the expected spec-019
files present, as in the prior pass).

**PASS.**

## 5. Check 5 — No unaccounted behavior (re-run)

Diff since the prior FAIL is a pure string rename — no new logic, no new files:
- `daily-triage.yml`: 6 sites `OPENCODE_GO_API_KEY` → `OPENCODE_API_KEY` (comment ×2, guard,
  warning, env ×2) → Task 1 / AC-019-01-04.
- `check-loop-triage.sh`: 2 assertion strings (lines 184, 186) → Task 7 / AC-019-01-04.
- `self-ci.yml` diff is unchanged from the prior pass (+5 lines: the check-loop-triage.sh
  Validate step, no `continue-on-error`) — re-confirmed via `git diff`.
- No other files changed (`git status --porcelain` matches the prior pass exactly).
The `git config user.name/email` lines in the commit step remain accounted for (persistence
commit, Task 1). **PASS.**

---

# Overall verdict (re-verification)

# PASS

The single prior FAIL (Task 1 / AC-019-01-04: `OPENCODE_GO_API_KEY` vs the pinned binary's
`OPENCODE_API_KEY`) is fixed and independently re-verified: the workflow and the check
script now use `OPENCODE_API_KEY` everywhere (0 occurrences of the old string in either
deliverable), a fresh download of the pinned v1.18.18 binary declares
`env:["OPENCODE_API_KEY"]` for the opencode-go provider (0 occurrences of the old string in
the binary), the check script's AC-019-01-04 assertion now fails (exit 1) against a fixture
carrying the old string, and no real API key value is committed anywhere.

All gates re-run clean for spec 019's scope:
1. Traceability — AC-019 7/7 task IDs traced, zero dangles (repo-root exit 1 unchanged:
   pre-existing sibling/legacy specs).
2. Full suite — check-loop-triage.sh (incl. fixed AC-019-01-04), selftest, bash -n,
   orchestration, loop-files, PyYAML ×2, validate-all, lint, check-skills: all exit 0.
3. Complexity — no control-flow change from the fix; prior CC ≤2 analysis holds.
3.5. Design-principles — exit 1 with the identical pre-existing 5 FAIL / 17 WARN, all
   `ci/templates/*`; zero findings on spec 019 files. (WARNs: pre-existing review hints.)
4. Spot checks — AC-019-01-04 (fix region) and AC-019-03-03 assertions match scenario
   Given/When/Then; wrong-string regression fixture fails the gate as intended.
5. No unaccounted behavior — fix delta is a rename traceable to Task 1 / AC-019-01-04.

Architect may proceed.

---

## Environmental notice (post-verification, OUTSIDE spec 019 scope)

During this verification session an **external actor concurrently modified**
`scripts/check-code-principles.sh` in this working tree (file mtime 2026-08-19 10:53:19,
i.e. after this report's Check 3.5 gate had already executed). The file now contains
unresolved merge-conflict markers from a merge of `origin/main` (`<<<<<<< HEAD` at line 37,
inside the Usage block — outside any comment), so:

- `bash -n scripts/check-code-principles.sh` → **exit 2** (syntax error near `<<<`)
- `bash scripts/check-code-principles.sh` → **exit 2** (tooling failure, not a finding)

Facts:
- **Not caused by the Verifier.** My only writes this session were this report and
  `/tmp/opencode` scratch (cleaned). No command I ran writes to that script; the repo has no
  non-sample git hooks; no Makefile target references it for writes or runs
  `git merge/pull/fetch/checkout`.
- **Outside spec 019's scope.** `scripts/check-code-principles.sh` is not a spec-019
  deliverable. The conflict content is another spec's in-flight change to that script
  (`--gates`, `--json`, `-BaseRef`, `--blocking` flags).
- **Uncommitted only.** `git show HEAD:scripts/check-code-principles.sh | bash -n` → clean
  (exit 0). The branch commit `3013d8d` is unaffected; CI is unaffected (self-ci.yml does not
  reference check-code-principles.sh; the conflict markers exist only in the working tree).
- The Check 3.5 gate evidence above (exit 1, byte-identical transcript) was captured from the
  working script before the external mutation; it stands as executed.

**Action for the human/Architect before any further local pipeline work:** resolve or restore
`scripts/check-code-principles.sh` (e.g. `git checkout HEAD -- scripts/check-code-principles.sh`
or finish the third party's merge). This is a working-tree hazard, not a spec-019 gate finding;
it does not alter the PASS verdict below, which covers spec 019's deliverables and gates.

---

# Overall verdict (re-verification, incl. environmental notice)

# PASS

Spec 019's fix is verified and every gate re-ran clean for spec 019's scope (traceability
AC-019 7/7 + zero dangles; full suite all exit 0; complexity unchanged ≤2; design-principles
gate exit 1 = identical pre-existing `ci/templates/*` FAILs/WARNs, zero on 019 files; spot
checks AC-019-01-04 + AC-019-03-03 assertions match scenarios; wrong-string regression
fixture now fails the gate as intended; no unaccounted behavior; no real API key committed).
The environmental notice above is a concurrent-work hazard in the working tree outside spec
019's scope — resolve it before further local runs of the principles gate, but it does not
block spec 019. Architect may proceed.

## Quality gates

# Report — spec 019 Daily Triage loop

- Stage: 5a Mutation Runner. Date: 2026-08-19. Branch: `spec/019-daily-triage-loop`.
- `00-informal.md` not read (information barrier).

## Verifier's verdict (carried forward)

**PASS** — `25-verification.md` final verdict (re-verification, 2026-08-19). The single
prior FAIL (Task 1 / AC-019-01-04: env var `OPENCODE_GO_API_KEY` vs the pinned opencode
v1.18.18 binary's provider env `OPENCODE_API_KEY`) was fixed by the Coder and
independently re-verified: the workflow and check script now use `OPENCODE_API_KEY`
everywhere (0 occurrences of the old string in either deliverable), the binary declares
`env:["OPENCODE_API_KEY"]` for the opencode-go provider, the check script's AC-019-01-04
assertion fails (exit 1) against a wrong-string regression fixture, and no real API key
value is committed. All other gates re-ran clean for spec 019's scope (traceability
AC-019 7/7 + zero dangles; full suite exit 0; complexity ≤2; design-principles exit 1 =
identical pre-existing `ci/templates/*` FAILs/WARNs, zero on 019 files).

## Mutation score

Skipped — `mvp` tier.

(Per `docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a
`production`-tier gate and is skipped at `mvp`; this repo has no `AGENTS_*.md`, and the
changed deliverables are bash + markdown + YAML with no mutation tooling in this repo.)

## Complexity summary (carried from the Refactorer, re-confirmed by the Verifier)

- `scripts/check-loop-triage.sh`: all functions ≤2. Worst offenders
  `require_grep`/`require_grepE` at CC 2 (`if` + `&&`); `require_file`, `fail`, `pass` at
  CC 1; main flow and `--selftest` block are top-level sequential case-ifs, each CC 1–2.
- Workflow guard condition: single `-z` test, CC 1.
- The env-var fix changed only grep argument strings (no control flow), so CC analysis is
  unchanged.
- Tool-scoped complexity linters (pmd/golangci/eslint) do not cover bash/YAML/markdown.

## Equivalent mutants

None. Mutation testing was not run (mvp tier), so no mutants were generated and none
were classified as equivalent.

## Final test status

Full suite re-run by the Mutation Runner after the Verifier's PASS — all green:

| Command | Exit | Result |
|---|---|---|
| `./scripts/check-loop-triage.sh` | 0 | every check passed, incl. fixed `AC-019-01-04` assertions |
| `./scripts/check-loop-triage.sh --selftest` | 0 | all 4 negative-case fixtures caught |
| `bash -n scripts/check-loop-triage.sh` | 0 | parses clean |
| `bash scripts/check-orchestration.sh` | 0 | all agent/skill/script/doc references valid |
| `make validate-all` | 0 | all validations passed (1 pre-existing WARN: `skills/hallmark/SKILL.md` 562 lines) |
| `bash scripts/check-loop-files.sh` | 0 | 016 foundation bundle present; every check passed |
| `specs/019-daily-triage-loop/25-verification.md` | — | exists, verdict `# PASS` (lines 545, 605) |

Notes:

- Working tree holds only the expected spec-019 changes: `self-ci.yml` (modified +5
  lines), new `daily-triage.yml`, `skills/loop-triage/`, `scripts/check-loop-triage.sh`,
  `loop-budget.md`, and the spec folder. Nothing else changed.
- The Verifier's environmental notice (concurrent working-tree conflict markers in
  `scripts/check-code-principles.sh`) is resolved: `bash -n` clean, zero conflict
  markers, outside spec 019 scope, no impact on this report's gates.

## Handoff

Spec 019 is mutation-skipped per tier, all configured gates green, Verifier PASS carried
forward. Ready for stage 5b (PR Opener): archive + commit + push + draft PR.
