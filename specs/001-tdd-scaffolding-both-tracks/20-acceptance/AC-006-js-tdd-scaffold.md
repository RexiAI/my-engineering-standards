# AC-006: JS/TS TDD scaffold

## AC-006-01 — Scaffold directory and package wiring exist
Given the repo after this task
When listing `ci/templates/js-feature/` (or `templates/js-tdd/`)
Then `package.json` fragment exists with `vitest` or `jest` and `fast-check`
And `vitest.config.ts` or `jest.config.js` exists

## AC-006-02 — Sample acceptance test is traceable
Given the scaffold's sample test file
When inspecting it
Then it contains `it("AC-006-01:` in the test name
And one property test uses `fast-check` (`fc.assert` or `fc.property`)

## AC-006-03 — Mutation config threshold 80 present
Given the scaffold
When reading `stryker.conf.json` (or inline `stryker` key in `package.json`)
Then `thresholds.break` is 80 and `testRunner` is `vitest` or `jest` (matching the chosen runner)
And the config is a copy or reference to `ci/templates/stryker.conf.json`

## AC-006-04 — npm scripts wired and package manager unchanged
Given the scaffold `package.json`
When reading `scripts`
Then `test` invokes `vitest run` or `jest`
And `mutation` or docs state `npx stryker run`
And no `yarn`/`pnpm`/`bun` lockfile is introduced (npm per `language-specific/javascript/SKILL.md`)

## AC-006-05 — Complexity gate referenced at ≤6
Given the scaffold README or ESLint config reference
When searching for `complexity`
Then it states ESLint `complexity: ["error", 6]` (or `≤6`) and does not raise the limit

## AC-006-06 — Tier awareness documented
Given the scaffold README fragment
When reading it
Then it notes mutation and property tests are `production`-tier per `docs/CONFORMANCE_TIERS.md` and may be skipped at `mvp`
And it links to `docs/TESTING.md §Property Testing` and `§Mutation Testing`
