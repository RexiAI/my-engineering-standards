# Tasks — Child repos and the semantic-release bot: rationale, opt-in path, and the --with-release flag

Formalization of `specs/022-child-repos-semantic-release/00-informal.md`. The
release bot exists for children (reusable workflow + config + docs) but the
bootstrap never emits the wiring. This spec (a) documents the rationale for that
asymmetry in `docs/CI_CD.md §Release Process`, (b) documents the exact opt-in
steps, and (c) ships the `init-ci.sh --with-release` opt-in flag, which emits
the release job via the reusable include on both platforms. All four tasks are
unconditional; the human gate has resolved the open questions (decisions log
below).

## Grounded reality (verified, do not re-derive)

- **Parent bot.** `.github/workflows/release.yml`: Semantic Release on
  `push: branches: [main]`, `GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}`,
  `permissions: contents/issues/pull-requests/id-token: write`. The standards
  repo is itself the released artifact children pin via the `.standards/`
  submodule.
- **Reusable job exists for children.** `.github/workflows/shared/ci-release.yml`:
  `workflow_call` with a **required** `GH_TOKEN` secret, same permission block,
  `cycjimmy/semantic-release-action@v4`, plugins incl. `@semantic-release/git`
  (auto-commits `CHANGELOG.md` back to `main`) and `@semantic-release/exec`.
  The `release` job inside has **no `if:` of its own** — the default-branch gate
  lives on the caller's job (see the docs example, CI_CD.md lines 151-157).
- **Config ships, conditionally — and only without the flag.** `scripts/init-ci.sh`
  `_gh_releaserc()` copies `ci/templates/releaserc.json` → child `.releaserc.json`
  **only when the child has a node backend or a frontend** (`_has_node_backend ||
  FRONTEND` non-empty). A Java-only or Go-only child gets no `.releaserc.json` at
  all from a default run; `--with-release` changes this (Task 3, decision D3).
- **Bootstrap does NOT wire the job.** `generate_github_ci()` emits
  `backend-ci-${lang}` jobs (docker-registry + GHCR_TOKEN + PACT_BROKER_URL) and
  a `frontend-ci` job (docker-registry + GHCR_TOKEN, or node-version +
  EXPO_TOKEN for RN), plus `deploy:` only under `--with-deploy`. No `release:`
  job, no `GH_TOKEN` anywhere in the script (grep-verified). `generate_gitlab()`
  includes `.standards/ci/gitlab/gitlab-ci.yml` + per-layer files; no
  `ci-release.yml` include. `collect_secrets()` prompts GHCR_TOKEN,
  MAVEN_USERNAME/MAVEN_PASSWORD (java), NPM_TOKEN (node/frontend), EXPO_TOKEN
  (RN), SONAR_TOKEN (optional), PACT_BROKER_URL (optional) — never GH_TOKEN.
  `_print_gh_secrets()` (summary) has no GH_TOKEN row.
- **Child drop-in templates have no release job.** `ci/templates/child-ci-node.yml`
  and `child-ci-react-native.yml` — CI jobs only.
- **GitLab reusable exists.** `ci/gitlab/shared/ci-release.yml` defines hidden
  jobs `.release-variables` (NODE_VERSION 22), `.release-setup` (node image,
  `npm ci --omit=dev`), `.semantic-release` (extends `.release-setup`, runs
  `npx semantic-release`, `rules: - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH`).
  It references no token variable today; the docs name the credential as "a
  project access token with `write_repository` scope (GitLab)".
- **Docs show the manual path.** `docs/CI_CD.md §Release Process` (heading
  `## Release Process`, line 364): trigger, version-bump table, "What Semantic
  Release does", and §Configuration ("Copy `ci/templates/releaserc.json` to
  `.releaserc.json` in the child repo. Required secrets: `GH_TOKEN` (GitHub) or
  a project access token with `write_repository` scope (GitLab)."). The
  generated-`ci.yml` example earlier in the doc (lines 132-165) includes a
  `release:` job (`if: github.ref_name == github.event.repository.default_branch`,
  `uses: …/shared/ci-release.yml@main`, `GH_TOKEN`) — **doc example only**; no
  generator or template emits that block.
- **Required Secrets table** (`### Required Secrets`, line 291) lists GHCR_TOKEN,
  MAVEN_USERNAME, MAVEN_PASSWORD, NPM_TOKEN, SONAR_TOKEN, PACT_BROKER_URL,
  EXPO_TOKEN — no GH_TOKEN row.
- **Self-CI gates:** `make lint` (JSON + YAML parse), `make validate-all`
  (= validate + validate-docs + validate-refs + validate-skills),
  `scripts/check-orchestration.sh`, `scripts/check-skills.sh`, no CRLF in
  committed blobs. `validate-refs` scans every `*.md` outside `specs/` for
  `docs/[A-Z_]+.md` references — new doc text must not introduce a broken one.
- **Unrelated pivot (do not touch):** the repo recently added §Archive /
  §Definition of done to `docs/SPEC_PIPELINE.md` and deleted a post-merge
  `archive-spec.yml` bot workflow. That is a spec-pipeline lifecycle change, not
  the release question this spec addresses.

## Tasks

### Task 1 — `docs/CI_CD.md §Release Process`: document why the bootstrap does not emit the release job

Add a rationale subsection under `## Release Process` that turns the asymmetry
into documented intent. Covers informal AC-001.

Acceptance criteria:
- `docs/CI_CD.md` `## Release Process` gains a subsection (e.g.
  `### Why init-ci.sh doesn't wire the release job`) that states, at minimum,
  the three rationale points:
  - **Credentials are repo-owned, not bootstrappable.** Semantic Release needs a
    repo-scoped write token (`GH_TOKEN`, `contents: write`); `init-ci.sh`
    generates config and CI wiring but cannot provision secrets; every child
    release requires a human to add the secret regardless — generating the
    workflow without it creates a permanently failing job.
  - **Release is an authority, not a job.** It creates tags, publishes releases,
    and auto-commits `CHANGELOG.md` to `main` (`@semantic-release/git`). CI jobs
    are side-effect-free and safe to auto-generate; release changes repo state
    and publishes artifacts — a per-repo ownership decision (approval gates,
    release cadence, whether the repo is versioned at all).
  - **Not every child repo has a release cadence.** Services under active change
    get tags; internal/experimental repos would get noisy releases. Opt-in lets
    each child decide.
- The subsection documents the parent-vs-child asymmetry: the parent runs its
  own `.github/workflows/release.yml` because the standards repo is itself the
  released artifact that children pin via the `.standards/` submodule — its bot
  is the parent's own wiring, not a bootstrap template.
- The subsection's factual claims match the tree: it states that `init-ci.sh`
  emits no `release:` job and never prompts for `GH_TOKEN`, and that the
  `release:` block in the generated-`ci.yml` example exists in the docs only,
  never in generated output.
- No `docs/[A-Z_]+.md` reference introduced by the new text is broken.

Scenarios: `20-acceptance/AC-022-01-docs-rationale.md`

### Task 2 — `docs/CI_CD.md §Release Process`: document the exact opt-in steps and the no-op boundary

Add the step-by-step opt-in path under `## Release Process`, and the boundary
statement: a child that never opts in stays green with no failing release job
and no required secret. Covers informal AC-002 and AC-004.

Acceptance criteria:
- The subsection (e.g. `### Opting in: wiring the release bot`) documents, in
  order and reproducible from docs alone:
  1. **`.releaserc.json`** — for Node-backend or frontend children,
     `init-ci.sh` already generates it (`_gh_releaserc`); a Java-only or
     Go-only child copies `ci/templates/releaserc.json` to `.releaserc.json`
     manually. (With `init-ci.sh --with-release`, the script generates it for
     Java-only/Go-only children too — Task 3; the manual copy applies to the
     manual path.)
  2. **Add the `release:` job** to `.github/workflows/ci.yml` — a copyable
     block calling `RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main`,
     gated on a push to the default branch, passing
     `GH_TOKEN: ${{ secrets.GH_TOKEN }}`. The block's secret key must be
     exactly `GH_TOKEN` (the reusable declares it `required: true`; GitHub
     errors on an undeclared secret).
  3. **Add the `GH_TOKEN` secret** in the child repo (GitHub Actions) — or a
     project access token with `write_repository` scope for the GitLab include
     path (`ci/gitlab/shared/ci-release.yml`, extending `.semantic-release`).
- The boundary statement appears in the same section: a child that never opts in
  still gets green unit/lint/build, no failing release job, and no required
  `GH_TOKEN` secret.
- The copyable block's `uses:` path resolves to a real file
  (`.github/workflows/shared/ci-release.yml` exists), and any GitLab mention
  resolves to `ci/gitlab/shared/ci-release.yml` (exists).
- No `docs/[A-Z_]+.md` reference introduced by the new text is broken.

Scenarios: `20-acceptance/AC-022-02-docs-optin-path.md`

### Task 3 — `scripts/init-ci.sh --with-release`: opt-in flag emitting the release job on both platforms

Unconditional (human decision D1). The release job calls the reusable include —
`shared/ci-release.yml@main` on GitHub; `local:
.standards/ci/gitlab/shared/ci-release.yml` + extend `.semantic-release` on
GitLab — consistent with the docs example. No parent-style standalone
`release.yml` is emitted on either platform (human decision D2). Covers
informal AC-003.

Acceptance criteria:
- `bash -n scripts/init-ci.sh` exits 0.
- Flag parsing: `--with-release` is accepted (sets `WITH_RELEASE_FLAG=true`);
  the usage/`Unknown flag` text lists it alongside `--with-saga`,
  `--with-deploy`, `--deploy-tool`.
- **GitHub generation** (`--platform github --with-release`): the emitted
  `.github/workflows/ci.yml` gains a `release:` job after the existing jobs
  that:
  - carries `if: ${{ github.event_name == 'push' && github.ref_name == github.event.repository.default_branch }}`
    (the reusable has no internal gate — the condition must live on the emitted
    job, mirroring `_gh_deploy_job`),
  - `uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main`,
  - passes exactly `GH_TOKEN: ${{ secrets.GH_TOKEN }}` in `secrets:`,
  - is emitted as a job inside the existing `.github/workflows/ci.yml` — no
    separate `release.yml` workflow file is created (the reusable include is
    the mechanism, not a parent-style own workflow).
- **Regression guard:** without `--with-release`, generated `ci.yml` contains no
  `release:` job and no `GH_TOKEN` line (unchanged default output).
- **Config coupling (unconditional, decision D3):** `--with-release` always
  also generates/copies `ci/templates/releaserc.json` → `.releaserc.json`, even
  for Java-only/Go-only children where `_gh_releaserc` would not have copied it
  (a release job without config is broken). An existing `.releaserc.json` is
  still never overwritten.
- `collect_secrets()` prompts for `GH_TOKEN` when `--with-release` is set;
  `print_summary()` lists `GH_TOKEN` in the GitHub secrets section and notes the
  release job when the flag is set.
- **GitLab symmetric** (`--platform gitlab --with-release`): the emitted
  `.gitlab-ci.yml` includes `local: .standards/ci/gitlab/shared/ci-release.yml`
  and defines a `release:` job extending `.semantic-release` (the template's
  default-branch rule applies); the summary notes the GitLab token requirement
  (project access token, `write_repository` scope) without inventing a variable
  name the template does not use. The include references the standards repo's
  `ci/gitlab/shared/ci-release.yml` — no own `ci-release.yml` copy is emitted
  (parent-style alternative rejected, decision D2).
- `docs/CI_CD.md` stays consistent with the flag: the Required Secrets table
  gains a `GH_TOKEN` row scoped "release (opt-in) only", and §Release Process
  mentions `init-ci.sh --with-release` as the generator path.
- Both generated files (`.github/workflows/ci.yml`, `.gitlab-ci.yml`) parse as
  YAML when generated with the flag.

Scenarios: `20-acceptance/AC-022-03-initci-with-release.md`

### Task 4 — Self-CI gates green

The repo's own CI runs on the PR that ships these files. Covers informal AC-005.

Acceptance criteria:
- `make lint` exits 0.
- `make validate-all` exits 0 (includes validate-refs: any new
  `docs/[A-Z_]+.md` reference resolves).
- `scripts/check-orchestration.sh` exits 0.
- `scripts/check-skills.sh` exits 0.
- `bash -n scripts/init-ci.sh` exits 0 (re-run after all edits).
- None of the changed files contains a CRLF byte (`grep -qU $'\r$'` on each
  returns non-zero).
- `git status` shows changes only under the paths this spec touches:
  `docs/CI_CD.md`, `scripts/init-ci.sh`, and
  `specs/022-child-repos-semantic-release/`.

Scenarios: `20-acceptance/AC-022-04-self-ci-gates.md`

## Acceptance criteria mapping

| Informal AC | Task(s) | Scenario file |
|---|---|---|
| AC-001 rationale (credentials repo-owned, release-as-authority, opt-in cadence, parent-vs-child asymmetry) | 1 | `AC-022-01-docs-rationale.md` |
| AC-002 exact opt-in steps reproducible from docs alone | 2 | `AC-022-02-docs-optin-path.md` |
| AC-003 `--with-release` emits gated release job + GH_TOKEN prompt + summary; GitLab symmetric | 3 | `AC-022-03-initci-with-release.md` |
| AC-004 no-op child boundary (no failing job, no required secret) | 2 | `AC-022-02-docs-optin-path.md` |
| AC-005 gates green, no CRLF, refs resolve | 4 | `AC-022-04-self-ci-gates.md` |

## Decisions (human answers, 2026-08-14)

All four open questions from the prior pass are resolved. Task 3 ships
unconditionally; no further human gate before `/build`.

1. **The flag ships (D1).** Answer to "intended design vs gap": (b) — ship
   Task 3, the `init-ci.sh --with-release` opt-in flag. All conditional framing
   is removed from Task 3 and AC-022-03; the "written to be struck" framing is
   gone.
2. **Reusable include, not parent-style workflow (D2).** Answer to "reusable
   include vs parent-style workflow": the reusable include. The flag's release
   job calls `shared/ci-release.yml@main` on GitHub, and `local:
   .standards/ci/gitlab/shared/ci-release.yml` + extend `.semantic-release` on
   GitLab — no standalone parent-style `release.yml` (GitHub) and no own
   `ci-release.yml` copy (GitLab). T3's generation criteria and AC-022-03
   already stated the reusable include; the wording is now firm rather than a
   default-if-approved.
3. **Force `.releaserc.json` for Java/Go-only children (D3).** Answer to
   "force `.releaserc.json` for non-Node children?": yes. When `--with-release`
   is set and the child is Java-only or Go-only (where `_gh_releaserc` does not
   copy the config), `init-ci.sh` also generates/copies
   `ci/templates/releaserc.json` → `.releaserc.json`. An existing
   `.releaserc.json` is never overwritten. Folded into T3's acceptance criteria
   and AC-022-03-04 / AC-022-03-08.
4. **Neutral opt-in wording (D4).** Answer to "mention when NOT to enable
   release?": keep the opt-in subsection neutral — no experimental /
   internal-only guidance in the opt-in steps. The cadence point appears only
   in Task 1's rationale (why the bootstrap doesn't auto-wire), never as opt-in
   advice. T2 and AC-022-02 already contain no such framing; verified, no
   change needed.

## Grounding corrections to the informal spec

1. **`.releaserc.json` generation is Node/frontend-only.** `_gh_releaserc()`
   copies only when the child has a node backend or any frontend; a Java-only or
   Go-only child gets no `.releaserc.json` from `init-ci.sh`. AC-002's "copy
   `releaserc.json` — already done by init-ci.sh" is true only for
   Node/frontend children; Task 2's step 1 states the Java/Go manual copy.
2. **`collect_secrets()` also prompts `SONAR_TOKEN` and `PACT_BROKER_URL`**
   (both optional) beyond the GHCR/NPM/MAVEN/EXPO set the informal spec lists.
   No behavior change; noted for accuracy in Task 3's summary work.
3. **The reusable `ci-release.yml` has no internal default-branch gate.** The
   `if: github.ref_name == github.event.repository.default_branch` lives on the
   caller's job (docs example lines 151-157). Any emitted `release:` job (Task 3)
   must carry the condition itself — `_gh_deploy_job` is the house pattern.
4. **GitLab "symmetric" = include + extend `.semantic-release`.** The GitLab
   template declares no token variable today; the docs name the credential only
   as "a project access token with `write_repository` scope". Task 3's GitLab
   criteria avoid inventing a variable name the template does not reference.
5. **The pipeline pivot is unrelated.** `docs/SPEC_PIPELINE.md` §Archive /
   §Definition of done and the deleted `archive-spec.yml` concern spec lifecycle,
   not child release wiring; do not touch them in this spec's diff.
