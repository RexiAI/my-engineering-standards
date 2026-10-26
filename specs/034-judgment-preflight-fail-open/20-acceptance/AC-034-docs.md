# AC-034: Task 8 — docs: setup step 0 and the typed-judgment layer

## AC-034-29 — Setup lists `make judgment-up` as step 0, optional-but-recommended
Given `docs/SPEC_PIPELINE.md`
When the setup section is read
Then `make judgment-up` appears as step 0
And it is marked optional-but-recommended
And it carries the token caveat that judgment calls are negligible next to
the machine's ~95% cache-read token spend

## AC-034-30 — Typed-judgment layer documents the contract and the new surface
Given `docs/SPEC_PIPELINE.md` §Typed-judgment layer
When the section is read
Then exit 10 is documented as "no fast-path exists → run the original (stock)
procedure", with no valid consumer response that halts on exit 10
And the fail-open preflight (`scripts/judgment-preflight.sh`) is documented
And the payload cap with deterministic truncation (`--max-state-bytes`,
default 12 KB) is documented
And the four telemetry reasons (`unconfigured`, `unreachable`,
`payload_overflow`, `error`) are documented
And `make judgment-status` is documented as the operator surface
