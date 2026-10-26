# 10-tasks.md — Bootstrap capability catalog

Turn the one-off bootstrap sequence into a single catalog-driven tool. One
capability table is the source of truth; an interactive menu, a full
`--list`, and `--all` all render from it; every capability gets a
non-interactive flag; detection covers the full stack matrix; and
`init-ci.sh` accepts the two missing backends and the missing frontend.

Scope is `scripts/bootstrap.sh` and `scripts/init-ci.sh` plus one new
catalog source and new bats fixtures under `scripts/tests/`. No change to the
gate catalog (gate names and the count of 6 are untouched), so no ADR is
required. Regression gates: `scripts/check-orchestration.sh`,
`scripts/check-skills.sh`, `scripts/check-gate-consistency.sh`, and
`make test-scripts`.

The Coder reads only this file and `20-acceptance/`; the asset inventory in
task 1 is the verified list of what this repo ships today, so the catalog can
be built without consulting `00-informal.md`.

---

## Task 1 — Capability catalog (single source of truth)

Create one catalog — a data file or a sourced bash module — as the only place
any capability is defined. Columns per entry: `id`, `label`, `category`,
`files written` (list), `required stack` (backend / frontend / CI platform /
empty), `conflicts` (list of incompatible capability ids, may be empty).

`--list` prints it; the menu renders from it; `--all` iterates it. No second
hardcoded list may exist in `bootstrap.sh`.

Acceptance criteria:

- A single catalog source exists and is the only place a capability is named.
  Grep of `bootstrap.sh` for any capability label or flag not derived from the
  catalog yields nothing (no `case`/array enumerating capabilities inline).
- `--list` prints every entry as `id<TAB>label<TAB>category`, one per line,
  non-interactively (works with stdin not a TTY), exit 0.
- `--list` output is generated from the catalog — a bats test renders the
  catalog and diffs it against `--list` byte-for-byte.
- Every entry carries a non-empty `id`, `label`, `category`, and `files
  written`; `required stack` is one of `backend`, `frontend`, `ci`, `none`;
  `conflicts` is present (empty list allowed).
- The catalog enumerates at least the verified shipped capabilities and their
  assets:

  - **Core wiring** (`--none` baseline): AGENTS.md pointer, opencode.json,
    okf reference, `.opencode/{agents,commands,skills}` symlink, `.envrc`,
    `config/.gitignore`, `.gitattributes`, PR template, session hygiene
    scripts, git hook.
  - **Backend** — java (`pom.xml`): checkstyle/spotbugs/pmd configs,
    `.gitignore.java`, `ci-java.yml`, gitlab `ci-java.yml`, saga templates,
    `pitest-profile.xml`. go (`*.go`): `.golangci.yml`, `Makefile.go`,
    `.gitignore.go`, `ci-go.yml`, gitlab `ci-go.yml`, `go-saga-lint.go`.
    node (`package.json`): eslint/prettier configs, `.gitignore.node`,
    `ci-node.yml`, gitlab `ci-node.yml`, `eslint-saga-rules`.
    python (`pyproject.toml`/`requirements.txt`): guide, `child-ci-python.yml`,
    `pact-python.yml`, `mutmut-pyproject.toml`. rust (`Cargo.toml`): guide,
    `child-ci-rust.yml`, `pact-rust.yml`, `mutants.toml`, `mutation.mk`.
  - **Frontend/mobile** — nextjs (`ci-nextjs.yml`), react (`ci-react.yml`),
    angular (`ci-angular.yml`), ionic (guide only — see OQ-6),
    react-native (`ci-react-native.yml`, `stryker.react-native.conf.json`),
    static (`ci-static.yml`).
  - **Quality gates** — saga (init-ci `--with-saga`), contract
    (`ci-contract.yml` + `pact-{java,go,node,python,rust}.yml`), mutation
    (`pitest-profile.xml`, `stryker.conf.json`,
    `stryker.react-native.conf.json`, `mutmut-pyproject.toml`, `mutants.toml`),
    security (`ci-security.yml`), e2e (`ci-e2e.yml`, `ci-e2e-weekly.yml`),
    sweeper (`ci-sweeper.yml`).
  - **Deploy** — kamal/dokku/ssh (`ci-deploy-*.yml`,
    `child-ci-deploy-*.yml`), vercel (`ci-vercel-production-verify.yml`).
  - **Agent pipeline** — spec pipeline (`agents/`, `commands/`), PR review
    (`ci-pr-review.yml`), deploy verifier (`agents/spec-deployer.md`).
  - **Loop engineering** — `LOOP.md`, `STATE.md`, `gate.yaml`,
    `loop-budget.md`, `loop-constraints.md`, `loop-run-log.md`.
  - **Media agents** — informational only (see OQ-2).

Verified by scenarios: AC-033-01, AC-033-02, AC-033-03, AC-033-04.

---

## Task 2 — Detection across the full matrix

Extend `bootstrap.sh` detection beyond java/go/node to the full matrix, with
each result printed alongside its evidence file. Backend and frontend are
distinct axes: a `package.json` repo is a `node` backend *and* may carry a
frontend marker.

Acceptance criteria:

- Backend detection: `pom.xml`→java, `*.go`→go, `package.json`→node,
  `pyproject.toml`→python, `requirements.txt` (no pyproject)→python,
  `Cargo.toml`→rust.
- Frontend detection reads `package.json` markers with the specific-marker
  precedence already used by `init-ci.sh` (`_detect_frontend_pkg`), extended
  with Ionic: `expo`/`react-native` before `next` before `@ionic/*` before
  `react` before `@angular/core`. Ionic wins over Angular; React Native wins
  over React; Next.js wins over React.
- A frontend repo routes to `--frontend`, never `--backend node` for the
  frontend half. A repo with both a backend and a frontend reports both.
- Detection output prints the stack and the exact evidence file that produced
  it (e.g. `[PYTHON] detected via pyproject.toml`).
- No framework marker detected → frontend is `none`; `static` is available as
  an explicit selection, not auto-detected (see OQ-10).

Verified by scenarios: AC-033-05 through AC-033-17.

---

## Task 3 — Interactive multi-select menu + non-TTY default

On a TTY with no flags, render a grouped multi-select menu from the catalog.
Grouping: Core wiring, Backend stacks, Frontend/mobile stacks, CI platform,
Quality gates, Deploy, Agent pipeline, Loop engineering. Preselect what
detection found. On a non-TTY with no flags, preserve today's core-wiring
behavior.

Acceptance criteria:

- Menu item list and grouping are generated from the catalog (task 1) — no
  capability is named in the menu code.
- Detected stacks come preselected; unselected-but-available capabilities are
  listed but not selected.
- A menu selection set maps to exactly the same flag set as passing those
  capabilities non-interactively (menu and flags share the same selection
  model).
- Non-TTY, no flags: performs core wiring only, skips CI setup, and prints the
  exact command to opt into the rest (e.g. `--all` or the specific flags).
- TTY, no flags: shows the full menu preselected by detection (`--none` is the
  explicit escape) — per OQ-1 recommendation.

Verified by scenarios: AC-033-18, AC-033-19, AC-033-20, AC-033-21, AC-033-22.

---

## Task 4 — Per-capability flags, `--all`/`--none`, refusal, outcomes

Every capability gets a non-interactive flag; `--all` and `--none` are the
bulk toggles; incompatible combinations are refused with a named reason; every
capability execution reports an explicit outcome.

Acceptance criteria:

- Flags exist: `--stack java|go|node|python|rust`,
  `--frontend nextjs|react|angular|ionic|react-native|static`, `--with-saga`,
  `--with-contract`, `--with-mutation`, `--with-security`, `--with-e2e`,
  `--with-sweeper`, `--with-pr-review`, `--with-release`,
  `--with-deploy kamal|dokku|ssh|vercel`, `--with-spec-pipeline`,
  `--with-loop`, `--copy-agents`, `--all`, `--none`, `--dry-run`, `--help`,
  `--list`.
- `--none` performs core wiring only (no CI, no stack config, no extra
  templates).
- `--all` enables every catalog entry whose `required stack` is compatible with
  the detected/selected stacks; incompatible entries are skipped, never
  silently dropped — the reason is printed.
- `--all` excludes deploy unless a tool is named; with `--with-deploy <tool>`
  deploy is included.
- An incompatible combination (derived from the catalog `conflicts` field) is
  refused with a named reason and a non-zero exit.
- Every capability reports exactly one of `CREATED`, `SKIPPED (exists)`, or
  `REFUSED (reason)`; a re-run writes nothing twice.

Verified by scenarios: AC-033-23 through AC-033-30.

---

## Task 5 — Extend `init-ci.sh`: `--backend python|rust`, `--frontend ionic`

`init-ci.sh` accepts `python` and `rust` for `--backend` and `ionic` for
`--frontend`, and its usage line and error text are updated together.

Acceptance criteria:

- `--backend python` and `--backend rust` are accepted (no unknown-flag
  error); the usage line lists `java,go,node,python,rust`.
- `--frontend ionic` is accepted; the usage line lists
  `nextjs,react,angular,ionic,react-native,static`.
- The invalid-flag error path prints the updated usage line.
- Emitting for `--backend python`/`--backend rust` produces a CI reference for
  the python/rust workflow; `--frontend ionic` produces an Ionic workflow
  reference. **Blocked on OQ-5 / OQ-6**: `ci-python.yml`, `ci-rust.yml`, and
  `ci-ionic.yml` reusable workflows do not exist today (see open questions).

Verified by scenarios: AC-033-31 through AC-033-34.

---

## Task 6 — Deploy: `--with-deploy kamal|dokku|ssh|vercel`

`bootstrap.sh` gains `--with-deploy <tool>` with the four tools, mapping VPS
tools to `init-ci.sh --deploy-tool` and the Vercel lane to the shipped
production-verify workflow.

Acceptance criteria:

- `--with-deploy kamal`, `dokku`, or `ssh` forwards to
  `init-ci.sh --deploy-tool <tool>` (existing init-ci behavior preserved).
- `--with-deploy vercel` is accepted and wires the Vercel production-verify
  lane (`ci-vercel-production-verify.yml`); its exact emission is specified by
  OQ-9.
- `--with-deploy` with a missing or unknown tool is refused with a named
  reason and non-zero exit.

Verified by scenarios: AC-033-35, AC-033-36, AC-033-37.

---

## Task 7 — Agent pipeline: spec pipeline, PR review, deploy verifier

The agent-pipeline group is reachable non-interactively.

Acceptance criteria:

- `--with-pr-review` forwards to `init-ci.sh --with-pr-review` (existing).
- `--copy-agents` preserves its current behavior: copies `agents/`,
  `commands/`, and `skills/` as real directories instead of symlinks.
- `--with-spec-pipeline` wires the spec pipeline agents; its exact
  relationship to `--copy-agents` is specified by OQ-7.

Verified by scenarios: AC-033-38, AC-033-39, AC-033-40.

---

## Task 8 — Loop engineering: `--with-loop`

`--with-loop` writes the loop state files the loop-foundation gate expects.

Acceptance criteria:

- `--with-loop` writes, into the child repo, the files
  `scripts/check-loop-files.sh` validates: `LOOP.md`, `STATE.md`,
  `loop-run-log.md`, `loop-budget.md`, `loop-constraints.md`, `gate.yaml`
  (from `templates/`).
- A re-run is a no-op (existing files report `SKIPPED (exists)`).

Verified by scenarios: AC-033-41, AC-033-42.

---

## Task 9 — `--dry-run` and `--help`

`--dry-run` writes nothing and prints the exact plan; `--help` lists the
flags.

Acceptance criteria:

- `--dry-run` creates zero files (file count unchanged before/after) and exits
  0.
- `--dry-run` prints, per selected capability, its id, the files it would
  write, and the flags it would pass to `init-ci.sh`.
- `--help` lists every flag from the catalog/flag set and exits 0.

Verified by scenarios: AC-033-43, AC-033-44, AC-033-45.

---

## Task 10 — Bats fixtures and regression gates

Bats fixtures under `scripts/tests/` prove the behaviors above; the existing
regression gates stay green.

Acceptance criteria:

- New bats fixtures live in `scripts/tests/` and `make test-scripts` exits 0.
- `scripts/check-orchestration.sh` exits 0 (the new catalog/script references
  resolve).
- `scripts/check-skills.sh` and `scripts/check-gate-consistency.sh` exit 0.
- No regression: non-TTY core-wiring output writes the same files as today,
  and `init-ci.sh`'s existing flags (`--platform`, `--backend`, `--frontend`,
  `--with-saga`, `--with-deploy`, `--with-release`, `--with-pr-review`,
  `--deploy-tool`, `--registry`) are unchanged in behavior.

Verified by scenarios: AC-033-46 through AC-033-49.

---

## Open questions (resolve before `/build`)

OQ-1 through OQ-4 are carried from `00-informal.md`; OQ-5 through OQ-10 were
found while verifying the repo against the ask. Each carries a recommendation;
the human gate must confirm or redirect before the Coder runs.

- **OQ-1** — TTY with no flags: full menu (recommended) or a core-only
  confirm? Recommendation: full menu preselected by detection; `--none` is the
  escape. → task 3.
- **OQ-2** — Does `--all` include media agents? Recommendation: no — they need
  external provider credentials; list them informational-only. → task 1.
- **OQ-3** — Does `--all` include the Vercel lane? Recommendation: only with
  explicit `--with-deploy vercel`. → task 6.
- **OQ-4** — Should `--with-loop` write loop files into the child repo or only
  point at templates? Recommendation: write them — `check-loop-files.sh`
  expects real files. → task 8.
- **OQ-5 (blocker)** — `ci-python.yml` and `ci-rust.yml` reusable GitHub
  workflows, and their GitLab `ci/gitlab/backend/ci-python.yml` /
  `ci-rust.yml` counterparts, do **not** exist. Only
  `ci/templates/child-ci-python.yml` and `child-ci-rust.yml` ship.
  Requirement 7's "map to the existing ci-python, ci-rust workflows" rests on a
  false premise. Does `--backend python|rust` require creating those reusable
  workflows first, or is detection + child-template copy sufficient? → task 5.
- **OQ-6 (blocker)** — Ionic has no `ci-ionic.yml` or
  `ci/gitlab/frontend/ci-ionic.yml`. Requirement 7 says "Ionic/Angular
  workflows". Recommendation: map Ionic to the existing Angular workflow;
  confirm whether a dedicated Ionic workflow is wanted. → task 5.
- **OQ-7** — `--with-spec-pipeline` vs `--copy-agents`: is `--with-spec-pipeline`
  the enable-flag and `--copy-agents` the copy-vs-symlink modifier, or are they
  aliases? The spec pipeline is already always wired (symlink by default). →
  task 7.
- **OQ-8 (scope)** — `--with-contract`, `--with-mutation`, `--with-security`,
  `--with-e2e`, `--with-sweeper` correspond to reusable workflows
  `init-ci.sh` does **not** emit today (only saga/deploy/release/pr-review are
  wired). Do these flags extend `init-ci.sh` to emit the corresponding jobs, or
  does `bootstrap.sh` copy the templates only? → task 4.
- **OQ-9** — `--with-deploy vercel` emission: `ci-vercel-production-verify.yml`
  is a post-merge production-verification lane, not a VPS deploy job like
  `ci-deploy-*`. What exactly does selecting "vercel" emit into the child's
  CI? → task 6.
- **OQ-10** — `static` has no auto-detectable marker. Recommendation: `static`
  is an explicit selection (`--frontend static`); no marker auto-detects to
  frontend `none`. Confirm. → task 2.
