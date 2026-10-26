# AC-034: Task 4 — wire the preflight into /spec and /build

## AC-034-17 — `spec-pipeline` runs the preflight first for `/spec`
Given the `spec-pipeline` agent instructions in `agents/spec-pipeline.md`
When the `/spec` invocation path is read
Then it instructs running `scripts/judgment-preflight.sh` before any delegation

## AC-034-18 — `spec-pipeline` runs the preflight first for `/build`
Given the `spec-pipeline` agent instructions in `agents/spec-pipeline.md`
When the `/build` invocation path is read
Then it instructs running `scripts/judgment-preflight.sh` before any delegation

## AC-034-19 — A preflight warning never halts stage delegation
Given the preflight exits 0 with a warning (backend down, fail-open)
When the orchestrator proceeds
Then it continues delegating to the next stage
And no stage is blocked solely by the preflight warning
And only a non-zero preflight exit (under `--require-judgment`/`JUDGMENT_REQUIRED=1`)
may stop the run
