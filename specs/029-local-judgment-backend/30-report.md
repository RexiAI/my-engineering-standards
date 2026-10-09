# 029 — Local judgment backend: Mutation Runner report (stage 5a)

Spec: `specs/029-local-judgment-backend/` · Branch: `spec/028-typed-judgment-layer`
(029 stacks on 028; PR #73 open — the tree legitimately carries BOTH the committed
028 change set and the uncommitted 029 work) · Mutation Runner run date:
2026-10-09 (UTC).

## Summary

| Item | Value |
|---|---|
| Conformance tier | `mvp` |
| Mutation testing | **skipped — `mvp` tier** |
| Verifier verdict (carried forward) | **PASS** attempt 1, phase 1 |
| Complexity summary (carried from Refactorer) | all 55 functions ≤6 CC; worst CC=6 (`call_api`, `check_callable` in `typed-judgment.sh`); `cmd_up:CC=5`, `term_tree:CC=2` independently re-measured by Verifier |
| Final test status (spec-029 scope) | **136/136 green** (44 + 78 + 14) |
| Final test status (full suite) | 290 ok / 5 not ok / 0 skipped of 295 — 5 failures ruled out-of-scope (see below) |
| Equivalent mutants | none — mutation run not executed at `mvp` tier |
| Phase-1 remediation attempts | 0 (no BLOCK; Verifier PASS on attempt 1) |
| Phase-2 remediation attempts | not applicable (PR not yet opened) |
| Report status | **GREEN** — PR Opener may proceed |

## Conformance tier ruling

**Tier: `mvp`.**

Evidence — the project declares its tier in `docs/CONFORMANCE_TIERS.md`:

command: grep -n "^## Conformance tier" docs/CONFORMANCE_TIERS.md
exit: 0
at: 2026-10-09T19:04:36Z

```
20:## Conformance tier: mvp
```

Per `docs/SPEC_PIPELINE.md §Conformance tiers`, the matrix row for
`Architect — mutation testing` reads:

| Stage | `mvp` | `production` | `multi-service` |
|---|---|---|---|
| Architect — mutation testing | **skip** | yes | yes |

The same tier matrix in `docs/CONFORMANCE_TIERS.md` places mutation testing
(`PiTest / Gremlins / Stryker`) at `production` tier. The Refactorer and the
Verifier both ruled `mvp` this run — the design-principles gate JSON emits
`"tier": "mvp"` and the Verifier's independent measurement confirms. The
Mutation Runner concurs: **mutation testing is skipped at this tier.**

This repo's production language for mutation testing is shell (bats/bash). No
standard shell mutation tool is configured or available in the toolchain table
(`docs/SPEC_PIPELINE.md §Tooling by language` lists PiTest for Java,
go-mutesting/gremlins for Go, Stryker for JS/TS — shell has no entry). The
skip is therefore doubly correct: (a) the tier does not require it, and (b) no
tool is provisioned to execute it.

## Verifier verdict (carried forward)

**PASS** — attempt 1, phase 1. No re-verification loops consumed.

Source: `specs/029-local-judgment-backend/25-verification.md`, verdict line and
per-check table. All five Verifier checks passed in scope; gate 2 (full test
suite) recorded a transcribed FAIL ruled out-of-scope (see below) and carried
in warnings per the spec-028 precedent.

## Complexity summary (carried from Refactorer, re-verified by Verifier)

The Refactorer's after-state claim — all functions ≤6 CC — was independently
re-measured by the Verifier with a shell-adapted CC heuristic. Worst measured
CC = 6; 55/55 functions in the two changed shell files pass.

Source: `25-verification.md §Evidence: complexity gate` (command, exit, at
recorded there). Design-principles gate JSON from the Refactorer's own run:

command: scripts/check-code-principles.sh -BaseRef HEAD --json
exit: 0
at: 2026-10-09T18:38:16Z (Verifier's run)

```json
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

No complexity finding. No design-principles finding on the 029 change scope.
14 pre-existing WARNs in `ci/templates/*` (untouched by 029) carried as W5 in
the Verifier's notes — not attributed to 029, not blocking.

## Spike outcome summary

The Coder's spike (recorded in `35-spike-report.md`, ADR 0005, and the E2E
addendum) produced a clear winner and is cross-artifact consistent, as the
Verifier independently confirmed:

- **Winner:** Kev-4B (`jaredpalmer/kev-4b`).
- **p50 latency:** 117 ms over 48 calls (24 cold + 24 warm; server cold p50
  286 ms, warm ~105 ms, first call 761 ms).
- **Threshold:** `JUDGMENT_MIN_CONFIDENCE=0.28` — 5th percentile of
  correct-answer confidence (linear interpolation, floored to 2 decimals;
  p5 = 0.2831 → 0.28).
- **Accuracy:** 24/24 Coder-authored fixtures (12 ci-triage + 12 spec-ux).
- **VRAM:** 15.6–15.8 GiB used of 16311 MiB (peak 15861 MiB at 4 Hz).
- **Recipe:** `uv run --extra serve python -m kev.serve --run jaredpalmer/kev-4b --port 8009`;
  health `/v1/models`; API `/v1/systemone`; default alias `kev-latest`
  (matches `DEFAULT_LOCAL_MODEL` in `typed-judgment.sh:86`).
- **Wire compatibility:** zero changes required beyond the Task 2 backend
  switch; 3 fidelity deltas enumerated with follow-up proposals scoped OUT
  of 029 (byte-frozen hosted path, AC-029-74 consumer preservation).

The orchestrator upheld the spike bar and the 0.28 threshold through stage 4
(Verifier PASS attempt 1, no re-verification loop needed). **Note W6 carried
forward from the Verifier:** the numeric bar originates in the informal spec
(§Task 0), from which Coder and Verifier are information-barred; the Coder
correctly declared an operational bar derived from the formalized ACs and
recorded re-adjudication instructions. The Architect/human should confirm the
informal §Task 0 numbers against the declared bar at PR review time.

## Out-of-scope suite failures

`make test` at 029's working-tree state: **290 ok / 5 not ok / 0 skipped of 295**.
All 5 failures are outside the 029 diff scope. The Verifier ruled them
out-of-scope per the Stop-and-Ask matrix row "Out-of-scope finding — record it;
do not fix; propose a follow-up spec", following the spec-028 Adjudication B
precedent. Carried here as a standing ruling, not re-adjudicated.

**Ruling A — env-caused (4 tests): `AC-001-05`, `agent-env.selftest` ×3.**
Root cause: `config/agent.local.env` (gitignored, per-machine credentials file)
contains real token values that `scripts/check-no-hardcoded-secrets.sh` flags.
Control: a detached worktree of HEAD (gitignored files absent by construction)
passes all four tests. CI cannot see these (file never committed). Follow-up:
open issue #72 family (scanner echoes secret values verbatim and scans
gitignored local files — carried from 028's W3).

**Ruling B — branch-state-caused (1 test): `check-pr-review: clean repo`.**
Root cause: the guard fires on `agents/spec-ux.md`, which is in
`origin/main..HEAD` as 028's committed, PR-#73-scoped change. Control: the
test fails identically in the clean-HEAD worktree (not caused by 029's
uncommitted work, which touches zero files under `agents/`). Disposition
belongs to PR #73's human review, not to spec 029.

command: make test
exit: 2
at: 2026-10-09T18:31:59Z (Verifier's run)

```
290 ok / 5 not ok / 0 skipped of 295
make: *** [Makefile:115: test-scripts] Error 1
```

Spec-029-scope per-file re-run (Mutation Runner's own confirmation):

command: bats --tap scripts/tests/typed-judgment.bats | tail -1; bats --tap scripts/tests/typed-judgment-integration.bats | tail -1; bats --tap scripts/tests/judgment-local-up.bats | tail -1
exit: 0 (each file)
at: 2026-10-09T19:04:36Z

```
ok 44 unit: dry-run in local mode prints the default alias without a live call
ok 78 AC-029-58: content-contract verifies ADR 0005 exists with the four required sections
ok 14 unit: up kills its own process and fails cleanly when health never answers
```

**Suite verdict for spec-029 scope: 136/136 green.** The 5 out-of-scope
failures in the broader suite do not block the 029 pipeline run, per the
Verifier's ruling and the 028 precedent.

## Equivalent mutants

None. No mutation run was executed at `mvp` tier, so no surviving mutants to
classify.

## Remediation record

Per `docs/SPEC_PIPELINE.md §Remediation budget`:

- **Phase 1 (pre-PR loop):** no BLOCK occurred. Verifier PASS on attempt 1.
  Attempt count: 1 (no re-verification needed).
- **Phase 2 (post-PR loop):** not applicable — PR not yet opened at the time
  of this report.

The Verifier's `25-verification.md` records attempt 1, phase 1 as the sole
verification pass. No gate failure triggered a fix-and-re-run.

## Warnings carried forward (not blocking)

The Verifier recorded five warnings (W1–W5, plus W6 on spike bar provenance).
All are review hints for the Architect/human at PR review time; none block
the pipeline:

- **W1** — gate 2 out-of-scope FAIL stands (Rulings A/B); follow-up = issue
  #72 family + a possible spec for the AC-024-01-12 guard on stacked branches.
- **W2** — 2 shellcheck advisory findings on `judgment-local-up.sh`
  (SC2206 warning L152, SC2086 info L72); deliberate word-splitting idioms.
- **W3** — spike report arithmetic slip ("7 of 24 (29 %)" vs the report's own
  buckets showing 8 of 24 below 0.6 = 33 %); one-word fix at next touch.
- **W4** — AC-029-70 per-question-shape counts verified by read, not asserted
  mechanically; hardening candidate for a follow-up.
- **W5** — design-principles full-tree WARN backlog (14 WARNs in
  `ci/templates/*`, pre-existing, untouched by 029).
- **W6** — spike bar provenance: Architect/human should confirm informal
  §Task 0 numbers against the declared bar at PR review.

## Definition-of-done status

| DoD criterion | Status |
|---|---|
| Verifier PASS | ✓ (attempt 1, phase 1) |
| `30-report.md` exists | ✓ (this file) |
| Report is GREEN | ✓ — tier-correct skip, suite green in scope, no BLOCK |
| Archive (`scripts/archive-spec.sh`) | pending — stage 5b (PR Opener) runs this as its final act |
| Draft PR | pending — stage 5b opens it |

**Report status: GREEN.** PR Opener may proceed to stage 5b.
