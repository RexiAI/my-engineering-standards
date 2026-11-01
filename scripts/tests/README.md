# Shell test harness (`scripts/tests/`)

Runner: **bats-core ≥1.10** (`bats --tap`). `shellspec` was evaluated and
rejected — bats is TAP-native, has no Ruby dependency, and ships in every CI
image. Run everything with `make test-scripts`.

Every test in this directory makes a real assertion: an exit code the script
documents, plus a stdout/stderr fragment that is part of its contract. A test
that would still pass if its script were replaced with `exit 0` is a defect,
not coverage. `scripts/check-bats-assertions.sh` enforces that mechanically —
it rejects bare `true` used as an assertion, `true || [ ... ]`, and
`run ... || true` with no following status/output assertion.

## Not characterized, and why

These `scripts/*.sh` have **no** bats file. Each one either mutates the
caller's repo, needs the network, or needs credentials/`gh`/Docker, so no
honest hermetic characterization test is possible. A fake test asserting
nothing would be worse than no test.

| Script | Why not characterized |
|---|---|
| `bootstrap.sh` | Scaffolds a child repo in place — creates symlinks, `.githooks`, and submodule wiring in the caller's tree. Mutating; no dry-run mode. |
| `init-ci.sh` | Writes CI workflow files into the target repo and prompts interactively for the CI platform. Mutating + interactive. |
| `init-deploy.sh` | Writes Kamal/Dokku/SSH deploy config into the target repo and expects a real VPS host/port. Mutating + needs remote infrastructure. |
| `install-opencode.sh` | Downloads a pinned opencode release from the network into `/tmp/opencode-bin`. Network-dependent. |
| `ci-smoke-test.sh` | Runs what CI runs (typecheck, lint, build, E2E) for the *enclosing project*; phases 2–3 need a JS/RN toolchain and can take minutes. Not hermetic. |
| `model-env.runtime-check.sh` | Downloads the pinned opencode binary and runs real `{env:SPEC_*_MODEL}` resolution against it. Network-dependent. |
| `validate-export-bundle.sh` | Validates an Expo web export for a React Native project; exits 2 ("skipped") in this repo and needs a full RN toolchain to reach any real assertion. |

## Characterized (spec 035)

`update-submodules.sh` is characterized end-to-end by
`ac-035-update-submodules.bats`: local `git init` fixtures with `file://`
remotes, a stub `gh` for PR creation, and `--dry-run` for the no-network
paths. The suite covers discovery, eligibility, dirty/diverged guards, the
local and PR-progression paths, failure exit codes, and dry-run plan output.

Partial coverage is recorded where it applies:

- `archive-spec.sh` — usage and not-found paths are tested; the success path
  moves `specs/NNN-slug/` into `docs/changes/` and is exercised by the pipeline
  itself (stage 5b), not from a test.
- `check-stop-and-ask-matrix.sh` — tested against fixtures only. Its
  `AC-009-03-03` assertion fails on any *uncommitted* change to
  `scripts/check-code-principles.sh`, so a repo-root run is not deterministic
  mid-branch.

## Scenario IDs

AC IDs appear only on tests that cover a real acceptance scenario — either an
archived one from `docs/changes/001-tdd-scaffolding-both-tracks.md` or a live
one under `specs/*/20-acceptance/` (e.g. `ac-035-update-submodules.bats`).
Tests covering behavior outside a scenario list are named descriptively with no
`AC-` prefix — inventing an AC ID for a scenario that does not exist would
defeat `scripts/check-scenario-traceability.sh`.
