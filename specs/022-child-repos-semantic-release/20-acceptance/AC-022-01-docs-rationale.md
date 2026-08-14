# AC-022-01: docs/CI_CD.md §Release Process documents why the bootstrap does not emit the release job

## AC-022-01-01 — The rationale subsection exists and names all three reasons
Given `docs/CI_CD.md`
When the `## Release Process` section is read
Then it contains a subsection whose title mentions why `init-ci.sh` does not wire the release job
And that subsection states credentials are repo-owned and not bootstrappable (a repo-scoped write token such as `GH_TOKEN` must be added by a human per repo)
And it states release is an authority, not a job (it creates tags, publishes releases, and auto-commits `CHANGELOG.md` to `main`)
And it states not every child repo has a release cadence, so the release job is opt-in

## AC-022-01-02 — The parent-vs-child asymmetry is documented
Given the rationale subsection in `## Release Process`
When it is read
Then it states the parent standards repo runs its own `.github/workflows/release.yml` because the parent is itself the released artifact children pin via the `.standards/` submodule
And it states a child's release bot is a per-child opt-in decision, not a bootstrap template

## AC-022-01-03 — The rationale matches the real tree
Given the rationale subsection in `## Release Process`
And the file `scripts/init-ci.sh`
When both are read
Then the subsection states that `init-ci.sh` emits no `release:` job
And it states that `init-ci.sh` never prompts for `GH_TOKEN`
And it states that the `release:` job block shown in the generated-`ci.yml` example exists in the docs only and is never produced by generation
And each of those three claims is true of the current `scripts/init-ci.sh` (no `release:` job in `generate_github_ci`, no `GH_TOKEN` anywhere in the script)
