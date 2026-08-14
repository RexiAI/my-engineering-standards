# 022-child-repos-semantic-release

> Spec pipeline archive. Original source: `specs/022-child-repos-semantic-release/` (deleted by this script).
> Archived: 2026-08-14

## Original ask

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

## Tasks

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

## Acceptance scenarios

## AC-022-01-01 — The rationale subsection exists and names all three reasons
## AC-022-01-02 — The parent-vs-child asymmetry is documented
## AC-022-01-03 — The rationale matches the real tree
## AC-022-02-01 — Step 1: .releaserc.json, already generated for Node/frontend, manual copy for Java/Go
## AC-022-02-02 — Step 2: a copyable release job block calling the real reusable workflow
## AC-022-02-03 — Step 3: the GH_TOKEN secret (or GitLab write_repository token)
## AC-022-02-04 — The no-op boundary: never opting in stays green
## AC-022-02-05 — Reproducible from docs alone, no broken doc references
## AC-022-03-01 — --with-release is a valid flag and appears in the usage text
## AC-022-03-02 — GitHub generation emits the release job, gated on default-branch push, passing GH_TOKEN
## AC-022-03-03 — Regression guard: no flag, no release job
## AC-022-03-04 — Java-only --with-release run also emits .releaserc.json, never overwriting an existing one
## AC-022-03-05 — GH_TOKEN is prompted and shown in the summary
## AC-022-03-06 — GitLab symmetric: include + release job extending .semantic-release
## AC-022-03-07 — Docs stay consistent with the flag
## AC-022-03-08 — Go-only --with-release run also emits .releaserc.json
## AC-022-04-01 — make lint exits 0
## AC-022-04-02 — make validate-all exits 0
## AC-022-04-03 — check-orchestration.sh exits 0
## AC-022-04-04 — check-skills.sh exits 0
## AC-022-04-05 — init-ci.sh still parses after all edits
## AC-022-04-06 — No CRLF, and the diff is scoped to this spec's paths

## Verification

# Verification — Child repos and the semantic-release bot (spec 022)

Verifier: independent re-execution of stages 2–3 claims. None of the Coder's or
Refactorer's self-reports were taken on faith; every claim below was re-run
against the live tree and real exit codes. `00-informal.md` was not read.

Branch: `spec/022-child-repos-semantic-release`
Verdict: **PASS** (with pre-existing debt flagged, none introduced by this branch)

---

## 1. Full gate suite — PASS (all real exit codes)

| Gate | Command | Exit |
|---|---|---|
| lint | `make lint` | 0 |
| validate-all | `make validate-all` ( = validate + validate-docs + validate-refs + validate-skills, Makefile:79) | 0 |
| orchestration | `scripts/check-orchestration.sh` | 0 |
| skills | `scripts/check-skills.sh` | 0 |
| shell parse | `bash -n scripts/init-ci.sh` | 0 |
| CRLF scan | `grep -qU $'\r$'` on `docs/CI_CD.md`, `scripts/init-ci.sh`, `specs/022-child-repos-semantic-release/10-tasks.md`, all four `20-acceptance/*.md` | none matched (all clean) |

All six executed from a clean shell in the repo root, output captured to files,
exits verified with `echo $?` (not rtk-filtered). `make validate-all` warns on
`skills/hallmark/SKILL.md` (562 lines > 500 limit, pre-existing, unrelated) but
exits 0.

## 2. Task-level checks — PASS

### 2a. `docs/CI_CD.md` §Release Process (Tasks 1–2)

Diff read in full (`git diff HEAD -- docs/CI_CD.md`, +78 lines). Claims verified
against the tree and by execution:

- Rationale subsection `### Why init-ci.sh doesn't wire the release job` exists
  and states all three reasons verbatim: credentials repo-owned/not
  bootstrappable (GH_TOKEN + `contents: write`, human must add the secret),
  release-as-authority (tags, releases, `@semantic-release/git` auto-commits
  CHANGELOG.md to main), opt-in cadence (not every child is versioned). Parent-
  vs-child asymmetry documented: parent runs its own
  `.github/workflows/release.yml` because it is the artifact children pin via
  `.standards/` — file exists (858B).
- "These claims match the tree" statement is **true**, confirmed by execution:
  default (no-flag) `init-ci.sh` emits no `release:` job and no `GH_TOKEN`
  (see 2b byte-identity runs); the `release:` block in the generated-`ci.yml`
  example (docs lines ~151–157) is docs-only — the generator never emits it.
- Opt-in subsection `### Opting in: wiring the release bot` has the 3 steps in
  order: (1) `.releaserc.json` — Node/frontend auto-generated by `_gh_releaserc`
  (code verified: `_has_node_backend || [ -n "$FRONTEND" ]`), Java/Go manual
  copy of `ci/templates/releaserc.json` (exists, 262B); (2) copyable `release:`
  block with exact `uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main`
  and `secrets: GH_TOKEN: ${{ secrets.GH_TOKEN }}`; (3) GH_TOKEN secret, GitLab
  alternative = project access token `write_repository` scope +
  `ci/gitlab/shared/ci-release.yml` (exists; contains `.semantic-release` hidden
  job with `rules: - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH`, no token
  variable).
- Reusable workflow claim verified: `.github/workflows/shared/ci-release.yml`
  declares `GH_TOKEN` `required: true` (line 8) and uses
  `GITHUB_TOKEN: ${{ secrets.GH_TOKEN }}`; no internal default-branch gate.
- No-op boundary statement present ("A child that never opts in is
  unaffected… purely additive") and matches actual no-flag emission.
- Anchor `[GitHub Actions: Child composes Parent](#github-actions-child-composes-parent)`
  resolves (heading at docs line 128). `validate-refs` (part of validate-all)
  green — no broken `docs/[A-Z_]+.md` references introduced.
- Required Secrets table gained `| GH_TOKEN | Semantic Release (release, opt-in only) |`
  (AC-022-03-07).

### 2b. `scripts/init-ci.sh --with-release` (Task 3) — executed against fresh scratch dirs

Harness: scratch trees under `/tmp/opencode/vf-scratch/` with `.standards`
symlinks; a `headrepo-copy` with `git show HEAD:scripts/init-ci.sh` as baseline.
All runs with `</dev/null` (non-interactive) unless noted. Every generated file
parsed with the repo's own linter invocation (`python3 -c "import yaml;
yaml.safe_load(...)"`, `python3 -m json.tool`).

1. **Flag parse** — `--with-release` accepted (sets `WITH_RELEASE_FLAG=true`).
   Unknown-flag path prints usage listing `[--with-release]` alongside
   `--with-saga`, `--with-deploy`, `--deploy-tool`. `bash -n` exit 0.
2. **GitHub go + flag** — generated `.github/workflows/ci.yml` contains exactly:
   ```yaml
   release:
     if: ${{ github.event_name == 'push' && github.ref_name == github.event.repository.default_branch }}
     uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main
     secrets:
       GH_TOKEN: ${{ secrets.GH_TOKEN }}
   ```
   `.github/workflows/` contains only `ci.yml` — **no standalone `release.yml`**.
   YAML parses. `.releaserc.json` generated for Go-only child (decision D3).
3. **No-flag regression guard — byte-identical to pre-change.** HEAD-script vs
   new-script runs (GitHub go, GitLab go, GitHub node+nextjs): generated trees
   byte-identical (`diff -r` = 0 lines) and stdout byte-identical (only the
   scratch-dir absolute-path lines differ). No-flag `ci.yml` has 0 `release` /
   `GH_TOKEN` matches. The `print_summary` refactor is output-preserving
   (HEAD's summary also ended with an unconditional `echo ""`).
4. **Java + flag / Go + flag → `.releaserc.json`; never overwrites.** Java run
   generated `.releaserc.json` (262B, == template). Pre-seeded
   `{"branches":["custom"],"custom":true}` survived a re-run byte-for-byte.
5. **GitLab go + flag** — `.gitlab-ci.yml` contains
   `- local: .standards/ci/gitlab/shared/ci-release.yml` (include list) and
   `release:\n  extends: .semantic-release`. No own `ci-release.yml` copy in the
   child root. YAML parses. Summary prints the GitLab token requirement
   ("project access token with write_repository scope") without inventing a
   variable name.
6. **GH_TOKEN prompt + summary (interactive)** — run under a pseudo-tty
   (`script -qec`): prompt `GH_TOKEN (Semantic Release, opt-in): ` appears;
   summary lists `- GH_TOKEN (Semantic Release, opt-in only)` in the GitHub
   secrets section and prints the `Release (opt-in):` note with the GH_TOKEN /
   GitLab token row. Non-interactive runs correctly skip the prompt (GH_TOKEN
   stays empty and is omitted from the summary — matches the no-op boundary).
7. **Node/frontend unchanged** — node+nextjs no-flag run: HEAD vs new stdout
   and tree byte-identical; `.releaserc.json` generated on default run as
   before.

### 2c. Scope claim — PASS

`git status` (porcelain): modified tracked files are exactly `docs/CI_CD.md`
and `scripts/init-ci.sh`; remainder is pre-existing untracked debris
(`commands/opsx-*.md`, `openspec/`, `config/model.local.env copy.example`,
`specs/002-005-*`). No staged changes, no other tracked modifications.

## 3. Design-principles gate — FAIL *pre-existing only*, branch introduces none

`bash scripts/check-code-principles.sh` — exit code **1**, summary line:
`✘ Design-principles check: 5 FAIL(s), 17 WARN(s).`

FAIL lines, verbatim:
```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

- **None of the 5 FAILs touches a file changed by this branch.** All are in
  `ci/templates/` saga files last committed 2026-07-12 (v1.3.0, commit c81b75d).
- Tracked content byte-identical to HEAD: `git diff HEAD` empty for all
  `ci/` files, `git status --porcelain ci/` empty, `git ls-files -s` blobs match
  `HEAD:`. (Note: the *working tree* copy of `go-saga-lint.go` contains CRLF
  bytes, but `.gitattributes` (`* text=auto eol=lf`) normalizes — git reports
  it clean and the committed blob is LF; this is a pre-existing checkout
  artifact, not a branch change.)
- **Refactorer's count is inaccurate: claimed 6 pre-existing FAILs, actual is
  5.** (Likely counted the summary line "5 FAIL(s)" as a sixth.) This is a
  report-accuracy WARN, not a branch defect — the direction of the claim
  (pre-existing, untouched) is verified true.
- WARNs (17, all pre-existing, none on changed files): method-body >20 lines
  (go-saga-lint.go x5), possible duplication (go-saga-lint.go x6,
  saga-compensation.js x4), empty method body (OutboxArchRules.java:30,
  SagaArchRules.java:33). Full list captured in the run log.
- Changed files (`docs/CI_CD.md`, `scripts/init-ci.sh`) produce **zero** FAILs
  and **zero** WARNs from this gate. This branch adds no new design-principle
  debt; the exit-1 gate is repo debt predating the branch.

## 4. Traceability — PASS for 022, pre-existing noise elsewhere

`scripts/check-scenario-traceability.sh` — exit 1, `121 violation(s)`, 10
PASSes, 108 scenario IDs found.

- All four 022 IDs **PASS** (traced): `AC-022-01 … AC-022-04` — each cited by
  the deliverable-file comment header in `scripts/init-ci.sh` (house pattern);
  inline comments additionally cite AC-022-03-01/-02/-03/-04/08/-05/-06, all of
  which resolve to real sub-scenarios. No stale or unaccounted 022 references.
- The 121 FAILs are all pre-existing noise: untraced scenarios from untracked
  scratch specs (002–005, which have no tests) and stale AC-020/AC-021 test
  references (archived spec 021 — tests still cite IDs whose scenario files
  were removed by archiving).
- **Delta claim verified arithmetically:** 121 now + 4 (the four 022 IDs that
  this branch's citations turned from FAIL into PASS) = 125 before. Matches the
  Coder's report.

## 5. Spot check: scenario-to-behavior (2 scenarios)

- **AC-022-03-02** (GitHub release job): scenario asserts job named `release`,
  `if` requiring `github.event_name == 'push'` + `github.ref_name ==
  default_branch`, `uses: …/shared/ci-release.yml@main`, secrets exactly
  `GH_TOKEN: ${{ secrets.GH_TOKEN }}`, no separate `release.yml`, YAML parses.
  Asserted against the actual generated file from a fresh scratch run — every
  clause matches byte-for-byte; the reusable declares `GH_TOKEN` required.
- **AC-022-02-02** (copyable block): scenario asserts the block calls
  `RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main`,
  is gated on default-branch push, passes exactly `GH_TOKEN`, and the
  referenced file exists and declares GH_TOKEN required. Verified against the
  docs text (lines ~429–430) and the real reusable file (`required: true`).

## 6. No unaccounted behavior — PASS

Full diff of both files read line-by-line. Every hunk traces to a task or
scenario: flag parse + usage (T3/AC-022-03-01), `_gh_release_job` (T3/AC-022-03-02),
regression guard (AC-022-03-03), `_gh_releaserc` D3 coupling (AC-022-03-04/08),
GH_TOKEN prompt (AC-022-03-05), GitLab include + `_gl_release_job`
(AC-022-03-06), summary rows + docs table row (AC-022-03-07), header citation
comments (T4 traceability). The supporting refactors (`_prompt_secrets` split,
`_gl_deploy_job` extraction, `_print_saga_note`/`_print_deploy_note`/
`_print_release_note` helpers, `_wants_npm_token` reorder) are
behavior-preserving — proven by the byte-identical HEAD-vs-new output on the
no-flag paths for github-go, gitlab-go, and node+nextjs. Nothing appears that
isn't accounted for in `10-tasks.md` + `20-acceptance/`.

## Flags for the Architect (WARNs, not pipeline stops)

1. **check-code-principles exit 1 is pre-existing** (5 FAILs in
   `ci/templates/` saga files, unchanged by this branch). The branch's own
   files are clean. Repo debt; consider a follow-up refactor spec.
2. Refactorer's FAIL count was off by one (6 claimed vs 5 actual).
3. `scripts/init-ci.sh` is mode 100644 in git (no exec bit) at HEAD and on this
   branch — docs invoke it as `./.standards/scripts/init-ci.sh`, which fails
   with "Permission denied" on a fresh checkout; invoke as `bash scripts/init-ci.sh`
   (pre-existing, out of this spec's scope).
4. `skills/hallmark/SKILL.md` >500-line WARN (pre-existing, unrelated).
5. Working-tree CRLF in `ci/templates/go-saga-lint.go` (pre-existing checkout
   artifact; committed blob is LF; self-ci CRLF gate checks blobs and is fine).

## Overall verdict

**PASS** — Architect may proceed. All six self-CI gates exit 0 on the real
tree; every Task 3 generation behavior was executed from scratch and matched
the scenarios byte-for-byte; no-flag output is byte-identical to pre-change on
all three platform/stack combinations tested; the 022 scenario IDs all trace;
the diff contains nothing beyond `10-tasks.md` + `20-acceptance/`; and the only
gate that fails (check-code-principles) does so on pre-existing, untouched
files — verified byte-identical to HEAD — with zero FAILs/WARNs on this
branch's changed files.

## Quality gates

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
