# Why child repos have no auto-generated semantic-release bot (and the opt-in path)

A child repo bootstrapped with `init-ci.sh` gets working unit/lint/build/deploy CI
on day one, but **no release job**. The parent standards repo runs Semantic
Release after every merge to `main` (its own `.github/workflows/release.yml`),
and the docs *describe* how a child can do the same — yet the bootstrap never
emits the wiring. This spec documents why that asymmetry exists and whether it
should stay.

## Grounded reality (verified against the real tree)

- **The parent runs its own bot.** `.github/workflows/release.yml`: Semantic
  Release on push to `main`, `GH_TOKEN` secret, permissions `contents: write` +
  `issues` + `pull-requests` + `id-token`. The standards repo is itself a
  released artifact that child repos pin via the `.standards/` submodule.
- **The release job exists for children as a reusable workflow.**
  `.github/workflows/shared/ci-release.yml` — `workflow_call` with a required
  `GH_TOKEN` secret, same permission block, cycjimmy/semantic-release-action,
  plugins incl. `@semantic-release/git` (auto-commits `CHANGELOG.md` back to
  `main`) and `@semantic-release/exec`.
- **The config ships.** `scripts/init-ci.sh` `_gh_releaserc` copies
  `ci/templates/releaserc.json` → child's `.releaserc.json` (branches: main,
  tagFormat `v${version}`, changelog+git+github plugins).
- **The bootstrap does NOT wire the job.** `init-ci.sh`'s GitHub generator emits
  `backend-ci`/`frontend-ci` jobs passing `docker-registry` + `GHCR_TOKEN` (and
  `EXPO_TOKEN` for RN) — no `release:` job, no `GH_TOKEN` secret.
  `collect_secrets()` prompts for GHCR_TOKEN / NPM_TOKEN / MAVEN_* / EXPO_TOKEN
  — never GH_TOKEN. Child drop-in templates (`ci/templates/child-ci-node.yml`,
  `child-ci-react-native.yml`) have no release job.
- **The docs show the manual path.** `docs/CI_CD.md §Release Process` documents
  the full flow: "Copy `ci/templates/releaserc.json` to `.releaserc.json` in the
  child repo. Required secrets: `GH_TOKEN`", and the generated-`ci.yml` example
  in the same doc includes a `release:` job calling
  `shared/ci-release.yml@main` with `GH_TOKEN` — but **no generated file ever
  contains that block**; it appears only as a doc example.

So the asymmetry is real and structural: *config + reusable job + docs* exist,
but *generation* stops at CI. A child that follows the docs can wire release in
a few manual steps; a child that only runs `init-ci.sh` silently has no bot.

## What this spec must deliver

1. **Document the rationale** — why the bootstrap doesn't auto-wire the release
   job. Candidate reasons (to confirm or refute in grounding):
   - **Credentials are repo-owned, not bootstrappable.** Semantic Release needs
     a repo-scoped write token (`GH_TOKEN`, `contents: write`). `init-ci.sh`
     generates config and CI wiring; it cannot provision secrets. Every child
     release requires a human to add the secret regardless — generating the
     workflow without it creates a permanently failing job.
   - **Release is an authority, not a job.** It creates tags, publishes
     releases, and auto-commits `CHANGELOG.md` to `main`
     (`@semantic-release/git`). CI jobs are side-effect-free and safe to
     auto-generate; release changes repo state and publishes artifacts — a
     per-repo ownership decision (approval gates, release cadence, whether the
     repo is versioned at all).
   - **Not every child repo has a release cadence.** Services under active
     change get tags; internal/experimental repos would get noisy releases.
     Opt-in lets each child decide.
   - **The standards repo's own bot is the exception that proves the rule**: the
     parent is itself the released artifact (submodule pinning), so its release
     automation is its own wiring, not a bootstrap template.
2. **Decide the open question explicitly** (human gate): is the current state
   (a) the intended design — then the spec documents the rationale and the
   opt-in steps as the standard, and optionally adds an `init-ci.sh --with-release`
   opt-in flag; or (b) a gap — then the spec extends `init-ci.sh` to emit the
   `release:` job (gated on default branch) + prompt for `GH_TOKEN` + update
   child templates and the summary. Prefer the documented-opt-in reading unless
   the human says otherwise.
3. **Docs** — `docs/CI_CD.md §Release Process` gains a subsection explaining why
   the bootstrap doesn't emit the release job and the exact opt-in steps (copy
   `releaserc.json` — already done by init-ci.sh; add the `release:` job block
   calling `shared/ci-release.yml@main`; add the `GH_TOKEN` secret). The
   architecture tree / secrets table stay consistent.
4. **Self-CI** — `make lint`, `make validate-all`, `check-orchestration.sh`,
   `check-skills.sh` stay green; any new `docs/[A-Z_]+.md` references resolve.

## Acceptance criteria

- AC-001: `docs/CI_CD.md §Release Process` documents why the bootstrap doesn't
  wire the release job (credentials repo-owned, release-as-authority, opt-in
  cadence) and the parent-vs-child asymmetry.
- AC-002: the same section documents the exact opt-in steps a child follows to
  get a semantic-release bot (releaserc.json already generated; add release job
  → shared/ci-release.yml@main; add GH_TOKEN secret) — reproducible from docs
  alone.
- AC-003: if `--with-release` is in scope (open question), `init-ci.sh
  --with-release` emits a `release:` job gated on the default branch passing
  `GH_TOKEN: ${{ secrets.GH_TOKEN }}` to `shared/ci-release.yml@main`, prompts
  for `GH_TOKEN`, and lists it in the summary; `--platform gitlab` symmetric.
- AC-004: docs state the boundary: a child repo that never opts in still gets
  green unit/lint/build with no failing release job and no required secret.
- AC-005: all gates green, no CRLF, orchestration refs resolve.

## Open questions (need a human answer)

1. Intended design vs gap — document rationale only, or also add the
   `init-ci.sh --with-release` opt-in flag?
2. If the flag is in scope: should `--with-release` imply the parent-style
   release workflow (own file) or the reusable `shared/ci-release.yml@main`
   include (consistent with docs)?
3. Should `docs/CI_CD.md` mention when NOT to enable release (experimental /
   internal-only repos), or keep the opt-in neutral?
