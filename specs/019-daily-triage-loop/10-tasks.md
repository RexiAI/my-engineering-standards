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
