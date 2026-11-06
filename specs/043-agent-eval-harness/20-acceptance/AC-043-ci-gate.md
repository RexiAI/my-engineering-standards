# AC-043: Self-CI gate wiring

## AC-043-59 — Self-CI runs the gate and its self-test
Given `.github/workflows/self-ci.yml`
When the `validate` job steps are read
Then a step runs `./scripts/check-agent-evals.sh`
And the same step or the step after it runs `./scripts/check-agent-evals.sh --self-test`

## AC-043-60 — The gate cannot be skipped
Given the self-CI agent-eval step
When its YAML is read
Then it does not set `continue-on-error: true`
And the workflow's `permissions` remain `contents: read`

## AC-043-61 — The self-test fails closed
Given `scripts/check-agent-evals.sh --self-test`
When it runs against its fixtures
Then it exits 0 only when every fixture produces its expected exit code
And the fixture set includes a missing task entry, an always-`1` verifier, a missing ADR index row, and a missing self-CI step
And a broken fixture exits 1 with a `FAIL AC-043-…` line

## AC-043-62 — The gate is read-only and offline
Given a clean worktree
When `scripts/check-agent-evals.sh` and `scripts/check-agent-evals.sh --self-test` run
Then `git status --porcelain` is unchanged
And `runs.jsonl` is unchanged
And no `opencode` process starts
And no `curl` or `wget` invocation occurs

## AC-043-63 — The governance link is enforced
Given `scripts/check-agent-evals.sh`
When `docs/adr/0022-agent-eval-harness.md` is missing
And, in a second fixture, its row is absent from `docs/adr/README.md`
Then the gate exits 1
And the failure names the missing ADR or the missing index row
