# 036-pipeline-agent-single-source

> Spec pipeline archive. Original source: `specs/036-pipeline-agent-single-source/` (deleted by this script).
> Archived: 2026-10-30

## Original ask

# Single source of truth for orchestrator rules

Problem: agents/spec-pipeline.md (140 lines) restates rules that also live in docs/SPEC_PIPELINE.md (remediation budgets, autopilot never-list, carve-out). Two copies drift.

Want: docs/SPEC_PIPELINE.md is the only normative source. agents/spec-pipeline.md keeps only what the orchestrator must act on at runtime (stage order, which agent per stage, stop conditions) and references doc sections by anchor instead of restating. No behavior change. Add a check (or extend check-orchestration.sh) that flags normative rules duplicated verbatim between agents/*.md and docs/SPEC_PIPELINE.md.

## Tasks

# 036 — Single source of truth for orchestrator rules: tasks

Source: `00-informal.md`. Normative source after this spec: `docs/SPEC_PIPELINE.md`.
`agents/spec-pipeline.md` becomes a runtime procedure that references the doc.
No pipeline behavior change.

Definitions used below:

- **Section reference** — a string of the form `docs/SPEC_PIPELINE.md §<Heading text>`
  where `<Heading text>` equals the text of a `##` or `###` heading in
  `docs/SPEC_PIPELINE.md` (exact match, case-sensitive, after stripping the `#`s
  and surrounding whitespace).
- **Normalized line** — a line with leading/trailing whitespace removed, a leading
  list/quote marker (`- `, `* `, `> `, `N. `) removed, and internal runs of
  whitespace collapsed to one space.
- **Verbatim duplicate** — a normalized line of at least 8 words (whitespace-split
  tokens) that appears identically in both an `agents/*.md` file and
  `docs/SPEC_PIPELINE.md`. Lines inside fenced code blocks and heading lines are
  excluded. (Threshold: see Open question Q1.)

## Task 1 — Trim `agents/spec-pipeline.md` to runtime procedure

Acceptance criteria:

- Frontmatter (`description`, `mode`, `permission` block) is byte-identical to before.
- Retains, as runtime instructions: the `scripts/judgment-preflight.sh` first action;
  the `/spec` sequence (`spec-specifier` then `spec-ux`, stop for human review,
  relay `BLOCKED`, note `SKIPPED`); the `/build` order `spec-coder` →
  `spec-refactorer` → `spec-verifier` → `spec-mutation-runner` → `spec-pr-opener`;
  the stop conditions (Verifier non-PASS → no stage-5 agents; Mutation Runner not
  green → no PR Opener; any stage cannot proceed → stop and relay; remediation
  budget exhausted → stop and escalate; autopilot hard stop → write morning report
  and stop queue); the `SPEC_LOOP_COUNT`/`SPEC_PHASE1_RETRIES`/`SPEC_PHASE2_RETRIES`
  export instruction.
- Does NOT restate: the nine never-list bullets (no merge, no git tag, …), the
  commit/push carve-out conditions, the autopilot trigger definition
  (`autopilot` token / `SPEC_AUTOPILOT=1`), or the remediation-budget rules beyond
  naming the cap. Each is replaced by a section reference to
  `§Autopilot mode` / `§Never-list`, `§Commit and push carve-out`,
  `§Remediation budget`, `§Post-PR CI check-and-remediate loop (phase 2)`.
- Contains at least one section reference for each of: `Remediation budget`,
  `Never-list`, `Commit and push carve-out`, `Autopilot mode`,
  `Stop-and-Ask decision matrix`.
- File is shorter than 140 lines.

## Task 2 — No normative content lost

Acceptance criteria:

- Every rule removed from `agents/spec-pipeline.md` in Task 1 is present in
  `docs/SPEC_PIPELINE.md`: max 3 phase-1 cycles, independent max-3 phase-2 budget,
  all nine never-list items, the carve-out branch/`30-report.md` precondition, the
  autopilot trigger.
- Any such rule missing from the doc is added to the doc in the relevant section
  (not left only in git history).
- No other `docs/SPEC_PIPELINE.md` rule is changed in meaning (diff limited to
  additions needed by this task and, if any, deduplication-neutral edits).

## Task 3 — Duplication check script

Acceptance criteria:

- New script `scripts/check-agent-doc-duplication.sh` (POSIX bash, `set -euo pipefail`).
- Compares every `agents/*.md` against `docs/SPEC_PIPELINE.md` using the
  "verbatim duplicate" definition above.
- Exit 0 and prints a single OK line when no verbatim duplicate exists.
- Exit 1 when ≥1 duplicate exists; prints one line per duplicate in the form
  `<agent-file>:<line-number>: duplicated from docs/SPEC_PIPELINE.md:<line-number>`.
- Also validates section references: each `docs/SPEC_PIPELINE.md §<Heading>` in
  `agents/*.md` must match a heading (definition above); each unresolved one is
  printed as `<agent-file>:<line-number>: unresolved section reference §<Heading>`
  and causes exit 1.
- Exit 2 on usage error / missing `docs/SPEC_PIPELINE.md` or `agents/` directory.
- Accepts an optional repo-root argument (default: current directory) so tests can
  run it against fixtures.
- A selftest `scripts/check-agent-doc-duplication.selftest.sh` exercises the
  scenarios in AC-036-03 against temp fixtures.

## Task 4 — Wire the check and pass on the repo

Acceptance criteria:

- `scripts/check-orchestration.sh` invokes `scripts/check-agent-doc-duplication.sh`
  and fails (exit 1) when it fails. (See Q2.)
- Running `scripts/check-agent-doc-duplication.sh` on the repo after Tasks 1–2
  exits 0 (all agents, not just `spec-pipeline.md`).
- Existing `scripts/check-orchestration.sh` checks still exit 0 on the repo.

## Open questions

- **Q1 (threshold):** "Duplicated verbatim" has no size in the informal spec. This
  spec assumes a normalized line of ≥8 words. Confirm or give another threshold
  (shorter lines like "Never commit or push" would otherwise false-positive).
- **Q2 (placement):** Informal allows a new check or extending
  `check-orchestration.sh`. This spec chooses a standalone script called from
  `check-orchestration.sh`. Confirm.
- **Q3 (conflict with 037):** `specs/037-split-spec-pipeline-doc` may split
  `docs/SPEC_PIPELINE.md`. If 037 lands first, the "normative source" and section
  references must cover the split files. Confirm 036 runs before 037, or widen the
  doc set.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Duplicate threshold: >=8 words after whitespace/list-marker normalization.
- Standalone `scripts/check-agent-doc-duplication.sh`, invoked by `check-orchestration.sh`.
- 036 lands before 037.
- ADR `docs/adr/0017-pipeline-agent-single-source.md` is in scope (required by `check-pr-review.sh` AC-024-01-12; 0016 is claimed by open PR #106).

## Acceptance scenarios

## AC-036-01-01 — Frontmatter unchanged
## AC-036-01-02 — Stage order retained
## AC-036-01-03 — /spec flow retained
## AC-036-01-04 — Stop conditions retained
## AC-036-01-05 — Runtime actions retained
## AC-036-01-06 — Never-list not restated
## AC-036-01-07 — Doc rules referenced, not restated
## AC-036-01-08 — File shrinks
## AC-036-02-01 — Remediation budgets present in doc
## AC-036-02-02 — Never-list complete in doc
## AC-036-02-03 — Carve-out and autopilot trigger present in doc
## AC-036-03-01 — Clean fixture passes
## AC-036-03-02 — Verbatim duplicate flagged
## AC-036-03-03 — Whitespace and list-marker differences still match
## AC-036-03-04 — Below threshold ignored
## AC-036-03-05 — Exactly threshold flagged
## AC-036-03-06 — Code blocks and headings excluded
## AC-036-03-07 — Unresolved section reference flagged
## AC-036-03-08 — Resolved ### reference accepted
## AC-036-03-09 — Missing inputs
## AC-036-04-01 — Repo passes the new check
## AC-036-04-02 — check-orchestration propagates failure
## AC-036-04-03 — check-orchestration still green on repo

## Verification

# 036 — Verification (stage 4)

Attempt 1, phase 1. Worktree: spec-036 (uncommitted working tree on top of 5e82a2d).

## Overall verdict: PASS (attempt 2, phase 1 — see re-verification below; attempt 1 was FAIL)

Failing gate: `traceability` (structural — test-carrier/ID-naming defect, not a behavior defect).
All other gates green. Pipeline stops; stage-5 agents must not run.

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 1
at: 2026-10-30T18:08:50Z

{
  "checks": [1, 2],
  "passes": ["AC-036-01-01 — traced to a test", "AC-036-01-02 — traced to a test", "AC-036-01-03 — traced to a test", "AC-036-01-04 — traced to a test", "AC-036-01-05 — traced to a test", "AC-036-01-06 — traced to a test", "AC-036-02-01 — traced to a test", "AC-036-02-02 — traced to a test", "AC-036-02-03 — traced to a test", "AC-036-03-01 — traced to a test", "AC-036-03-02 — traced to a test", "AC-036-03-03 — traced to a test", "AC-036-03-04 — traced to a test", "AC-036-03-05 — traced to a test", "AC-036-03-06 — traced to a test", "AC-036-03-07 — traced to a test", "AC-036-03-08 — traced to a test", "AC-036-04-01 — traced to a test", "AC-036-04-02 — traced to a test", "AC-036-04-03 — traced to a test"],
  "fails": ["AC-036-01-07 — scenario defined in specs/*/20-acceptance/ but no test references it.  Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete  and remove the scenario instead of leaving it untraced.", "AC-036-01-08 — scenario defined in specs/*/20-acceptance/ but no test references it.  Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete  and remove the scenario instead of leaving it untraced.", "AC-036-03-09 — scenario defined in specs/*/20-acceptance/ but no test references it.  Add a test named after this ID, or confirm with 10-tasks.md that it's obsolete  and remove the scenario instead of leaving it untraced."]
}

Human-mode tail (same run set): `✘ Scenario traceability check: 3 violation(s).`

Verifier note (does not override the script): the three IDs are referenced only in
`scripts/check-agent-doc-duplication.selftest.sh`, which the checker does not count as a
test carrier. Further, the spec-036 scenario IDs are unprefixed (`AC-036-01-..`, `AC-036-03-..`)
and collide with earlier specs' IDs (e.g. `scripts/tests/ac-001-harness.bats` defines
`AC-036-01-01..06`; `ac-004-005-007-trace.bats` etc.), so several "passes" above may be
satisfied by unrelated older tests rather than spec-036 tests. Remediation route: Coder/
Specifier — give spec-036 scenarios spec-unique IDs (e.g. `AC-036-NN`) and reference them
from a carrier the checker scans (a `scripts/tests/*.bats` file).

## Evidence: full test suite

command: make test
exit: 0
at: 2026-10-30T18:09:03Z

Checking bats assertions are not vacuous...
1..710
... (710 `ok` lines, 0 `not ok`, 0 `# skip` directives; "SKIPPED" matches are test names only)
ok 709 unit: state exactly at the cap is not truncated and emits no reason
ok 710 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

Supplementary (spec-036 carrier, wired into self-ci.yml):

command: bash scripts/check-agent-doc-duplication.selftest.sh
exit: 0
at: 2026-10-30T18:09:03Z

PASS AC-036-04-02 check-orchestration propagates failure
PASS AC-036-04-03 check-orchestration green on repo

selftest: 26 passed, 0 failed

command: scripts/check-agent-doc-duplication.sh
exit: 0
at: 2026-10-30T18:09:03Z

OK: agents/*.md duplicate no docs/SPEC_PIPELINE.md rule and all section references resolve

## Evidence: complexity gate

command: shellcheck -S warning scripts/check-agent-doc-duplication.sh scripts/check-agent-doc-duplication.selftest.sh scripts/check-orchestration.sh
exit: 0
at: 2026-10-30T18:12:59Z

(no output)

Info-level run (`shellcheck` default severity, exit 1 at 2026-10-30T18:12:51Z) reports only
SC2016 (info) — selftest.sh lines 98, 99, 107, 117 (intentional literal backticks in fixtures);
check-orchestration.sh lines 89, 104 (pre-existing, not in diff). self-ci runs shellcheck with
`continue-on-error: true`. Not a finding.

## Evidence: design-principles gate

command: scripts/check-code-principles.sh scripts --json -BaseRef HEAD
exit: 0
at: 2026-10-30T18:13:02Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": []
}

(An earlier invocation passing individual files as SOURCE_DIR exited 2 with
`ERROR: source directory 'scripts/check-orchestration.sh' is missing or unreadable` — a
usage error by the Verifier, superseded by the directory run above.)

## Evidence: scenario-to-behavior spot check

command: manual read of 20-acceptance/AC-036-03-duplication-check.md vs scripts/check-agent-doc-duplication.selftest.sh; git diff scripts/tests/autopilot-orchestrator.bats
exit: 0
at: 2026-10-30T18:13:30Z

- AC-036-03-02: Given/When/Then requires exit 1 and exact line
  `agents/x.md:5: duplicated from docs/SPEC_PIPELINE.md:20`. Test (selftest.sh:84) asserts
  `RC -eq 1` and `grep -qxF` of that exact line. MATCH.
- AC-036-03-03: requires exit 1 + duplicate reported for whitespace/list-marker variant. Test
  (selftest.sh:86-88) uses `-   Do not   run stage-5 agents ...`, asserts RC 1 and
  `duplicated from`. MATCH (does not assert line numbers; scenario doesn't require them).
- Flagged pre-existing test edit AC-035-16 (autopilot-orchestrator.bats): the nine never-list
  assertions now run against docs/SPEC_PIPELINE.md, plus a new `grep -qF
  'docs/SPEC_PIPELINE.md §Never-list'` on the agent; `hard stop` and `never a decision` still
  asserted on the agent. Assertion strength preserved, consistent with Task 1/Task 2. Accepted;
  Architect to note it modifies a prior spec's test.

## No unaccounted behavior

Finding: diff limited to agents/spec-pipeline.md trim, section-reference edits in three other
agents, new duplication script + selftest, check-orchestration.sh §5 wiring, self-ci.yml selftest
line, AC-035-16 adjustment, and ADR docs/adr/0016-pipeline-agent-single-source.md + README index
row. ADR is not listed in 10-tasks.md — likely legitimate (GOVERNANCE ADR requirement for pipeline
changes) but Coder must justify. No unaccounted runtime logic.

---

# Re-verification — attempt 2, phase 1

Scope: gates `traceability` (prior FAIL) and `test-suite` (affected by new bats file). Also re-ran design-principles and orchestration as affected-by-change sanity (both exit 0). Complexity/spot-check/unaccounted prior results stand.

## Evidence: scenario traceability (attempt 2)

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-30T18:23:54Z

{
  "checks": [1, 2],
  "passes": ["AC-036-01 — traced to a test", "AC-036-02 — traced to a test", "AC-036-03 — traced to a test", "AC-036-04 — traced to a test"],
  "fails": []
}

WARN (does not override script): checker reports at AC-NNN-NN granularity, not AC-NNN-NN-MM. Verifier cross-check: all 27 unique AC-036-NN-MM IDs in 20-acceptance/ are referenced in scripts/tests/ac-036-pipeline-agent-single-source.bats (0 missing). Flag to Architect: checker ID regex truncates 4-part IDs.

## Evidence: full test suite (attempt 2)

command: make test
exit: 0
at: 2026-10-30T18:23:56Z

Checking bats assertions are not vacuous...
ok 174 AC-036-01-01: selftest scenario passes
ok 175 AC-036-01-02: selftest scenario passes
ok 176 AC-036-01-03: selftest scenario passes
...
ok 733 unit: state exactly at the cap is not truncated and emits no reason
ok 734 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)

Counts: 734 ok, 0 not ok, 0 `# skip`; 24 AC-036 tests ran.

Sanity: scripts/check-code-principles.sh exit 0; scripts/check-orchestration.sh exit 0; docs/adr/0017-pipeline-agent-single-source.md present.

## Verdict (attempt 2): PASS — gatesFailed: none

## Post-PR CI check (phase 2)

### Round 1 — attempt 1, phase 2

command: gh pr checks 107 --repo RexiAI/my-engineering-standards --watch; gh pr checks 107 --json name,state,bucket,workflow,link
at: 2026-10-30T18:33:43Z
exit: 1

| Check | Workflow | Result | Check-run ID |
|---|---|---|---|
| Review PR / Review PR | PR Review Agent | PASS | — |
| Validate (run 41107870835) | Self CI | FAIL | 124242347305 |
| Validate (run 41107861928) | Self CI | FAIL | 124242319963 |

Pre-existing vs this PR: Self CI on `main` is green (last 3 runs: 40671277600, 40343275009, 40312185310 — all `success`). The PR #106 failures are not on main. This failure is caused by this PR.

Failing log excerpt (`gh run view 41107870835 --log-failed`):

```
  [FAIL] 036-pipeline-agent-single-source is finished (has 30-report.md) but not archived — missing docs/changes/036-pipeline-agent-single-source.md
         Run: scripts/archive-spec.sh 036-pipeline-agent-single-source (stage 5d does this automatically)
1 finished spec(s) not archived!
##[error]Process completed with exit code 1.
```

Classification: structural (pipeline-process / archive gate), not behavioral — no test assertion failed; all AC test lines in the log PASS. Fix: run stage 5d `scripts/archive-spec.sh 036-pipeline-agent-single-source` (PR Opener), push, re-trigger scoped re-check of check IDs 124242347305 / 124242319963.

Round verdict: FAIL

## Quality gates

# 036 — Mutation Runner report (stage 5a)

## Verifier verdict (carried forward)

PASS — attempt 2, phase 1 (`25-verification.md`, "Verdict (attempt 2): PASS — gatesFailed: none"). Attempt 1 was FAIL on `traceability`.

## Mutation score

skipped — `mvp` tier (tier per `25-verification.md` design-principles gate JSON: `"tier": "mvp"`). Mutation testing is a `production`-tier gate per `docs/SPEC_PIPELINE.md §Conformance tiers`. No mutation tool run; no mutation-kill tests written.

## Complexity summary (carried from Refactorer/Verifier)

- `shellcheck -S warning` on `scripts/check-agent-doc-duplication.sh`, `scripts/check-agent-doc-duplication.selftest.sh`, `scripts/check-orchestration.sh`: exit 0 (2026-10-30T18:12:59Z). Info-level SC2016 only (intentional literal backticks / pre-existing).
- `scripts/check-code-principles.sh scripts --json -BaseRef HEAD`: exit 0 (2026-10-30T18:13:02Z), tier `mvp`, gates incl. complexity — no FAIL.

## Equivalent mutants

none — mutation testing not run (mvp tier).

## Final test status

command: make test
exit: 0
at: 2026-10-30T18:32:02Z

1..734 — 734 ok, 0 not ok. Tail: `test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)`. No new code added by this stage; run re-confirms the Verifier's attempt-2 result.

## Remediation record

- BLOCK: `traceability` gate FAIL at verification attempt 1, phase 1 (AC-036-01-07, AC-036-01-08, AC-036-03-09 untraced by a scanned carrier).
- Resolved: phase 1, attempt 2 (re-verification PASS, 2026-10-30T18:23:56Z).
- Phase 2: none (no PR yet).

PR: https://github.com/RexiAI/my-engineering-standards/pull/107
Commits: 4 (task commits; plus this docs(spec) record commit)

## 40-deploy.md

# 40-deploy — 036-pipeline-agent-single-source

PR: #107
Deploy URL: n/a
Build status: skip
Health check status: skip
E2E verdict: skip
Phase-3 attempt: 0 (not applicable)
Timestamp: 2026-10-30T18:34:23Z

## Repo classification

command: ls vercel.json package.json; grep -E '"(react|next|@angular/core|@ionic/[a-z-]+)"' package.json
exit: 2
at: 2026-10-30T18:34:23Z

```
ls: cannot access 'vercel.json': No such file or directory
ls: cannot access 'package.json': No such file or directory
```

No `vercel.json`, no `package.json` with a frontend framework, and no Vercel Git integration — this is a standards repo, not a frontend.

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable
