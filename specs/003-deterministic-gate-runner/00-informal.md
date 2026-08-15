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
- **G8** Docs: `docs/CHANGELOG.md` updated. WARN-only.
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
