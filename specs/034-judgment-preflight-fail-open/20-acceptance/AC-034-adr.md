# AC-034: Task 9 — ADR: consumer contract + fail-open preflight

## AC-034-31 — ADR records the contract change and the index is updated
Given the `docs/adr/` directory and its `README.md` index
When this spec's ADR is added
Then a new ADR file exists at the next sequential number after the highest
indexed number (currently 0011)
And it records the exit-10 contract (exit 10 = run stock procedure, never BLOCKED)
And it records the fail-open preflight
And it records the payload cap with deterministic truncation
And it records the four-way fallback-reason taxonomy
And the `README.md` index gains a row for the new ADR
