# AC-034: Task 10 — tests incl. the static no-BLOCK assertion

## AC-034-32 — Static assertion: no consumer maps exit 10 to BLOCKED
Given the consumer surface `agents/*.md` and `skills/*/SKILL.md`
When the static assertion test runs
Then it fails if any consumer file maps exit 10 to `BLOCKED`
And it passes when `agents/spec-ux.md` routes exit 10 to the stock
applicability check (the positive contract is also asserted)

## AC-034-33 — The new tests run offline with no live backend
Given no `JUDGMENT_*` env vars are set and there is no network access
When the new bats tests under `scripts/tests/` run
Then they pass (all new preflight, cap, status, and content-contract tests are
hermetic — mocked HTTP, no live local backend required)
