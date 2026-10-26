# AC-033: Loop engineering — --with-loop

## AC-033-41 — `--with-loop` writes the loop files the gate validates
Given a child repo with `.standards/` present
When `bootstrap.sh --with-loop` runs
Then `LOOP.md`, `STATE.md`, `loop-run-log.md`, `loop-budget.md`, `loop-constraints.md`, and `gate.yaml` are written to the child repo
And `scripts/check-loop-files.sh` passes against that repo

## AC-033-42 — `--with-loop` re-run is a no-op
Given a child repo that already has the loop files
When `bootstrap.sh --with-loop` runs again
Then no file is rewritten
And each existing loop file reports `SKIPPED (exists)`
