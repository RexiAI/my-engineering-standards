# 003-deterministic-gate-runner

> Spec pipeline archive. Original source: `specs/003-deterministic-gate-runner/` (deleted by this script).
> Archived: 2026-08-15

## Original ask

# 003 — Deterministic gate-runner

## Why

Spec-pipeline agents today run their own judgement on whether a behavior
is "shippable": the Refactorer decides whether complexity is OK, the
Verifier checks the trace by reading files, the Architect decides what
mutation score passes. Subjective calls. They pass when the agent
thinks they pass; the agent's self-report is the only evidence.

Reference: ACDC's `scripts/gates/gate-runner.{sh,ps1}` plus
`design-checker.sh` make the same checks mechanical. One script returns
JSON + exit code; every agent routes its verdict through that JSON; a
dry-run script proves the harness itself works against throwaway fixture
projects.

This is **Phase B**. It adds the deterministic gate-runner plus its
self-test and the design gates (D1–D11, SOLID/DRY/YAGNI/KISS made
mechanical). Phases C (hooks) and D (PR orchestration) wire the runner
up.

## What I want

A new `scripts/gates/` directory containing:

- `gate-runner.sh` — the single entry point. Flags
  `-Phase local|design|scenarios|pr|all`, `-BaseRef <ref>`,
  `-RepoPath <path>` (defaults to `$PWD`), `-Gates <id1,id2,...>`.
  Exit `0` = PASS, `1` = BLOCK. Writes
  `<RepoPath>/.civ/gate-report.json` — repo-scoped, never
  harness-scoped.
- `find-harness.sh` — single resolver. `CIV_GATES_DIR` override →
  `${REPO_ROOT}/scripts/gates` → `plugins/acdc-civ/scripts/gates` →
  installed plugins → the script's own dir. All consumers (Verifier,
  Architect, hook layer, docs) get the same harness.
- `design-checker.sh` + `design-gates.defaults.json` — D1–D11 design
  gates. Scoped to the diff (`git diff <baseRef>...HEAD --name-only`).
  Pre-existing debt in a touched file is WARN; debt introduced by this
  diff is BLOCK. Thresholds overridable per-repo via
  `.design-gates.json` (which an agent can never edit to make a gate
  pass — threshold changes are human-reviewed).
- `dry-run.sh` — self-test the harness with throwaway fixture projects
  (library/spec, ambiguous/spec, microservices-shaped). Writes
  `.civ-dryrun/dry-run-summary.json`. Needs only `bash`, `git`, `jq` —
  no JDK, Maven, cluster. Exits `0` only when every assertion passes.
- `README.md` — usage, the JSON report schema, the SKIP-not-pass rule.

The gate set, scoped to this repo (no full Java service gates):

- **G0** Pre-flight: clean tree, branch `spec/NNN-slug`, base reachable.
- **G1** Build/format: language-specific, delegates to the project's
  own build command.
- **G2** Test: language-specific, same.
- **G3** Security: language-specific, SKIP if no CLI.
- **G4** Quality: language-specific, SKIP if no CLI.
- **G5** Startup: N/A for this repo (it's a library). Always SKIP.
- **G6** PR: branch policy + commit prefix + PR body.
- **G7** Deploy: N/A. SKIP.
- **G8** Docs: `CHANGELOG.md` updated. WARN-only.
- **D1–D11** Design gates via the language guide.
- **S1** Scenario traceability — wraps the existing
  `scripts/check-scenario-traceability.sh` (unchanged).
- **S2** Mutation coverage — calls `scripts/mutation.sh` if it exists;
  SKIP otherwise (mutation testing lands in a future spec).

## What I don't want

- Java-specific gate implementations. This repo is shell + Markdown +
  Makefile. The runner accepts a `.civ/gate-profile.json` per-repo
  override; default profile is this repo's.
- Mutation testing in this change. The `S2` SKIP-not-pass fallback
  covers the gap until `add-mutation-testing` lands.
- CI integration in this phase. `.github/workflows/*` learn to call the
  runner in a follow-up.
- Cross-platform `.ps1` twins. This repo is Linux-only; child repos
  can vendor their own. (Open question.)

## Out of scope

- Changes to any agent spec (those are Phases C and D).
- New gates beyond what's listed above.

## How child repos will use this

The runner lives at `scripts/gates/`. Child repos vendor this entire
repo via the `.standards/` submodule, gaining the runner automatically
when they bump the submodule. Phase C wires the hook layer; Phase D
wires the orchestration skill.

## Tasks

# 003 — Deterministic gate-runner: Tasks

`scripts/gates/` shell scripts only (no `.ps1` twins this phase; Linux-only).
No behavior change until Phase C/D wire it up; the runner ships as a *new
surface* that coexists with existing entry points.

## Dependency order

1. **Task 1** (`gate-runner.sh` + `find-harness.sh` + `README.md`) is
   the spine; implement first.
2. **Task 2** (design-checker + defaults) depends on Task 1's `-Phase
   design` contract.
3. **Task 3** (dry-run) depends on Tasks 1 + 2.
4. **Task 4** (`gitignore`, runner state) depends on Tasks 1–3.
5. **Task 5** (composition with existing scripts) depends on Task 1.
6. **Task 6** (verify before merge) runs last.

---

## Task 1 — Author the harness

Create `scripts/gates/`.

- `gate-runner.sh` — POSIX entry point. Flags:
  `-Phase local|design|scenarios|pr|all`, `-BaseRef <ref>`,
  `-RepoPath <path>`, `-Gates <id1,id2,...>`. Exit `0` PASS, `1`
  BLOCK. Writes `<RepoPath>/.civ/gate-report.json`.
- `find-harness.sh` — single resolver.
  Order: `${CIV_GATES_DIR}` → `${REPO_ROOT}/scripts/gates` →
  `plugins/acdc-civ/scripts/gates` → installed plugins → self dir.
- `README.md` — usage, the JSON report schema, the SKIP-not-pass rule,
  threshold edit policy.

Acceptance criteria:

- `bash scripts/gates/find-harness.sh` prints the harness dir, exits `0`.
- `bash scripts/gates/gate-runner.sh -Phase local -RepoPath . -BaseRef
  HEAD` exits `0` on a clean repo.
- `gate-runner.sh -Phase all -Gates G0` re-runs only G0 and produces
  the same JSON schema.

---

## Task 2 — Author the design gates

- `scripts/gates/design-checker.sh` — D1–D11 (size/complexity, SRP,
  ISP, DIP, DRY, naming, coupling, dead code, YAGNI, test delta, KISS
  composite). Scoped to `git diff <baseRef>...HEAD --name-only`.
- `scripts/gates/design-gates.defaults.json` — defaults per the spec
  (class ≤ 300 lines, method ≤ 30, cyclomatic ≤ 10, etc.).
- Per-repo override via `.design-gates.json`. An agent can never
  edit either file to make a gate pass — threshold changes are
  human-reviewed.

Acceptance criteria:

- D1 catches a synthetic oversized class in the fixture (Task 3).
- A diff that adds no violations but touches a file with pre-existing
  violations shows the gate as WARN, not BLOCK.
- Design defaults match the spec exactly.

---

## Task 3 — Author the dry-run / self-test

- `scripts/gates/dry-run.sh` — three fixture scenarios
  (library/spec, ambiguous/spec, microservices-shaped). Asserts each
  scenario's exit code, `status`, `projectType`, and per-gate status.
- Writes `.civ-dryrun/dry-run-summary.json`.
- Needs only `bash` + `git` + `jq`. No JDK, Maven, cluster.

Acceptance criteria:

- On a fresh machine (only `bash`, `git`, `jq`), the script exits `0`
  and writes the summary.
- The summary shows every expected assertion's pass/fail.

---

## Task 4 — Author `.civ/` runner state

- Add `.civ/` and `.civ-dryrun/` to `.gitignore`.
- Document the report paths in `scripts/gates/README.md`.

Acceptance criteria:

- `grep .gitignore` lists both `.civ/` and `.civ-dryrun/`.
- `README.md` example output reproduces from a clean clone.

---

## Task 5 — Compose with existing scripts

- `local` phase invokes `scripts/check-scenario-traceability.sh` as
  `S1` (unchanged).
- `local` phase composes the six `check-*.sh` and two
  `detect-*.sh` scripts under the appropriate phase.
- `S2` (mutation coverage) is invoked if `scripts/mutation.sh`
  exists; SKIP with a note otherwise.

Acceptance criteria:

- The legacy scripts run identically when invoked directly.
- The runner's `S1` exit code matches the legacy script's exit code.

---

## Task 6 — Verify before merge

- `bash scripts/gates/dry-run.sh` is green.
- `bash scripts/gates/gate-runner.sh -Phase local -RepoPath .
  -BaseRef HEAD` exits `0` on this clean repo.
- README example output reproducible from a clean clone.

Acceptance criteria:

- All three checks pass.

## Acceptance scenarios

## AC-001-01 — `find-harness.sh` exists and resolves
## AC-001-02 — `find-harness.sh` honors `CIV_GATES_DIR` override
## AC-001-03 — `find-harness.sh` fails loudly on bad override
## AC-001-04 — `gate-runner.sh -Phase local` runs on a clean repo
## AC-001-05 — Scoped re-verification runs only requested gates
## AC-001-06 — `README.md` documents usage
## AC-002-01 — `design-checker.sh` implements D1–D11
## AC-002-02 — Defaults match the spec exactly
## AC-002-03 — Design gates are scoped to the diff
## AC-002-04 — Newly introduced violations BLOCK
## AC-003-01 — Default dry-run is portable
## AC-003-02 — Each fixture scenario produces a known status
## AC-003-03 — SKIP is not a blocking failure
## AC-004-01 — `.civ/` is gitignored
## AC-004-02 — `.civ-dryrun/` is gitignored
## AC-004-03 — `git status` does not show runner state
## AC-005-01 — `S1` exit code matches the legacy script
## AC-005-02 — `S2` is invoked when `scripts/mutation.sh` exists
## AC-005-03 — `S2` SKIPs when `scripts/mutation.sh` is absent
## AC-005-04 — Legacy scripts remain runnable directly
## AC-006-01 — Dry-run is green
## AC-006-02 — `gate-runner.sh -Phase local` is green on this repo
## AC-006-03 — README example output is reproducible

## Verification

# 003 — Verification

Populated by `spec-verifier` after Coder + Refactorer finish.

## Re-execution checklist

- [ ] `bash scripts/gates/dry-run.sh` exits `0` and writes
  `.civ-dryrun/dry-run-summary.json`
- [ ] `bash scripts/gates/find-harness.sh` prints an absolute path
  and exits `0`
- [ ] `bash scripts/gates/find-harness.sh` honors `CIV_GATES_DIR`
- [ ] On a non-existent harness path, `find-harness.sh` exits
  non-zero with stderr message
- [ ] `bash scripts/gates/gate-runner.sh -Phase local -RepoPath .
  -BaseRef HEAD` exits `0` on a clean tree
- [ ] Scoped re-verification (`-Gates G0`) produces the same JSON
  schema as a full run
- [ ] `scripts/gates/design-checker.sh` defines D1–D11
- [ ] `design-gates.defaults.json` matches the exact thresholds in
  the spec (300/30/10/5/7/5/10/3/5)
- [ ] `.gitignore` contains `.civ/` and `.civ-dryrun/`
- [ ] `scripts/check-scenario-traceability.sh` S1 exit matches the
  legacy direct invocation

## Verdict

- [ ] PASS
- [ ] FAIL — see scenarios below for which AC files are
  unsatisfied.

## Quality gates

# 003 — Architect Report

Populated by `spec-architect` after Verifier passes.

## Dry-run summary

- Dry-run total checks: _(from dry-run-summary.json `totalChecks`)_
- Dry-run failed checks: _(from `failedChecks`)_
- Overall: _(PASS/FAIL)_

## Gate results

| Gate | Status | Notes |
|---|---|---|
| G0 | _(from gate report)_ | |
| G1 | | |
| G2 | | |
| G6 | | |
| S1 | | |
| S2 | | (likely SKIP) |
| D1–D11 | | |

## Branch / commit summary

- Branch: `spec/003-deterministic-gate-runner`
- Commit count: _(populated by Architect)_
- Tasks touched: 6 of 6

## Verdict

(Populated by `spec-architect`.)
