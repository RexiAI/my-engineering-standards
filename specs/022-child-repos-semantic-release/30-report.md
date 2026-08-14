# Architect report — Child repos and the semantic-release bot (spec 022)

Stage 5a (Mutation Runner) / Architect gate. Branch: `spec/022-child-repos-semantic-release`.

Verdict: **GREEN** — PR Opener may proceed.

---

## 1. Verifier's verdict (carried forward)

**PASS** — `specs/022-child-repos-semantic-release/25-verification.md`. All six
self-CI gates executed from scratch with exit 0; every Task 3 generation
behavior (`--with-release` GitHub/Go/Java/GitLab paths, GH_TOKEN prompt,
no-flag regression guard) re-run against fresh scratch trees and matched the
acceptance scenarios byte-for-byte; no-flag output byte-identical to
pre-change; all four 022 scenario IDs trace; diff limited to `docs/CI_CD.md` +
`scripts/init-ci.sh`.

## 2. Mutation testing — SKIPPED (mvp tier + inapplicable)

Mutation testing was **not run**. Two independent reasons, either alone is
sufficient:

1. **Conformance tier is `mvp`.** No `AGENTS_<PROJECT>.md` exists in this repo
   (verified: no such file in the tree), so the floor tier applies.
   `docs/CONFORMANCE_TIERS.md` assigns mutation testing (PiTest / Gremlins /
   Stryker) to `production`; `docs/SPEC_PIPELINE.md §Conformance tiers` marks
   the Architect mutation gate **skip** at `mvp`. Per the tier table this is
   not a gap — it is out of scope until the repo graduates.
2. **No test suite exists to mutate against, and no mutation tool targets the
   changed artifact.** This is the standards parent repo, not an application:
   the Makefile exposes only `validate` / `validate-docs` / `validate-refs` /
   `validate-skills` / `validate-all` — no `test:` target, no unit/acceptance
   runner in Java, Go, or JS/TS. The test files under `ci/templates/tests/`
   are templates shipped to *child* repos, never executed here (and untouched
   by this branch). Spec 022's change is a bash script
   (`scripts/init-ci.sh --with-release`) plus docs; PiTest, go-mutesting/
   gremlins, and Stryker target Java/Go/JS application code — none covers bash.
   The meaningful behavioral coverage for a bash change is the byte-identity
   regression guard and the scenario assertions, both of which the Verifier
   re-executed (§2b/§2c of `25-verification.md`).

No surviving mutants exist to kill and no tests were written (no mutation
pass). This stage's own obligation — verify the Verifier's PASS stands on the
live tree — is discharged by the fresh gate re-runs in §5 below.

## 3. Complexity summary (carried from Refactorer, re-checked by Verifier)

Design-principles/complexity gate `scripts/check-code-principles.sh`: exit 1 —
**5 FAIL(s), 17 WARN(s), all pre-existing, none on this branch's files.**

- FAILs (cyclomatic complexity >6): `ci/templates/go-saga-lint.go:101`
  (checkCompensationPairs CC=14), `:163` (checkOutboxCoLocation CC=10),
  `:207` (checkSagaHandlerContext CC=10), `:275` (resolveDirs CC=8);
  `ci/templates/eslint-saga-rules/saga-compensation.js:56`
  (getSagaStepOptions CC=7). All last committed 2026-07-12 (v1.3.0), tracked
  blobs byte-identical to HEAD.
- WARNs (17): method-body >20 lines (go-saga-lint.go ×5), possible duplication
  (go-saga-lint.go ×6, saga-compensation.js ×4), empty method body
  (OutboxArchRules.java:30, SagaArchRules.java:33). All pre-existing.
- Changed files (`docs/CI_CD.md`, `scripts/init-ci.sh`): **zero** FAILs and
  **zero** WARNs. The ≤6 cyclomatic gate targets Java/Go/JS only; bash is not
  in scope, so the script's complexity is not gated by this tool.
- Refactorer accuracy note (from Verifier §3): Refactorer claimed 6
  pre-existing FAILs; actual is 5. Report-accuracy WARN only — direction of
  the claim (pre-existing, untouched) verified true.

Pre-existing repo debt, flagged for a follow-up refactor spec, not a
pipeline stop.

## 4. Equivalent mutants

**None.** Mutation testing was not run (see §2); there are no surviving
mutants to classify, hence no equivalent (un-killable) mutants to name.

## 5. Final test status — GREEN

Fresh re-run of the repo's gate suite on this exact branch (all exit 0):

| Gate | Command | Exit |
|---|---|---|
| lint | `make lint` | 0 |
| validate-all | `make validate-all` | 0 |
| shell parse | `bash -n scripts/init-ci.sh` | 0 |

Plus the Verifier's already-executed `scripts/check-orchestration.sh` (0),
`scripts/check-skills.sh` (0), and CRLF scan (clean). No new test code was
written by this stage, so the Verifier's PASS re-confirms on the unchanged
tree.

## 6. GREEN for PR Opener

Stage 5b (`spec-pr-opener`) may commit, archive via
`scripts/archive-spec.sh 022-child-repos-semantic-release`, push, and open the
draft PR. Known pre-existing WARNs (design-principles exit 1 on untouched
`ci/templates/`, `scripts/init-ci.sh` lacking exec bit, hallmark SKILL.md
line-count, working-tree CRLF artifact) are carried in `25-verification.md`
§Flags for the Architect and are not introduced by this branch.
