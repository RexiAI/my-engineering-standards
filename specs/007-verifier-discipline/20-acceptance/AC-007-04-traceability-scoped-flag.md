# AC-007-04: check-scenario-traceability.sh supports scoped checks, JSON output, and a tooling-failure exit code

## AC-007-04-01 — `--checks 1` runs only the scenario-to-test check (AC-003)
Given a scratch specs tree where a scenario heading `## AC-999-01` has no matching test reference (check 1 violation)
And the same tree has a test referencing `AC-999-99` which is not a real scenario heading (check 2 violation)
When `scripts/check-scenario-traceability.sh --checks 1 <specs_dir> <src_dir>` runs
Then the output reports the orphaned scenario `AC-999-01` and nothing about `AC-999-99`
And the script exits 1

## AC-007-04-02 — `--checks 2` runs only the test-reference-to-scenario check
Given the scratch tree from AC-007-04-01
When `scripts/check-scenario-traceability.sh --checks 2 <specs_dir> <src_dir>` runs
Then the output reports the dangling reference `AC-999-99` and nothing about the orphaned scenario `AC-999-01`
And the script exits 1

## AC-007-04-03 — `--checks 1,2` and the default run are equivalent to the full check
Given a scratch tree with one violation in each check
When `scripts/check-scenario-traceability.sh --checks 1,2 <specs_dir> <src_dir>` runs
Then the output reports both violations and the script exits 1
And running the script with no `--checks` flag reports both violations and exits 1 as well

## AC-007-04-04 — A clean tree with `--json` emits a machine-readable pass and exits 0
Given a scratch specs tree where every scenario is traced and every reference resolves
When `scripts/check-scenario-traceability.sh --json <specs_dir> <src_dir>` runs
Then stdout is a single JSON object containing the scenario IDs, an empty `fails` array, and the pass entries
And the script exits 0

## AC-007-04-05 — `--json` with a finding includes the violation and still exits 1
Given the scratch tree from AC-007-04-01
When `scripts/check-scenario-traceability.sh --checks 1 --json <specs_dir> <src_dir>` runs
Then the JSON object's `fails` array contains one entry naming the orphaned scenario `AC-999-01`
And the script exits 1

## AC-007-04-06 — A tooling failure is exit 2, never a false PASS
Given the script runs in an environment where a required tool such as `grep` is unavailable or the target source directory cannot be read
When `scripts/check-scenario-traceability.sh` runs
Then the script does not exit 0
And the script exits 2 (or otherwise non-0, non-1) with an error to stderr naming the failure
And it never prints a clean summary for a check it could not execute

## AC-007-04-07 — Unknown check number is a usage error (exit 2)
Given the script accepts check numbers 1 and 2
When the script runs with `--checks 3` or `--checks ""`
Then the script writes an error message to stderr naming the invalid check
And the script exits 2

## AC-007-04-08 — Positional arguments keep working alongside the new flags
Given the script's existing positional arguments `SPECS_DIR` and `SOURCE_DIR` default to `specs` and `.`
When the script runs with `--checks 1,2` and explicit positional arguments
Then the positional arguments are honored for the spec and source directories
And the "no specs dir" / "no scenario headings" cases still exit 0 as nothing-to-check
