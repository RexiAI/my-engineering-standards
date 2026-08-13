# Tasks — React Native CI + full SDLC parity with Java / Go / Node

Formalization of `specs/021-react-native-sdlc/00-informal.md`. The language rules
already exist (`language-specific/react-native/`); this spec ships the missing
CI/CD layer so a React Native child repo can be bootstrapped like a Go or Node
one: a GitHub reusable workflow, a GitLab template, a child drop-in template,
`init-ci.sh` detection + generation, `docs/CI_CD.md` / `docs/TESTING.md`
coverage, and a Stryker config that handles the jest-expo preset.

## Grounded reality (verified, do not re-derive)

- **No RN CI layer exists today.** No `.github/workflows/frontend/ci-react-native.yml`,
  no `ci/gitlab/frontend/ci-react-native.yml`, no `ci/templates/child-ci-react-native.yml`,
  no `react-native` in `scripts/init-ci.sh` (frontend options are
  `nextjs/react/angular/static`), no RN row in `docs/CI_CD.md`, no RN framework
  reference in `docs/TESTING.md`.
- **Analog files to mirror:** `.github/workflows/frontend/ci-nextjs.yml` and
  `ci-react.yml` are byte-identical workflows (`workflow_call`, inputs
  `node-version` default `"22"` + `node-version-file` default `""`, `npm ci`,
  `cache: npm`, jobs `unit-test` / `lint` / `build` / `docker`; the `docker` job
  is gated on `push` + default branch + `deploy-on-main`). `ci/gitlab/frontend/ci-nextjs.yml`
  and `ci-react.yml` define hidden jobs `.node-variables` (NODE_VERSION 22),
  `.node-cache`, `.node-setup`, then `.nextjs-unit`/`.nextjs-lint`/`.nextjs-build`/`.nextjs-docker`
  (no docker job at all in the React case). `ci/templates/child-ci-node.yml` is
  the child drop-in shape. `ci/gitlab/frontend/ci-static.yml` shows the rules-only
  gating pattern.
- **`scripts/init-ci.sh`:** `detect_frontend()` reads `package.json` (checks
  `"next"`, then `"react"`, then `"@angular"`); interactive `select` menu lists
  "Next.js" / "React (Vite)" / "Angular" / "Static HTML" / "None" / "Cancel".
  `generate_github_ci()` writes `.github/workflows/ci.yml` inline via heredoc —
  it never copies `ci/templates/child-ci-*.yml`; those are the documented
  drop-in references. Non-static frontends get a `frontend-ci` job passing
  `docker-registry` in `with:` and `GHCR_TOKEN` in `secrets:`. `generate_gitlab()`
  writes `.gitlab-ci.yml` with `include: local: .standards/ci/gitlab/frontend/ci-${FRONTEND}.yml`
  plus `frontend-unit`/`frontend-lint`/`frontend-build`/`frontend-docker` jobs
  extending `.${FRONTEND}-*` (stage test/lint/deploy/docker). `collect_secrets()`
  prompts per-language placeholders (GHCR_TOKEN, NPM_TOKEN, …); `print_summary`
  lists GitHub secrets.
- **Shared configs already present:** `ci/templates/releaserc.json`,
  `ci/templates/stryker.conf.json` (uses `testRunner: "vitest"` — **not**
  reusable for RN as-is, which needs the Jest runner for the jest-expo preset),
  `ci/templates/pitest-profile.xml`.
- **Self-CI gate** (`.github/workflows/self-ci.yml` `validate` job + `Makefile`):
  CRLF check on committed blobs, `bash -n` on `*.sh`, `make validate-all`
  (`validate`/`validate-docs`/`validate-refs`/`validate-skills`),
  `scripts/check-orchestration.sh`, `scripts/check-skills.sh`, `make lint`
  (YAML parse of everything under `.github` + `ci`, JSON parse of
  `language-specific/javascript/*.json`). A `validate-refs` step scans every
  `*.md` outside `specs/` for `docs/[A-Z_]+.md` references — any new doc text
  must not introduce a broken reference. GitHub Actions errors on a reusable
  workflow being passed an input **or** secret it does not declare, so the
  generated RN `ci.yml` must pass exactly what `ci-react-native.yml` declares.
- **This repo is the standards parent.** It ships the workflows/templates/
  scripts; it does not run an RN child app in its own CI. Every task's
  acceptance is verified here by file presence + parse + the init-ci.sh
  generator behavior against a scratch directory, not by building a real app.

## Tasks

### Task 1 — `.github/workflows/frontend/ci-react-native.yml`: reusable workflow (unit / lint / typecheck / export / gated EAS build)

Mirror `ci-react.yml`'s shape; drop the Docker path because EAS builds remotely.

Acceptance criteria:
- File exists at `.github/workflows/frontend/ci-react-native.yml` and parses as
  YAML (`python3 -c "import yaml; yaml.safe_load(open(path))"` exit 0).
- Declares `on.workflow_call` with `inputs`: `node-version` (string, default
  `"22"`) and `node-version-file` (string, default `""`) — same descriptions as
  `ci-react.yml`. Declares `secrets.EXPO_TOKEN` (`required: false`). Declares
  `permissions: contents: read` only — **no** `packages: write`.
- Declares `concurrency.group` = `${{ github.workflow }}-${{ github.ref }}` with
  `cancel-in-progress: true`.
- Job `unit-test`: `actions/checkout@v4`, `actions/setup-node@v4` resolving
  node-version/node-version-file exactly like `ci-react.yml` and `cache: npm`,
  `npm ci`, then the same test fallback chain as `ci-react.yml`
  (`npm test -- --passWithNoTests 2>/dev/null || npm run test:unit --if-present || npm test`).
- Job `lint`: `npm ci`, `npm run lint --if-present`, `npm run format:check --if-present`.
- Job `typecheck`: `npm ci`, then exactly `npx tsc --noEmit`.
- Job `build` (export): `needs: [unit-test, lint]`, `npm ci`, then exactly
  `npx expo export`.
- Job `eas-build`: `needs: [unit-test, lint, build]`; its `if:` guards on a push
  to the default branch **and** `secrets.EXPO_TOKEN != ''`; it runs
  `npm ci` then a command containing `eas-cli build --non-interactive`. This is
  the only job that needs EXPO_TOKEN.
- The workflow contains **no** `docker` job, **no** `GHCR_TOKEN` secret, and
  **none** of the `docker-registry` / `docker-image-name` / `deploy-on-main`
  inputs that `ci-react.yml` has.

Scenarios: `20-acceptance/AC-021-01-github-workflow.md`

### Task 2 — `ci/gitlab/frontend/ci-react-native.yml`: GitLab template, same job set, no docker

Mirror `ci/gitlab/frontend/ci-react.yml`'s structure. This repo's GitLab
frontend templates define hidden jobs only; the child's `.gitlab-ci.yml` extends
them.

Acceptance criteria:
- File exists at `ci/gitlab/frontend/ci-react-native.yml` and parses as YAML.
- Defines `.node-variables` (NODE_VERSION `"22"`), `.node-cache`
  (key `${CI_COMMIT_REF_SLUG}`, paths `node_modules/`, policy `pull-push`), and
  `.node-setup` (image `node:${NODE_VERSION}`, `tags: [docker]`,
  `before_script: - npm ci`) — matching `ci-react.yml`.
- Defines hidden job `.react-native-unit` extending `[.node-setup, .node-cache]`
  running the npm test fallback chain.
- Defines hidden job `.react-native-lint` extending `[.node-setup, .node-cache]`
  running `npm run lint --if-present` and `npm run format:check --if-present`.
- Defines hidden job `.react-native-typecheck` extending `[.node-setup, .node-cache]`
  running exactly `npx tsc --noEmit`.
- Defines hidden job `.react-native-build` extending `[.node-setup, .node-cache]`
  running exactly `npx expo export`.
- Defines hidden job `.react-native-eas` extending `[.node-setup, .node-cache]`
  with `rules: - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH && $EXPO_TOKEN != null`
  and a script running `npx eas-cli build --non-interactive`.
- Defines **no** `.react-native-docker` hidden job (RN has no Docker step).

Scenarios: `20-acceptance/AC-021-02-gitlab-template.md`

### Task 3 — `ci/templates/child-ci-react-native.yml`: child drop-in template

Mirror `ci/templates/child-ci-node.yml`. This is the documented one-file include
a child repo drops in manually; `init-ci.sh` (Task 4) generates an equivalent
`ci.yml` inline.

Acceptance criteria:
- File exists at `ci/templates/child-ci-react-native.yml` and parses as YAML.
- First comment lines are `# Generated CI for React Native project` and
  `# Template: ci/templates/child-ci-react-native.yml`.
- `on:` triggers mirror `child-ci-node.yml`: `push` (main), `pull_request`
  (main), `workflow_dispatch`.
- The single job `uses:` is
  `RexiAI/my-engineering-standards/.github/workflows/frontend/ci-react-native.yml@main`.
- `with:` sets `node-version: "22"`. `secrets:` sets
  `EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}`.
- Contains no `GHCR_TOKEN`, no `docker-registry`, no `deploy-on-main`
  (mirrors the workflow's declared inputs/secrets so GitHub does not error on an
  undeclared input/secret).

Scenarios: `20-acceptance/AC-021-03-child-template.md`

### Task 4 — `scripts/init-ci.sh`: detect expo/react-native, add to menu, generate RN CI on both platforms, EXPO_TOKEN placeholder

Wire `react-native` into the frontend detection, menu, usage text, GitHub and
GitLab generators, and secrets collection. The `"expo"` check must come before
the existing `"react"` check — an Expo app's `package.json` contains `"react"`,
so the current order would misclassify it as plain React.

Acceptance criteria:
- `bash -n scripts/init-ci.sh` exits 0.
- The usage text's `--frontend` list includes `react-native`.
- `detect_frontend()`: a `package.json` containing `"expo"` resolves
  `FRONTEND=react-native`; a `package.json` containing both `"expo"` and
  `"react"` still resolves `react-native` (the expo/RN check precedes the
  `"react"` check); a `package.json` containing `"react-native"` but no
  `"expo"` resolves `react-native`.
- The interactive frontend `select` menu includes a "React Native (Expo)"
  entry.
- `--frontend react-native` is accepted as a flag (no TTY required).
- GitHub generation (`--platform github --frontend react-native`): the emitted
  `.github/workflows/ci.yml` has a `frontend-ci` job referencing
  `RexiAI/my-engineering-standards/.github/workflows/frontend/ci-react-native.yml@main`
  with `with: node-version: "22"` and `secrets: EXPO_TOKEN: ${{ secrets.EXPO_TOKEN }}` —
  and **no** `GHCR_TOKEN` line and **no** `docker-registry` line anywhere in the
  file.
- GitLab generation (`--platform gitlab --frontend react-native`): the emitted
  `.gitlab-ci.yml` includes
  `local: .standards/ci/gitlab/frontend/ci-react-native.yml` and defines
  `frontend-unit` (extends `.react-native-unit`, stage test),
  `frontend-lint` (extends `.react-native-lint`, stage lint),
  `frontend-typecheck` (extends `.react-native-typecheck`, stage test),
  `frontend-build` (extends `.react-native-build`, stage deploy),
  `frontend-eas` (extends `.react-native-eas`, stage docker) — and **no**
  `frontend-docker` job.
- Non-RN frontends are unchanged: `--frontend nextjs` on GitHub still passes
  `docker-registry` + `GHCR_TOKEN`; on GitLab still emits `frontend-docker`
  extending `.nextjs-docker`.
- `collect_secrets()` prompts for `EXPO_TOKEN` when the frontend is
  `react-native`; `print_summary()` lists EXPO_TOKEN in the GitHub secrets
  section when set. (`grep EXPO_TOKEN scripts/init-ci.sh` matches; the exact
  prompt/wiring is left to the Coder.)
- Both generated files (`.github/workflows/ci.yml`, `.gitlab-ci.yml`) parse as
  YAML when generated for `react-native`.

Scenarios: `20-acceptance/AC-021-04-init-ci.md`

### Task 5 — `docs/CI_CD.md`: React Native language table, divergence notes, architecture tree, secrets row

Add a React Native section under Language Support, the architecture-tree entry,
and the EXPO_TOKEN secrets row.

Acceptance criteria:
- A `### React Native (Expo)` (or equivalent) section exists with a table whose
  rows and commands are, at minimum: `unit-test` →
  `npm test -- --passWithNoTests` (Every push); `lint` →
  `npm run lint && npm run format:check` (Every push); `typecheck` →
  `npx tsc --noEmit` (Every push); `build/export` → `npx expo export` (Every
  push); `eas-build` → `npx eas-cli build --non-interactive` (Merge to main —
  requires EXPO_TOKEN); `eas-submit` → EAS Submit (release path, store
  credentials); `e2e (Maestro)` → `maestro test .maestro/` (Optional /
  scheduled — documented hook).
- The section states the mobile divergences: no Docker image step by default
  (EAS builds remotely); Maestro E2E is emulator-dependent so it is a
  scheduled/optional job, not a per-push gate, and v1 ships a documented hook
  (`.maestro/` flows + `maestro test .maestro/`) rather than a running job.
- The section states EAS jobs run only when `EXPO_TOKEN` is present, so a repo
  without an Expo account still gets green unit/lint/typecheck; the EAS project
  id is committed config in `eas.json`/`app.json`, not a CI secret.
- The Architecture tree's `.github/workflows/frontend/` listing gains a
  `ci-react-native.yml` line labeled React Native (Expo).
- The Required Secrets table gains an `EXPO_TOKEN` row (used by EAS build;
  deploy/main path only).
- No `docs/[A-Z_]+.md` reference in the new text is broken (all referenced docs
  exist).

Scenarios: `20-acceptance/AC-021-05-ci-cd-docs.md`

### Task 6 — `docs/TESTING.md`: reference the RN testing layers (RNTL vs Maestro split)

Stop the root testing doc from claiming "Jest" as if RN were plain Node.

Acceptance criteria:
- The Unit-tests section (JS/TS guidance) references React Native Testing
  Library + jest-expo preset as the RN unit/component runner (distinct from
  plain Jest) and links `language-specific/react-native/TESTING.md`.
- The E2E section references Maestro as the RN E2E tool (YAML flows on a
  simulator/device) with Detox as the upgrade path, and links
  `language-specific/react-native/TESTING.md`.
- The added references do not break `make validate-refs` (the relative link
  target `language-specific/react-native/TESTING.md` exists).

Scenarios: `20-acceptance/AC-021-06-testing-docs.md`

### Task 7 — `ci/templates/stryker.react-native.conf.json`: Stryker config with the Jest runner and jest-expo handled

The existing `ci/templates/stryker.conf.json` pins `testRunner: "vitest"` and
is not reusable for RN (RN tests run through jest with the jest-expo preset), so
a dedicated config is required per the informal spec's "otherwise a dedicated
…conf.json" branch.

Acceptance criteria:
- File exists at `ci/templates/stryker.react-native.conf.json` and parses as
  JSON (`python3 -m json.tool` exit 0).
- `testRunner` is `"jest"` (not `"vitest"`).
- `mutate` patterns include `src/**/*.ts` **and** `src/**/*.tsx`, excluding
  `*.test.ts(x)` / `*.spec.ts(x)` / `*.d.ts`.
- `thresholds` has `low: 80` and `break: 80`.
- The config explicitly handles the jest-expo preset (a `jest` block carrying
  `preset: jest-expo` via `config`/`configFile`, or a comment naming
  `jest-expo` as required — the file must mention `jest-expo`).
- `docs/TESTING.md` Mutation Testing section cites
  `ci/templates/stryker.react-native.conf.json` as the RN Stryker config
  (alongside the existing `ci/templates/stryker.conf.json` note).

Scenarios: `20-acceptance/AC-021-07-stryker-config.md`

### Task 8 — Self-CI gates green

The repo's own CI runs on the PR that ships these files; this task is the
explicit checklist proving the diff passes it.

Acceptance criteria:
- `make lint` exits 0 (all `.github` + `ci` YAML parses, including the three new
  YAML files).
- `make validate-all` exits 0.
- `scripts/check-orchestration.sh` exits 0.
- `scripts/check-skills.sh` exits 0.
- `bash -n scripts/init-ci.sh` exits 0 (already required by Task 4; re-run here
  after all edits).
- None of the new or changed files contains a CRLF byte (`grep -qU $'\r$'`
  on each returns non-zero).
- `git status` shows changes only under the paths this spec touches:
  `.github/workflows/frontend/ci-react-native.yml`, `ci/gitlab/frontend/ci-react-native.yml`,
  `ci/templates/child-ci-react-native.yml`, `ci/templates/stryker.react-native.conf.json`,
  `scripts/init-ci.sh`, `docs/CI_CD.md`, `docs/TESTING.md`, and `specs/021-react-native-sdlc/`.

Scenarios: `20-acceptance/AC-021-08-self-ci-gates.md`

## Acceptance criteria mapping

| Informal AC | Task(s) | Scenario file |
|---|---|---|
| AC-001 GitHub workflow runs unit + lint + typecheck via workflow_call, mirrors ci-nextjs structure | 1 | `AC-021-01-github-workflow.md` |
| AC-002 GitLab template exists with the same job set | 2 | `AC-021-02-gitlab-template.md` |
| AC-003 child template exists; init-ci.sh detects RN/expo and generates a wiring `ci.yml` (GitHub + GitLab) | 3 + 4 | `AC-021-03-child-template.md`, `AC-021-04-init-ci.md` |
| AC-004 CI_CD.md RN table + architecture tree entry; TESTING.md references RNTL/Maestro | 5 + 6 | `AC-021-05-ci-cd-docs.md`, `AC-021-06-testing-docs.md` |
| AC-005 all YAML validates, orchestration refs resolve, no CRLF | 8 | `AC-021-08-self-ci-gates.md` |
| AC-006 EAS jobs gated on EXPO_TOKEN and documented; no-Expo repo stays green on unit/lint/typecheck | 1 + 2 + 5 | `AC-021-01-github-workflow.md`, `AC-021-02-gitlab-template.md`, `AC-021-05-ci-cd-docs.md` |

## Decisions (human-confirmed; all questions resolved — no open questions remain)

1. **`build/export` job = local `npx expo export` — RESOLVED (human: OK).**
   The informal spec lists "build/export (expo export or EAS build)". This spec
   picks `npx expo export` (local, no network/Expo account) for the per-push
   build job, so a repo without EXPO_TOKEN still gets a real bundle check, and
   a separate gated `eas-build` job covers the deploy/main path. Confirmed; no
   change. (`AC-021-01-06`, `AC-021-01-07`, `AC-021-02-05`, `AC-021-02-06`.)
2. **EAS Submit is documented, not a v1 job — RESOLVED (human: OK).**
   The CI_CD.md table lists an `eas-submit` row (release path, store
   credentials), but the workflow ships no `eas-submit` job in v1 — consistent
   with the informal spec's deferral of the `init-deploy.sh` EAS path.
   Confirmed; no change. (`AC-021-05-01` documents the row only; no workflow
   scenario asserts an `eas-submit` job.)
3. **Maestro E2E = documented hook only in v1 — RESOLVED (human: OK).**
   The workflow contains no active Maestro job; `docs/CI_CD.md` documents the
   opt-in hook (`.maestro/` flows + `maestro test .maestro/`). Confirmed; no
   commented-out job block in the workflow itself. (`AC-021-05-02`.)
4. **`child-ci-react-native.yml` is a reference, not copied by init-ci.sh —
   RESOLVED (human: OK).** `init-ci.sh` writes `ci.yml` inline via heredoc and
   never copies `ci/templates/child-ci-*.yml` — that is existing behavior for
   `child-ci-node.yml` too. AC-003's "generates a `.github/workflows/ci.yml`
   that includes it" is therefore interpreted as "wires the
   `frontend/ci-react-native.yml` reusable workflow" (GitHub) and "includes
   `ci/gitlab/frontend/ci-react-native.yml` + extends `.react-native-*`"
   (GitLab). Confirmed; no change. (`AC-021-04-06`, `AC-021-04-07`.)
5. **EAS project id is committed config, not a secret — RESOLVED (human: OK).**
   Only `EXPO_TOKEN` becomes a CI secret placeholder. The EAS project id lives
   in `eas.json` / `app.json` in the child repo and is documented as such in
   CI_CD.md. Confirmed; no change. (`AC-021-05-03`.)
6. **`typecheck` command is exactly `npx tsc --noEmit` — RESOLVED (human: OK).**
   No `--if-present` fallback. Deterministic and works in any Expo TypeScript
   project; a child with a custom `typecheck` script still satisfies it via the
   same tsc binary. Confirmed; no change. (`AC-021-01-05`, `AC-021-02-04`.)
7. **Generated GitHub `ci.yml` for RN passes `node-version: "22"` in `with:` —
   RESOLVED (human: OK).** Unlike the other generated frontend jobs (which pass
   only `docker-registry`), the RN job carries an explicit, declared input.
   Confirmed; no change. (`AC-021-04-06`.)
