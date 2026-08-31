# 001 — TDD Scaffolding (Both Tracks) — Report

> Spec: `specs/001-tdd-scaffolding-both-tracks`
> Stage: 5a Mutation Runner per `docs/SPEC_PIPELINE.md` and `agents/spec-mutation-runner.md`
> Conformance tier: `mvp` (this repo) — mutation testing is `production`-tier per `docs/CONFORMANCE_TIERS.md` and `docs/SPEC_PIPELINE.md §Conformance tiers`

## Verdict

| Field | Value |
|-------|-------|
| Verifier verdict (carried from `25-verification.md`) | **PASS** — attempt 1, phase 1, all 5 checks PASS, no FAIL/BLOCK (at 2026-08-31T13:18:53Z) |
| Mutation score | **skipped — `mvp` tier** (production-tier gate, scaffold templates verified at 80%) |
| Complexity summary (carried from Verifier/Refactorer) | **PASS** — 0 FAIL, 4 WARN (see below) |
| Final test status | **GREEN** — 195/195 bats tests passed, 0 failures |
| Equivalent mutants | **none** — no mutation run (mvp skip); no unreachable survivors to name |
| Remediation record | **none** — no BLOCK occurred in phase 1 or phase 2 |

## Mutation

Per `docs/SPEC_PIPELINE.md §Conformance tiers` and `docs/CONFORMANCE_TIERS.md`, mutation testing (PiTest / Gremlins / Stryker) is a `production`-tier gate. This repo declares `mvp`, so the Mutation Runner **skips** the mutation run and instead verifies that the scaffold templates contain the production-tier mutation configs at the required 80% threshold.

Templated threshold evidence:

- `ci/templates/pitest-profile.xml` → `<mutationThreshold>80</mutationThreshold>`
- `ci/templates/mutation.mk` → `gremlins unleash --threshold-efficacy 80`
- `ci/templates/stryker.conf.json` → `"break": 80` (with `high:90 low:80`)
- `ci/templates/js-feature/stryker.conf.json` → `thresholds { high:90, low:80, break:80 }`
- `ci/templates/js-feature/package.json` → `mutation: npx stryker run`

This matches the pipeline's tooling table: Java `mvn verify -Pmutation` ≥80%, Go `gremlins` ≥80%, JS/TS `npx stryker run` ≥80%.

## Complexity summary

Carried from Verifier `25-verification.md` (re-confirmed here):

- `make validate-all` → PASS (35 files, cross-refs valid, SKILL.md 1 WARN pre-existing hallmark >500 lines)
- `./scripts/check-orchestration.sh` → PASS (all agent/skill/script/doc refs valid)
- `./scripts/check-code-principles.sh` (tier: mvp) → **0 FAIL, 4 WARN**
  - PASS Complexity/KISS (java/go/node): no violations
  - PASS YAGNI, PASS SOLID (all sub-gates)
  - 4 WARN: DRY duplicate 4-line blocks in `templates/.gitignore.go` lines 10-13 (pre-existing template, not introduced by spec 001; review hint only, per Stop-and-Ask WARN does not block)
  - Property tests: skipped (mvp tier)
- Language scaffold thresholds carried:
  - Java: `ci/templates/java-feature/pmd-rules.xml` → `CyclomaticComplexity ≤6`, `CognitiveComplexity ≤6`
  - Go: `ci/templates/go-feature/Makefile` lint → `golangci-lint cyclop/gocognit ≤6`
  - JS: `ci/templates/js-feature/eslint.config.js` → `complexity: ["error", 6]`

No method or file exceeds the ≤6 / 20-line / 500-line heuristics introduced by this spec.

## Equivalent mutants

None. Mutation was not run (mvp skip). No surviving mutants to classify as equivalent. If this repo graduates to `production`, run `make mutation` (delegates to `mvn verify -Pmutation` / `gremlins unleash --threshold-efficacy 80` / `npx stryker run` per template) and name any unreachable survivor explicitly here with why it is un-killable (e.g., defensive `if (x==null) return` that is dead code after a prior guard).

## Final test status

Full suite re-run after mutation-kill work (no new mutation-killing tests needed at mvp tier — harness is the product).

- `bats --tap scripts/tests/*.bats` → 1..195, 195 ok, 0 not ok (hermetic, temp dirs, no network/Docker)
- `make test-scripts` → same harness, same result (CI calls `make test-scripts` via `self-ci.yml`)
- Scenario traceability: 46 scenarios traced (AC-001..AC-007), every reference resolves

## Remediation record

Per `docs/SPEC_PIPELINE.md §Remediation budget`: for each BLOCK, the phase (1 or 2) and the attempt count at which it was resolved; or `none` when no BLOCK occurred. Carry forward from `25-verification.md` attempt entries and the orchestrator's loop summary — never guessed.

- Verifier `25-verification.md` attempt: **1, phase 1** — no BLOCK, verdict PASS
- Mutation Runner phase: **phase 1, attempt 1** — no BLOCK
- CI loop phase 2: not yet entered (PR not open)
- **Result: none** — no BLOCK occurred during the run. If no `25-verification.md` attempt information were present, that would be stated here; it is present and carried above.

## Evidence: mutation score (skipped — mvp tier)

command: make mutation
exit: 0
at: 2026-08-31T13:33:41Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)

## Evidence: mutation wiring (threshold 80 present in templates)

command: grep -n "mutationThreshold>80" ci/templates/pitest-profile.xml && grep -n "threshold-efficacy 80" ci/templates/mutation.mk && grep -n '"break": 80' ci/templates/stryker.conf.json ci/templates/js-feature/stryker.conf.json
exit: 0
at: 2026-08-31T13:29:58Z

ci/templates/pitest-profile.xml:30:                    <mutationThreshold>80</mutationThreshold>
ci/templates/mutation.mk:22:	gremlins unleash --threshold-efficacy 80 --tags integration
ci/templates/stryker.conf.json:16:    "break": 80
ci/templates/js-feature/stryker.conf.json:7:  "thresholds": { "high": 90, "low": 80, "break": 80 },

## Evidence: final test suite

command: bats --tap scripts/tests/*.bats
exit: 0
at: 2026-08-31T13:33:41Z

1..195
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
...
ok 194 AC-002-08: validate-export-bundle is hermetic — does not mutate scripts/ and cleans temp dir
ok 195 AC-002-08: validate-export-bundle uses temp dirs and trap cleanup (helper sourced)

195 passed, 0 failed (of 195 tests). Raw TAP line count: 196 (header 1..195 + 195 ok).

## Evidence: design-principles gate (re-confirm)

command: scripts/check-code-principles.sh
exit: 0
at: 2026-08-31T13:33:41Z

Checking design principles in: . (tier: mvp)

PASS Complexity/KISS (java): no violations found
PASS Complexity/KISS (go): no violations found
PASS Complexity/KISS (node): no violations found
WARN Possible duplication (2x identical 4-line block, first at ./templates/.gitignore.go:13): .env /.env.local /*.log /*~
WARN Possible duplication (2x identical 4-line block, first at ./templates/.gitignore.go:12): *~ /.env /.env.local /*.swo
WARN Possible duplication (2x identical 4-line block, first at ./templates/.gitignore.go:10): *.swp /*.swo /*~ /.DS_Store
WARN Possible duplication (2x identical 4-line block, first at ./templates/.gitignore.go:11): *.swo /*~ /.env /*.swp
PASS YAGNI (java): no premature abstractions detected
PASS YAGNI (go): no premature abstractions detected
PASS YAGNI (node): no premature abstractions detected
PASS SOLID-SRP (java): no oversized files
PASS SOLID-SRP (go): no oversized files
PASS SOLID-SRP (node): no oversized files
PASS SOLID-OCP (java): no large type-dispatch chains
PASS SOLID-OCP (go): no large type-dispatch chains
PASS SOLID-OCP (node): no large type-dispatch chains
PASS SOLID-LSP (java): no heavy instanceof dispatch
PASS SOLID-LSP (node): no heavy instanceof dispatch
PASS SOLID-ISP (java): no fat interfaces
PASS SOLID-ISP (node): no fat interfaces
PASS SOLID-DIP (java): no domain→infrastructure imports
PASS SOLID-DIP (go): no domain→infrastructure imports
PASS SOLID-DIP (node): no domain→infrastructure imports
Property tests: skipped (project tier is mvp — production+ required)

---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 4 WARN(s).

## Evidence: scenario traceability (re-confirm)

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-08-31T13:29:58Z

Scenario IDs found: 46

PASS AC-001-01 — traced to a test
PASS AC-001-02 — traced to a test
PASS AC-001-03 — traced to a test
PASS AC-001-04 — traced to a test
PASS AC-001-05 — traced to a test
PASS AC-001-06 — traced to a test
PASS AC-002-01 — traced to a test
...
PASS AC-007-05 — traced to a test
PASS AC-007-06 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.

## Output

Mutation score: skipped — `mvp` tier (threshold 80 verified in `ci/templates/pitest-profile.xml`, `ci/templates/mutation.mk`, `ci/templates/stryker.conf.json`, `ci/templates/js-feature/stryker.conf.json`).
Test results: GREEN (195/195).
Equivalent mutants: none (no run).
Report: `specs/001-tdd-scaffolding-both-tracks/30-report.md`
