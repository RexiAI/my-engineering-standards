# Spec Pipeline

A six-stage pipeline that turns an informal spec you write into a mutation-tested,
gated pull request, adapted from Robert C. Martin's agent pipeline
(Specifier → Coder → Refactorer → Architect) plus an independent QA stage
(Verifier) that re-verifies prior stages' claims before anything is committed.
You write stage 0 and review once after stage 1; everything after that runs to a
draft PR.

This file is the index; each stage's detailed rules live under
`docs/spec-pipeline/` (table below), the cross-cutting rules here. Read the index
sections your stage file names, plus that stage file — not the whole set.

## Stages

| # | Stage | Agent | You do |
|---|---|---|---|
| 0 | Informal spec | — (you) | Write `specs/NNN-slug/00-informal.md` in your own words |
| 1 | Specifier | `spec-specifier` | Nothing yet — review the output |
| 1.5 | UX Designer | `spec-ux` | Nothing — skips automatically if no frontend surface |
| — | **Human gate** | — | Read `10-tasks.md` + `20-acceptance/` + `15-design.md` (if present). Fix or approve. |
| 2 | Coder | `spec-coder` | Nothing — runs to green tests |
| 3 | Refactorer | `spec-refactorer` | Nothing — runs to clean structure |
| 4 | Verifier | `spec-verifier` | Nothing — independently re-checks stages 2-3 |
| 5a | Mutation Runner | `spec-mutation-runner` | Nothing — bounded, scoped mutation (ADR 0028), only if Verifier passed |
| 5b | PR Opener | `spec-pr-opener` | Nothing — commits, pushes, opens draft PR (no longer archives), only if Mutation Runner green |
| 5c | Deploy Verifier | `spec-deployer` | Nothing — waits for the live Vercel preview deployment, verifies health check + E2E against it, writes `40-deploy.md`; frontend lanes only, otherwise a recorded skip |
| 5d | Archiver | `spec-pr-opener` | Nothing — runs the archive as the genuinely final act, only if `40-deploy.md` carries a PASS verdict or a recorded skip |
| — | Output | — | Review the draft PR |

Two commands drive it: `/spec` runs stage 1 and stops. `/build` runs stages 2-5 and
opens the PR.

## Stage files

| Stage | Agent | Stage file |
|---|---|---|
| 1 | Specifier | `docs/spec-pipeline/specifier.md` |
| 1.5 | UX Designer | `docs/spec-pipeline/ux.md` |
| 2 | Coder | `docs/spec-pipeline/coder.md` |
| 3 | Refactorer | `docs/spec-pipeline/refactorer.md` |
| 4 | Verifier | `docs/spec-pipeline/verifier.md` |
| 5a | Mutation Runner | `docs/spec-pipeline/mutation-runner.md` |
| 5b | PR Opener | `docs/spec-pipeline/pr-opener.md` |
| 5c | Deploy Verifier | `docs/spec-pipeline/deployer.md` |
| 5d | Archiver | `docs/spec-pipeline/pr-opener.md` |

Shared files; read one only when your stage file says "Must read" it:

- `docs/spec-pipeline/audit-contract.md` — audit contract, evidence blocks,
  definition of done.
- `docs/spec-pipeline/post-pr-loops.md` — post-PR CI loop, production deploy
  verification.
- `docs/spec-pipeline/model-config.md` — model configuration, PR review wiring.
- `docs/spec-pipeline/typed-judgment.md` — typed-judgment layer.
- `docs/spec-pipeline/rationale.md` — why a separate Verifier, information
  barrier, compensating control, why no BDD runner, why no scenario mutation.

## Artifact layout

```
specs/NNN-slug/                          ← PR branch only, gone on main
  00-informal.md        you write this, and only this
  10-tasks.md           specifier: numbered tasks, acceptance criteria
  15-design.md          ux designer: design read, dial values, per-task directives (frontend specs only)
  20-acceptance/
    AC-NNN-name.md      specifier: Given/When/Then scenarios, one file per task
  25-verification.md    verifier: independent re-check results, PASS/FAIL verdict
  30-report.md          architect: mutation score, complexity, gate results, remediation record
  40-deploy.md          deploy verifier: deploy evidence — deploy URL, build status, health check status, E2E verdict (frontend lanes; a recorded skip reason otherwise)

docs/changes/NNN-slug.md                 ← long-lived, on main, written by stage 5d via archive-spec.sh
```

`NNN` is a zero-padded 3-digit sequence, e.g. `001-discount-system`.

## Stop-and-Ask decision matrix

This matrix is authoritative for every pipeline agent: each agent resolves the
listed conditions per the matrix, never by improvisation.

| Condition | Deterministic action |
|---|---|
| Working tree dirty | STOP and report; never stash or auto-commit |
| Repo not found after discovery (wrong directory, `.standards/` submodule missing) | Ask for the absolute path once; never scaffold (no `git init`, no submodule creation) unprompted |
| Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`) | Tell the user to run `/spec` first; never create the artifacts yourself |
| Project type ambiguous (language stack / conformance tier undetectable) | Defer to the harness default (`mvp` tier; language per `language-specific/<lang>/SKILL.md`); ask only if interactive and unconfirmed |
| Version bump / git tag not requested | Off by default; never infer from SemVer or the diff; never create git tags — CI (Semantic Release) owns versioning |
| A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold) | Fix the code, never the threshold — gate config is off-limits to agents |
| Design gate WARN (not FAIL) | Record in the report; do not stop; flag to the Architect |
| Out-of-scope finding | Record it (Verifier: `25-verification.md`); do not fix; propose a follow-up spec |
| Acceptance criteria ambiguous | Resolve before delegating implementation — stop and ask one specific question |
| Verifier verdict FAIL | STOP the pipeline; relay the report; do not run stage-5 agents; do not fix it yourself |
| Deploy verification fails | Route per fix-routing rule; on ambiguous failure, STOP and escalate to human; never guess |
| PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green) | STOP; commit nothing, push nothing |

## Autopilot mode

Autopilot turns every "stop and ask" in this document into "choose the
documented default, record it, continue". Stops stay stops and the never-list
stays never. It is off by default; non-autopilot behavior is unchanged.

**Trigger.** An invocation is autopilot when any single argument is the literal
token `autopilot` (case-insensitive), or when `SPEC_AUTOPILOT=1` — the literal
string `1` is the only truthy value. The `/autopilot` command turns it on
explicitly for a queue run. Detection is delegated to
`scripts/autopilot-trigger.sh`; commands and agents must not re-implement the
match, and there is no `--autopilot` flag.

**No questions.** In autopilot, no stage calls the question tool, emits
`BLOCKED — <question>` as a stop, or waits for human input. Every ask row below
becomes: choose the documented default, record it, continue.

| Condition | Autopilot disposition |
|---|---|
| Working tree dirty | Continue only if every dirty path is inside the current spec folder, else STOP |
| Repo not found after discovery (wrong directory, `.standards/` submodule missing) | Use the current working directory when it is a git work tree, else STOP |
| Spec artifacts not found (`/build` without `10-tasks.md` / `20-acceptance/`) | If `00-informal.md` exists, run stage 1 and continue, else STOP |
| Project type ambiguous (language stack / conformance tier undetectable) | Choose `mvp` and the detected language, record the decision, continue |
| Version bump / git tag not requested | Never, unchanged — CI (Semantic Release) owns versioning |
| A design gate blocks (complexity ≤6, `check-code-principles.sh` FAIL, mutation below threshold) | Fix the code, never the threshold, unchanged |
| Design gate WARN (not FAIL) | Record it, unchanged |
| Out-of-scope finding | Record it and propose a follow-up spec, unchanged |
| Acceptance criteria ambiguous | Choose the most conservative reversible option, record it, continue |
| Verifier verdict FAIL | Bounded 3-cycle remediation, then STOP |
| Deploy verification fails | Bounded 3 attempts, then STOP |
| PR Opener precondition fails (branch not `spec/NNN-slug`, or `30-report.md` missing/not green) | Create `spec/NNN-slug` from current HEAD if the branch is the only failure; never push `main`; STOP if the report is not green |

### Hard stops

These are the only stops autopilot keeps. Autopilot never converts a hard stop into a guess:

1. dirty tree outside the current spec folder
2. no repo / no `00-informal.md` / no way to establish requirements
3. phase-1 or phase-2 budget exhausted
4. deploy failure after 3 attempts
5. `30-report.md` missing or not green at PR time
6. any never-list action

### Never-list

These are refusals, not decisions — autopilot never resolves them by choosing:

- no merge
- no git tag
- no push to `main`/`master`
- no force-push
- no branch deletion
- no gate-threshold change
- no secret creation/rotation
- no writes outside the target repo
- no `git init`/submodule scaffolding

### Recording decisions

Each resolved ask gets one entry in `specs/NNN-slug/45-decisions.md` with six
labelled lines: `Condition:`, `Options:`, `Chosen:`, `Why:`, `Reversibility:`,
and `At:` — an ISO-8601 UTC timestamp `YYYY-MM-DDTHH:MM:SSZ`. A run that
resolves nothing writes the single line `No autopilot decisions were required`.
`30-report.md` carries `Autopilot: true` and `Autopilot decisions: N`, where N
is the entry count in `45-decisions.md`. `scripts/autopilot-decisions.sh` is the
deterministic writer for both artifacts.

A queue run writes a morning report — `docs/changes/autopilot-YYYY-MM-DD.md`
when it opened at least one PR, `specs/autopilot-YYYY-MM-DD.md` when it opened
none — with one status block per spec in queue order. `scripts/autopilot-report.sh`
writes it deterministically, even when the queue stops at the first hard stop.
At a hard stop the queue stops; it does not skip to the next slug.

## Lite mode

A small spec may run Coder → Verifier → PR Opener → Archiver, skipping
Refactorer, Mutation Runner, UX Designer, and Deploy Verifier. Selection is
mechanical (`scripts/lite-trigger.sh`, `scripts/classify-spec-size.sh`,
`scripts/resolve-pipeline-mode.sh`) with tier guard > token > classifier,
logged in `45-decisions.md`, and refused on `production`, `multi-service`, and
an unknown tier. Every Verifier hard gate still runs
(`scripts/check-code-principles.sh` included); `30-report.md` records
`Pipeline mode: lite` and `skipped (lite)`.

Procedure: `docs/spec-pipeline/lite-mode.md`; ADR
[0020](adr/0020-pipeline-lite-mode.md).

## Commit and push carve-out

`AGENTS.md` says never commit or push without explicit instruction. The pipeline is
a narrow, stated exception:

- Only the two tail stages that write to the branch may commit and push:
  stage 5b (PR Opener) and stage 5d (Archiver) — the same `spec-pr-opener`
  agent, acting twice. 5d runs under the same commit-and-push carve-out as 5b:
  branch `spec/NNN-slug`, never `main`/`master`.
- They may commit, push, and open a **draft** PR, but only:
  - on a branch named `spec/NNN-slug`, never `main`/`master`
  - one conventional commit per task from `10-tasks.md`
  - the tracked, append-only ledger `runs.jsonl` is committed in the PR Opener's
    own docs/archive commit — never in a task commit, never gitignored, never
    left dirty in the working tree
  - only after the Verifier reports PASS and the Architect reports every
    configured gate green
- Any gate failure halts the pipeline. Nothing is committed. `30-report.md`
  explains what failed.
- The PR body links `10-tasks.md` and `30-report.md`. CI gates are the reviewer of
  record; you review the diff same as any other PR.

## Remediation budget

Every gate-failure loop in the spec pipeline is bounded. The budget has three
phases, each with its own counter, and each capped at **max 3**. The exact
phrasing `re-run until green is forbidden phrasing`: no gate is ever re-run
"until green" — every re-run is a counted attempt under one of the two
budgets.

**Phase 1 — Pre-PR loop.** The local gates and the design gates, run before
anything is pushed. On a Verifier BLOCK the pipeline hands the failing fix
back to the Coder (behavior failures) or the Refactorer (structural/complexity
failures), then re-invokes the Verifier for **scoped re-verification**: it
re-runs only the failing gates, not the whole suite. The Phase 1 budget is
**max 3**.

**Phase 2 — Post-PR loop.** The CI gates that run after the push. Its budget
is **max 3**, and its counter is independent of **Phase 1** — a Phase 1
exhaustion does not consume Phase 2 budget or vice versa. This section states
the policy; the loop's mechanics are spec 014's territory, not this document's.

**Phase 3 — deploy-verification loop.** The live-system deploy checks stage 5c
runs after the PR opened (spec 031). Its budget is **max 3** fix-and-redeploy
rounds, and its counter is independent of **Phase 1** and **Phase 2** —
exhaustion of one does not consume another's budget. The mechanics live in
`docs/spec-pipeline/deployer.md`, §Deploy verification loop (phase 3).

Phase ordering is explicit: phase 3 runs only after the phase-2 post-PR
CI loop is green — the two loops never race and phase 3 never starts early.

Exhausting either budget stops the pipeline: the stop emits the failing gate
IDs and the last evidence, and escalates to the human. This is the halt the
"Commit and push carve-out" describes — a gate failure triggers remediation up
to the cap, and only the post-exhaustion stop is the halt that wording means.
Before exhaustion, a gate failure is a re-delegation signal, not a stop.

`30-report.md` records which phase and attempt count each BLOCK was resolved
at, carried forward from the verifier's `25-verification.md` attempt entries,
so budget exhaustion is auditable.
