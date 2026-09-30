---
name: ci-triage
description: Triage a failing Self CI run on this repo — read the failing logs with gh, classify the failure as flake / regression / infra / config, and at L1 report-only escalate to a human or propose a minimal fix from an isolated worktree. Use when a Self CI run fails on a branch or PR, when the CI Sweeper workflow invokes a sweep, or when asked to diagnose why CI is red.
license: See repo root
allowed-tools: Bash(gh:*) Bash(git worktree add:*) Bash(scripts/typed-judgment.sh:*)
---

# When to use

A Self CI run failed on a branch or PR and someone — a human or the CI Sweeper
workflow (`.github/workflows/ci-sweeper.yml`) — needs it triaged. This is the
CI Sweeper loop's entry point. The loop is spec 017; its safety rules, state
files, and readiness levels come from spec 016 (`docs/LOOP_ENGINEERING.md`,
consumed by reference — do not re-specify them here).

# Invocation

The failing-log read used by this repo is the `gh` CLI (installed and
authenticated with `repo` scope): list the runs, then read the failed log.

```bash
gh run list --workflow "Self CI"
gh run view <RUN-ID> --log-failed
```

The **Self CI** workflow (`.github/workflows/self-ci.yml`) is the only CI that
runs on feature branches and PRs, and it has a single job, **Validate** — so the
failing job is `Validate` unless the run failed before the job started.

# Classification output

Every triage produces exactly one output with three parts:

1. **class** — exactly one of `flake`, `regression`, `infra`, `config`;
2. **failing job/step** — the job and step that failed (Self CI has one job,
   `Validate`, so name the failing step);
3. **evidence** — the log line, file:line, or step name that drove the
   classification. No classification without evidence.

# Decision guide

| Class | Meaning | Action |
|---|---|---|
| `flake` | Seen before, intermittent, or passed on retry with no code change | **Watch**, log, route to quarantine — never fix |
| `regression` | A code change introduced the failure; deterministic on the failing commit | Minimal fix in a worktree (see below) |
| `infra` | Runner OOM, registry down, secrets missing, or another environment failure | Escalate — not a code defect |
| `config` | Workflow syntax, wrong tool version, or a configuration error | Escalate — not a code defect |

The flake criteria: **seen before** (the same signature is already in the
quarantine ledger), **intermittent** (fails sometimes, passes other times on the
same commit), or **passed on retry with no code change** (a rerun of the same
commit was green).

# Typed-judgment fast-path (opt-in, spec 028)

This fast-path is **opt-in and never authoritative**: a typed judgment is a
probabilistic classification hint, not a gate. The Decision guide table above
remains the source of the rubrics and the final word on routing.

**Gate:** both `JUDGMENT_API_URL` and `JUDGMENT_API_KEY` must be set and
non-empty in the environment. If either is unset or empty, **skip this section
entirely** — the stock LLM classification procedure below runs unchanged and
the run-log records no judgment fields at all (behavior identical to
pre-integration).

When configured, after gathering the `gh` evidence and before classifying by
hand, build the state JSON from that evidence — exactly these fields:

```json
{ "failed_log_excerpt": "<the failing log lines>",
  "changed_files": ["<paths from the failing commit>"],
  "prior_state_entries": ["<matching STATE.md / quarantine entries>"] }
```

Write it to a temp file and ask exactly one Choice question whose options are
the four classes and whose criteria are the rubrics from the Decision guide
table above:

```bash
scripts/typed-judgment.sh --state-file "$STATE_JSON" \
  --questions '{"classification":{"type":"choice","instructions":"Classify this failing CI run as exactly one of flake, regression, infra, config.","criteria":"flake: seen before, intermittent, or passed on retry with no code change; regression: a code change introduced the failure, deterministic on the failing commit; infra: runner OOM, registry down, secrets missing, or another environment failure; config: workflow syntax, wrong tool version, or a configuration error.","options":["flake","regression","infra","config"]}}'
```

Then branch on the script's exit code:

- **exit 0** — stdout carries the normalized answer. Use the typed answer as
  the `class` field of the classification output (the three-part output rule
  still applies: evidence must back it — cite the same log evidence you
  gathered). Record in `loop-run-log.md`:
  `{"judgment":"classification","answer":"<answer>","confidence":<0..1>,"latency_ms":<ms>,"tokens":<n>,"fallback":false,"judgment_fallback":false}`.
- **exit 10** (fallback: not configured after all, cap exceeded, API error,
  or confidence below `JUDGMENT_MIN_CONFIDENCE`) — run the existing LLM
  classification procedure unchanged and record
  `{"judgment":"classification","judgment_fallback":true}` in the run-log.

Never let a typed judgment change the flake rule, the infra/config
"not a code defect" routing, the maker/checker split, or the escalation
gates — those stay with the deterministic procedure and the human.

# The flake rule

A flake is classified as **Watch**, never auto-fix. A flake is logged and routed
to quarantine, not fixed: append the flake signature, evidence, and first/last
seen dates to the quarantine ledger `docs/ci-flakes.md`, and consult that ledger
for "seen before" before classifying anything as a repeat.

# Infra and config are not code defects

Infrastructure failures (runner OOM, registry down, secrets missing) and
workflow-config failures (workflow syntax, missing tooling) are **not code
defects**. They are routed to escalation, never "fixed" by editing code.

# Isolated fix flow

For a `regression`, the fix is the **smallest change** that addresses the
specific failure, made in an isolated worktree via `git worktree add` — never on the swept branch, and never on `main`.
Work on a branch in the worktree and let the checker (next section) verify before anything is proposed.

# Maker/checker split

The fixing pass (maker) and a separate checking pass (checker) are distinct —
the same agent never both produces and approves. The checker confirms before any PR or comment is proposed, that:

- (a) the fix addresses the failure — verified against the failing commit's log,
  not a guess;
- (b) there are no unrelated changes — the diff touches only what the failure
  needs;
- (c) tests and lint pass — the local suite plus `make validate-all` / `make lint`.

# Bounded remediation

Remediation is bounded: at most **3 attempts** per failure. Each attempt is
recorded in `loop-run-log.md` (spec 016's append-only file, one `run_id` per
failure) per its JSON schema. This counter is the loop's own **circuit breaker**,
independent of spec 008's pipeline budget and 014's round counter — a
sweeper that runs tomorrow is never capped by a pipeline budget that ran today.

# Escalation

On attempt exhaustion the loop escalates to a human with pruned context: the
failing job, the run link, and the last log excerpt. The escalation surface is a
GitHub issue (the repo's human handoff channel) carrying that context, under the
stable label `ci-sweeper`. The loop never loops forever.

Escalate when any of these holds:

- infrastructure failure (runner OOM, registry down, secrets missing);
- the failure touches more than 5 files or core architecture;
- security-sensitive failures;
- max attempts exceeded;
- intermittent flakes needing quarantine.

# Deferral

Before starting a fix, check `STATE.md` (spec 016's durable state). When
`STATE.md` shows an in-flight remediation of the same failure on the same branch
— the 014-owned `spec/NNN-slug` case — the sweeper defers rather than competing
with the pipeline's own post-PR loop.

# State contract — STATE.md CI Sweeper section

The **CI Sweeper** section of `STATE.md` (spec 016's durable state file,
consumed by reference, not re-specified) records one block per in-flight failure
with these fields:

- last run timestamp
- failing commit SHA
- failing job
- attempt count
- worktree/PR link
- outcome

The section is updated on each run; resolved failures are removed from the CI
Sweeper section each run, while in-flight failures are retained.

`STATE.md` and `loop-run-log.md` are spec 016's files, consumed by reference.
The CI Sweeper section is operative only after 016's foundation lands; until
then the loop records state at L1 (report) and never runs unattended.

# Cost guidance

- The loop exits early when CI is green — the workflow trigger skips green runs;
  the loop itself must also short-circuit.
- No full sweep on a no-op run: no code change since the last sweep, or the
  failure is already resolved.
- Record the per-run token estimate (`tokens_estimate`) per spec 016's
  `loop-run-log.md` schema.

# Readiness

This loop runs at **L1 (report)** — it triages and reports, and does not run
unattended fixes. The standing rules (path denylist, no auto-merge, human
gates) live in `docs/LOOP_ENGINEERING.md` and `templates/loop-constraints.md`;
merging any PR this loop proposes is always a human action.
