# AC-022-02: docs/CI_CD.md §Release Process documents the exact opt-in steps and the no-op child boundary

## AC-022-02-01 — Step 1: .releaserc.json, already generated for Node/frontend, manual copy for Java/Go
Given the opt-in subsection in `docs/CI_CD.md` `## Release Process`
When it is read
Then step 1 states that `init-ci.sh` already generates `.releaserc.json` for child repos with a node backend or a frontend
And it states that a Java-only or Go-only child copies `ci/templates/releaserc.json` to `.releaserc.json` manually
And `ci/templates/releaserc.json` exists in the standards repo

## AC-022-02-02 — Step 2: a copyable release job block calling the real reusable workflow
Given the opt-in subsection in `docs/CI_CD.md` `## Release Process`
When it is read
Then step 2 shows a copyable `release:` job block for the child's `.github/workflows/ci.yml`
And the block calls `RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main`
And the block is gated on a push to the default branch
And the block passes exactly the secret `GH_TOKEN: ${{ secrets.GH_TOKEN }}`
And the referenced file `.github/workflows/shared/ci-release.yml` exists and declares a required `GH_TOKEN` secret

## AC-022-02-03 — Step 3: the GH_TOKEN secret (or GitLab write_repository token)
Given the opt-in subsection in `docs/CI_CD.md` `## Release Process`
When it is read
Then step 3 states the child must add a `GH_TOKEN` secret in GitHub Actions
And it states the GitLab alternative is a project access token with `write_repository` scope
And it references the GitLab include path `ci/gitlab/shared/ci-release.yml`, which exists in the standards repo

## AC-022-02-04 — The no-op boundary: never opting in stays green
Given the opt-in subsection in `docs/CI_CD.md` `## Release Process`
When it is read
Then it states that a child repo that never opts in keeps green unit/lint/build CI
And it states that such a child has no failing release job
And it states that such a child requires no `GH_TOKEN` secret
And this matches what `scripts/init-ci.sh` actually emits without `--with-release` (no release job, no GH_TOKEN)

## AC-022-02-05 — Reproducible from docs alone, no broken doc references
Given the opt-in subsection in `docs/CI_CD.md` `## Release Process`
When a reader follows the three steps using only the docs and the standards repo files they reference
Then no step depends on information outside the docs and those files
And every `docs/[A-Z_]+.md` reference in the new text resolves to an existing file
