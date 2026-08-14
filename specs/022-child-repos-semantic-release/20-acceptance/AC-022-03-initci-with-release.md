# AC-022-03: init-ci.sh --with-release emits a default-branch-gated release job on GitHub and GitLab

> Unconditional (human decisions D1 and D2): the flag ships, and its release
> job uses the reusable include on both platforms.

## AC-022-03-01 — --with-release is a valid flag and appears in the usage text
Given the script `scripts/init-ci.sh`
When it is run with `--with-release`
Then it accepts the flag and proceeds to generation
And the script's usage/unknown-flag text lists `--with-release`
And `bash -n scripts/init-ci.sh` exits 0

## AC-022-03-02 — GitHub generation emits the release job, gated on default-branch push, passing GH_TOKEN
Given the script `scripts/init-ci.sh`
When it is run with `--platform github --with-release --backend go`
Then the generated `.github/workflows/ci.yml` contains a job named `release`
And that job's `if` requires `github.event_name == 'push'` and `github.ref_name == github.event.repository.default_branch`
And that job uses `RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main`
And its `secrets` block contains exactly `GH_TOKEN: ${{ secrets.GH_TOKEN }}`
And no separate `release.yml` workflow file is emitted (the release job lives inside `ci.yml`, calling the reusable workflow)
And the generated file parses as YAML

## AC-022-03-03 — Regression guard: no flag, no release job
Given the script `scripts/init-ci.sh`
When it is run with `--platform github --backend go` (no `--with-release`)
Then the generated `.github/workflows/ci.yml` contains no job named `release`
And it contains no `GH_TOKEN` line

## AC-022-03-04 — Java-only --with-release run also emits .releaserc.json, never overwriting an existing one
Given the script `scripts/init-ci.sh`
When it is run with `--platform github --with-release --backend java` in a directory with no `.releaserc.json`
Then a `.releaserc.json` file is generated from `ci/templates/releaserc.json`
And if a `.releaserc.json` already exists, it is not overwritten

## AC-022-03-05 — GH_TOKEN is prompted and shown in the summary
Given the script `scripts/init-ci.sh`
When it is run with `--with-release` and interactive stdin
Then `collect_secrets` prompts for a `GH_TOKEN` value
And the printed summary lists `GH_TOKEN` in the GitHub secrets section
And the summary notes the release job

## AC-022-03-06 — GitLab symmetric: include + release job extending .semantic-release
Given the script `scripts/init-ci.sh`
When it is run with `--platform gitlab --with-release --backend go`
Then the generated `.gitlab-ci.yml` includes `local: .standards/ci/gitlab/shared/ci-release.yml`
And it defines a `release:` job extending `.semantic-release`
And the generated file parses as YAML

## AC-022-03-07 — Docs stay consistent with the flag
Given `docs/CI_CD.md`
When the `--with-release` flag is added to `init-ci.sh`
Then the Required Secrets table gains a `GH_TOKEN` row scoped to release (opt-in) only
And `## Release Process` mentions `init-ci.sh --with-release` as the generator path
And no `docs/[A-Z_]+.md` reference in the new text is broken

## AC-022-03-08 — Go-only --with-release run also emits .releaserc.json
Given the script `scripts/init-ci.sh`
When it is run with `--platform github --with-release --backend go` in a directory with no `.releaserc.json`
Then a `.releaserc.json` file is generated from `ci/templates/releaserc.json`
And if a `.releaserc.json` already exists, it is not overwritten
