# Report — 017 CI Sweeper loop

**Stage 5a (Mutation Runner)** — spec `017-ci-sweeper-loop`, branch
`spec/017-ci-sweeper-loop`. `00-informal.md` not read.

---

## Verifier's verdict (carried forward)

**PASS** — `specs/017-ci-sweeper-loop/25-verification.md` exists and its overall
verdict is PASS: AC-017 traceability clean (5 groups, 26 sub-IDs, no dangles),
full relevant suite green, complexity ≤3 on every changed function, single-sourced
pin, shared install script, design-principles gate exit 1 entirely pre-existing
`ci/templates/*` state, spot-checked scenarios match their Given/When/Then,
negative fixture fails closed.

## Mutation score

**skipped — mvp tier.** This repo conforms at `mvp` (no `AGENTS_*.md`;
`check-code-principles.sh` auto-detects `tier: mvp`). Per
`docs/SPEC_PIPELINE.md §Conformance tiers`, mutation testing is a `production`-tier
gate and does not run at `mvp`. The changed code is bash + skill markdown + workflow
YAML; no mutation tooling for shell exists in this repo.

## Complexity summary (carried from the Refactorer, re-confirmed by Verifier)

- `scripts/check-ci-sweeper.sh`: `fail()` CC 1, `pass()` CC 1, `verify_grep()` CC 3,
  `self_test()` CC 2 — all ≤3.
- `scripts/install-opencode.sh`: no functions, straight-line under `set -euo
  pipefail` — CC 1.
- **Pin in one place:** `VERSION="v1.18.18"` occurs exactly once in the change set
  (`scripts/install-opencode.sh:14`); no literal version in either workflow.
- **Shared install script:** both workflows invoke `bash scripts/install-opencode.sh`
  (self-ci.yml, ci-sweeper.yml); self-ci's inline curl/tar block removed in favor of
  the shared script; installs to `/tmp/opencode-bin` (matches
  `model-env.runtime-check.sh` expectations).

## Equivalent mutants

**None.** Mutation testing not run (mvp tier); no survivors to evaluate.

## Architect note (carried from the Verifier)

`docs/ci-flakes.md` is cited by `skills/ci-triage/SKILL.md` as the flake-quarantine
ledger, but the file does not exist. Verifier judgment: consistent with the task
text — no acceptance scenario requires the file to exist now; `10-tasks.md` open
question 4 names it as the *assumed* ledger name pending human confirmation. The
skill committing to that name is write-on-first-use, not a missing deliverable.
Record the open-question-4 answer (ledger name) so the named file is not surprising
post-merge.

## Final test status

Re-run in full one final time (stage 5a re-check; Verifier had already confirmed
once — no new test code was written at this stage since mutation testing was
skipped):

| Command | Result |
|---|---|
| `./scripts/check-ci-sweeper.sh` | exit 0 — 26 PASS, 0 FAIL |
| `./scripts/check-ci-sweeper.sh --self-test` | exit 0 — gate fails closed on broken fixture |
| `bash -n scripts/check-ci-sweeper.sh scripts/install-opencode.sh` | exit 0 — no syntax errors |
| `scripts/check-orchestration.sh` | exit 0 — all orchestration references valid |
| `make validate-all` | exit 0 — 35 required files + cross-refs valid; SKILL.md scan passes (only pre-existing hallmark WARN) |
| `scripts/check-loop-files.sh` | exit 0 — all AC-016 PASS lines, loop foundation present |
| `specs/017-ci-sweeper-loop/25-verification.md` | exists, verdict PASS |

**All green.** Ready for stage 5b (PR Opener).

Mutation Runner: spec-mutation-runner (stage 5a). Writes: this file only.
