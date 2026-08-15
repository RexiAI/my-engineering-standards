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
