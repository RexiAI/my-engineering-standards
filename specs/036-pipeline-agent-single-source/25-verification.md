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
