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
