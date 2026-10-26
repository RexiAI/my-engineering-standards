# 033-bootstrap-capability-catalog

> Spec pipeline archive. Original source: `specs/033-bootstrap-capability-catalog/` (deleted by this script).
> Archived: 2026-10-26

## Original ask

# Informal spec: bootstrap capability catalog

## The ask

"In the script bootstrap, you should offer all functionalities that have been
added for the backend, frontend, etc. — web, back, apps, all!"

## Current state (verified, not assumed)

`scripts/bootstrap.sh` is 356 lines. It hard-wires a fixed sequence and detects
three stacks.

**Detection today** — Java (`pom.xml`), Go (`*.go`), Node (`package.json`). It
then calls `init-ci.sh --backend "$LANG_DETECTED"`. A React app is detected as
`node` and wired as a **backend**; `--frontend` is never passed. Python and Rust
have guides (`language-specific/python`, `language-specific/rust`) and
**self-contained child templates** (`ci/templates/child-ci-python.yml`,
`child-ci-rust.yml`) — but no reusable `ci-python.yml` / `ci-rust.yml` exists,
and bootstrap does not detect or offer either. Angular, Ionic, and React Native
have guides and reusable workflows, but bootstrap cannot select them.

**Capabilities `init-ci.sh` already accepts but bootstrap never offers:**
`--with-saga`, `--with-deploy` (+ `--deploy-tool kamal|dokku|ssh`),
`--with-release`, `--with-pr-review`, `--frontend`, `--platform both`.
Its `--backend` accepts only `java,go,node`; `--frontend` accepts
`nextjs,react,angular,react-native,static` (no Ionic).

**Shipped by this repo, wired by neither script:** reusable workflows
`ci-e2e.yml`, `ci-e2e-weekly.yml`, `ci-contract.yml`, `ci-security.yml`,
`ci-sweeper.yml`, `ci-toolchain-bump.yml`, `ci-vercel-production-verify.yml`;
mutation configs (pitest, stryker, stryker-react-native, mutmut, mutants.toml);
Pact templates for five languages; TDD feature scaffolds (java/go/js); loop
engineering files (`LOOP.md`, `loop-budget.md`, `loop-constraints.md`,
`loop-run-log.md`); `templates/SKILL.md`, `agent.md`, `gate.yaml`, `STATE.md`;
`branch-protection.md`; Docker templates; the spec pipeline (only reachable via
the non-interactive `--copy-agents` flag).

**Missing:** `--help`, `--list`, `--dry-run`, and any non-interactive way to
choose capabilities other than `--copy-agents`. The only prompt is the CI
platform select.

## Required behavior

1. **One capability catalog.** A single table — id, label, category, files
   written, required stack, conflicts — is the only source of truth. `--list`
   prints it; the menu renders from it; `--all` iterates it. No second list that
   can drift.
2. **Interactive menu on a TTY.** Multi-select, grouped: Core wiring, Backend
   stacks, Frontend/mobile stacks, CI platform, Quality gates (saga/outbox,
   contract, mutation, security, e2e, sweeper), Deploy (VPS tool or Vercel lane),
   Agent pipeline (spec pipeline, PR review, deploy verifier), Loop engineering.
   Preselect what detection found.
3. **Every capability has a non-interactive flag.** `--stack
   java|go|node|python|rust`, `--frontend
   nextjs|react|angular|ionic|react-native|static`, `--with-saga`,
   `--with-contract`, `--with-mutation`, `--with-security`, `--with-e2e`,
   `--with-sweeper`, `--with-pr-review`, `--with-release`, `--with-deploy
   kamal|dokku|ssh|vercel`, `--with-spec-pipeline`, `--with-loop`,
   `--copy-agents`, `--all`, `--none`, `--dry-run`, `--help`, `--list`.
4. **`--all` and `--none`.** `--all` enables every catalog entry compatible with
   the detected/selected stacks. `--none` is core wiring only. Incompatible
   combinations are **refused with a named reason**, never silently dropped.
   Deploy is excluded from `--all` unless a tool is named, because it needs a
   host or a linked project.
5. **Detection covers the full matrix.** Python (`pyproject.toml` /
   `requirements.txt`), Rust (`Cargo.toml`), Angular (`@angular/core`), Ionic
   (`@ionic/*`), React Native, Next.js, React, static. Detection result is
   printed with the evidence file it came from.
6. **Correct stack routing.** A frontend project passes `--frontend`, not
   `--backend node`. A repo with both passes both.
7. **`init-ci.sh` extended** so `--backend` accepts `python` and `rust` (copying
   the self-contained `child-ci-python.yml` / `child-ci-rust.yml`; creating
   reusable workflows is out of scope) and `--frontend` accepts `ionic` as an
   alias that emits the existing Angular wiring. Usage line and error text
   updated together.
8. **Idempotent, explicit outcomes.** Every capability reports `CREATED`,
   `SKIPPED (exists)`, or `REFUSED (reason)`. Re-running writes nothing twice.
9. **`--dry-run` writes nothing** and prints the exact plan (capability, files,
   flags it would pass to `init-ci.sh`), exit 0. `--help` lists flags; `--list`
   lists capabilities.
10. **Non-TTY without flags preserves today's behavior** (core wiring, CI
    skipped) and prints the exact command to opt into the rest.
11. **Tests.** Bats fixtures prove: every catalog entry maps to a real flag;
    `--list` output equals the catalog; `--dry-run` creates zero files;
    detection works for all eight stacks; incompatible pairs are refused;
    `--all` skips deploy without a tool; a re-run is a no-op. No regression in
    the current bootstrap output or in `init-ci.sh`'s existing flags.

## Out of scope

- Creating GitHub/GitLab repositories, Vercel projects, or hosts.
- Prompting for or writing secrets.
- Rewriting the standards documents; this is wiring, not new standards.
- Changing the spec pipeline's stages.

## Open questions

Resolved by the owner's delegate on 2026-10-25. Override any at the human gate.

- OQ-1 — **Full menu preselected by detection.** `--none` is the escape.
- OQ-2 — **No media agents in `--all`.** Credentials-gated; informational only.
- OQ-3 — **Vercel only with explicit `--with-deploy vercel`.**
- OQ-4 — **`--with-loop` writes real files** (`LOOP.md`, `loop-budget.md`,
  `loop-constraints.md`, `loop-run-log.md`); `check-loop-files.sh` reads them.
- OQ-5 — **No new reusable workflows.** `--backend python|rust` copies the
  self-contained `ci/templates/child-ci-python.yml` / `child-ci-rust.yml`.
  ADR 0006 D4 scoped those to templates; the template header already records the
  collapse-to-delegator path. Creating `ci-python.yml` / `ci-rust.yml` is a
  separate spec.
- OQ-6 — **Ionic is an alias for Angular wiring.** No `ci-ionic.yml`; Ionic is
  only supported on Angular (see `language-specific/ionic/SKILL.md`), so a
  dedicated workflow would duplicate `ci-angular.yml`.
- OQ-7 — **Not aliases.** `--with-spec-pipeline` enables the agent wiring
  (default symlink); `--copy-agents` is the copy-vs-symlink modifier.
- OQ-8 — **Extend `init-ci.sh`.** Contract/e2e/security/sweeper flags emit
  callers of the existing reusable workflows. Mutation copies config only
  (pitest/stryker/mutmut/mutants.toml); there is no reusable mutation workflow.
- OQ-9 — **`--with-deploy vercel` adds the post-merge verification caller
  only.** It emits a caller for `ci-vercel-production-verify.yml` and prints
  that the project must be linked in the Vercel dashboard. It never claims to
  build or deploy.
- OQ-10 — **`static` is explicit only.** No marker auto-detects to it.

## Tasks

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

## Acceptance scenarios

## AC-033-01 — `--list` prints every catalog entry
## AC-033-02 — `--list` output is generated from the catalog
## AC-033-03 — menu and `--all` consume the same catalog
## AC-033-04 — every catalog entry carries complete fields
## AC-033-05 — java detected via pom.xml
## AC-033-06 — go detected via a .go file
## AC-033-07 — node backend detected via package.json
## AC-033-08 — python detected via pyproject.toml
## AC-033-09 — python detected via requirements.txt
## AC-033-10 — rust detected via Cargo.toml
## AC-033-11 — angular detected via @angular/core
## AC-033-12 — ionic detected via @ionic/*
## AC-033-13 — react-native detected via expo or react-native
## AC-033-14 — nextjs detected via next
## AC-033-15 — react detected via react
## AC-033-16 — no framework marker yields frontend none
## AC-033-17 — specific frontend markers win over react
## AC-033-18 — menu renders the catalog grouped
## AC-033-19 — menu preselects detected stacks
## AC-033-20 — menu selections map to the same flag set
## AC-033-21 — non-TTY with no flags preserves core wiring
## AC-033-22 — TTY with no flags shows the full menu
## AC-033-23 — every capability has a non-interactive flag
## AC-033-24 — `--none` performs core wiring only
## AC-033-25 — `--all` enables only compatible entries
## AC-033-26 — `--all` excludes deploy without a tool
## AC-033-27 — `--all` includes deploy when a tool is named
## AC-033-28 — incompatible combination is refused with a named reason
## AC-033-29 — every capability reports an explicit outcome
## AC-033-30 — a re-run writes nothing twice
## AC-033-31 — usage and error text updated together
## AC-033-32 — `--backend python` is accepted
## AC-033-33 — `--backend rust` is accepted
## AC-033-34 — `--frontend ionic` is accepted
## AC-033-35 — VPS tools forward to init-ci --deploy-tool
## AC-033-36 — `--with-deploy vercel` wires the Vercel lane
## AC-033-37 — missing or unknown deploy tool is refused
## AC-033-38 — `--with-pr-review` forwards to init-ci
## AC-033-39 — `--copy-agents` copies as real directories
## AC-033-40 — `--with-spec-pipeline` wires the spec pipeline agents
## AC-033-41 — `--with-loop` writes the loop files the gate validates
## AC-033-42 — `--with-loop` re-run is a no-op
## AC-033-43 — `--dry-run` writes nothing
## AC-033-44 — `--dry-run` prints the exact plan
## AC-033-45 — `--help` lists every flag
## AC-033-46 — bats fixtures run green
## AC-033-47 — orchestration references resolve
## AC-033-48 — skills and gate-consistency gates stay green
## AC-033-49 — no regression in default output or init-ci flags

## Verification

# 25-verification.md — Verifier re-check (spec 033)

Attempt 1, phase 1 (pre-PR). Base ref: `main` (6eb2c99). Branch:
`spec/033-bootstrap-capability-catalog` (dirty working tree — expected at stage 4;
the Coder/Refactorer never commit, only the PR Opener does).

Every Coder and Refactorer claim re-executed independently. Verdict below is
transcribed from the gate scripts' exit codes and output, never from the diff.

---

## Check 1 — Scenario traceability

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-26T00:04:48Z

{
  "checks": [1, 2],
  "passes": ["AC-033-01 — traced to a test", "AC-033-02 — traced to a test", "AC-033-03 — traced to a test", "AC-033-04 — traced to a test", "AC-033-05 — traced to a test", "AC-033-06 — traced to a test", "AC-033-07 — traced to a test", "AC-033-08 — traced to a test", "AC-033-09 — traced to a test", "AC-033-10 — traced to a test", "AC-033-11 — traced to a test", "AC-033-12 — traced to a test", "AC-033-13 — traced to a test", "AC-033-14 — traced to a test", "AC-033-15 — traced to a test", "AC-033-16 — traced to a test", "AC-033-17 — traced to a test", "AC-033-18 — traced to a test", "AC-033-19 — traced to a test", "AC-033-20 — traced to a test", "AC-033-21 — traced to a test", "AC-033-22 — traced to a test", "AC-033-23 — traced to a test", "AC-033-24 — traced to a test", "AC-033-25 — traced to a test", "AC-033-26 — traced to a test", "AC-033-27 — traced to a test", "AC-033-28 — traced to a test", "AC-033-29 — traced to a test", "AC-033-30 — traced to a test", "AC-033-31 — traced to a test", "AC-033-32 — traced to a test", "AC-033-33 — traced to a test", "AC-033-34 — traced to a test", "AC-033-35 — traced to a test", "AC-033-36 — traced to a test", "AC-033-37 — traced to a test", "AC-033-38 — traced to a test", "AC-033-39 — traced to a test", "AC-033-40 — traced to a test", "AC-033-41 — traced to a test", "AC-033-42 — traced to a test", "AC-033-43 — traced to a test", "AC-033-44 — traced to a test", "AC-033-45 — traced to a test", "AC-033-46 — traced to a test", "AC-033-47 — traced to a test", "AC-033-48 — traced to a test", "AC-033-49 — traced to a test"],
  "fails": []
}

Result: **PASS**. All 49 scenarios traced to a test; no dangling test references.

---

## Check 2 — Full test suite (run twice, per flake re-check)

`make test-scripts` runs `scripts/check-bats-assertions.sh` then `bats --tap
scripts/tests/*.bats`. The Refactorer reported two transient failures
(AC-030-01-06 and one unnamed); re-ran the suite twice. Both runs clean — the
flake did not reproduce.

### Supplementary: full test suite run 1 of 2

command: make test-scripts
exit: 0
at: 2026-10-26T00:00:03Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..535
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
... (535 `ok` lines total, 0 `not ok`) ...
ok 535 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Summary: 535 `ok`, 0 `not ok`.

## Evidence: full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T00:03:46Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..535
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
... (535 `ok` lines total, 0 `not ok`) ...
ok 535 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Summary: 535 `ok`, 0 `not ok`.

Result: **PASS**. Exit 0 on both runs; 535 tests green; the reported transient
failures did not reproduce. No flakiness observed across two runs.

---

## Check 3 — Complexity gate

The changed files are all bash (`.sh`), one `.tsv`, `.bats`, and `.yml`. No
golangci-lint / pmd / eslint applies to bash; `shellcheck` is not installed in
this environment. The repo's authoritative cyclomatic-complexity enforcement is
`check-code-principles.sh` (its `complexity` gate), which only analyzes
Java/Go/JS-TS/Python/Rust — bash is outside its CC analyzer. Scoped to the diff
against `main`, no scanned-language file changed, so the gate finds nothing in
the change; the full-tree gate still carries the pre-existing out-of-scope
`skills/hallmark` CC=10 FAIL (see Check 3.5).

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T00:05:03Z

{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}

Result: **PASS** (scoped). The bash refactor cannot be CC-measured by this
gate (bash is outside the analyzer); the Refactorer's structural split of
`bootstrap.sh` into five sourced modules (`bootstrap-catalog-lib.sh`,
`bootstrap-detect-lib.sh`, `bootstrap-lib.sh`, `bootstrap-plan-lib.sh`,
`bootstrap-actions.sh`) is the complexity-reduction claim, and it is
behavior-preserving per Check 2 (full suite green) and Check 4.

---

## Check 3.5 — Design-principles gate (KISS/DRY/YAGNI/SOLID + CC + property tests)

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef main --json
exit: 0
at: 2026-10-26T00:04:51Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}

### Supplementary: design-principles gate (full tree)

command: scripts/check-code-principles.sh --json
exit: 1
at: 2026-10-26T00:04:52Z

{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [{ "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }],
  "warns": [
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28", "file": "./ci/templates/go-saga-lint.go", "line": "45" },
    { "message": "Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25", "file": "./ci/templates/go-saga-lint.go", "line": "101" },
    { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::KISS_LINES=41", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" },
    { "message": "Method body >20 lines (node): ./skills/hallmark/site/examples/cobalt-01/script.js:93:225::KISS_LINES=43", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "93" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): type: \"problem\", /docs: { /description: /meta: {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "115" },
    { "message": "Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): schema: [], /}, /create(context) { /},", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "132" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:133): }, /create(context) { /return { /schema: [],", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "133" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:135): return { /CallExpression(node) { /if (!isSagaStepCall(node)) return; /create(context) {", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "135" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:122): public boolean test(JavaClass javaClass) { /String name = javaClass.getSimpleName(); /return BROKER_SUFFIXES.stream().anyMatch(name::endsWith); /@Override", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "122" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:242): node, /messageId: \"directBrokerCall\", /data: { name }, /context.report({", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "242" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:243): messageId: \"directBrokerCall\", /data: { name }, /}); /node,", "file": "./ci/templates/eslint-saga-rules/saga-compensation.js", "line": "243" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/archunit/OutboxArchRules.java:4): import com.tngtech.archunit.lang.ArchRule; /import com.tngtech.archunit.lang.ConditionEvents; /import com.tngtech.archunit.lang.SimpleConditionEvent; /import com.tngtech.archunit.lang.ArchCondition;", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "4" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:182): for _, file := range pkg.Files { /for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /violations := 0", "file": "./ci/templates/go-saga-lint.go", "line": "182" },
    { "message": "Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:105): for _, decl := range file.Decls { /fn, ok := decl.(*ast.FuncDecl) /if !ok { /for _, file := range pkg.Files {", "file": "./ci/templates/go-saga-lint.go", "line": "105" },
    { "message": "Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30", "file": "./ci/templates/archunit/OutboxArchRules.java", "line": "30" },
    { "message": "Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33", "file": "./ci/templates/archunit/SagaArchRules.java", "line": "33" }
  ]
}

Result: **PASS** (scoped to the change). The full-tree run's single FAIL
(`skills/hallmark/site/examples/cobalt-01/script.js` CC=10) and all WARNs are
pre-existing, outside this spec's change set, and out of scope per instructions.
The scoped run against `main` carries zero FAILs and zero WARNs.

---

## Check 4 — Scenario-to-behavior spot check

Manually confirmed four scenarios' tests assert what their Given/When/Then
state (not merely that an ID exists and passes). Three match; one does not.

### PASS — AC-033-01 (`--list` prints every entry as id<TAB>label<TAB>category)

Ran `bootstrap.sh --list` from a hermetic child fixture (`.standards/` symlinked
per the bats fixture model). Output: 35 lines, every line exactly three
tab-separated fields (`id<TAB>label<TAB>category`), line count equal to the
catalog's 35 non-comment/blank rows, exit 0. First line:
`core-agents-md<TAB>AGENTS.md standards pointer<TAB>Core wiring`.
Matches the scenario.

### PASS — AC-033-44 (`--dry-run` prints the exact plan) and AC-033-45 (`--help` lists every flag)

`bootstrap.sh --dry-run --stack java --with-saga` (exit 0) prints the plan with
each selected capability id, its files, and the `init-ci.sh flags:` summary
(`--backend java --platform github --with-saga`). `bootstrap.sh --help` (exit 0)
lists every flag (`--stack`, `--frontend`, `--with-saga`, `--with-loop`,
`--with-deploy`, `--all`, `--none`, `--dry-run`, `--help`, `--list`, …).
Matches the scenarios.

### FAIL — AC-033-41 (`--with-loop` writes the loop files the gate validates)

The scenario's final requirement is: **"And `scripts/check-loop-files.sh` passes
against that repo"** (i.e. exit 0). The shipped test (`AC-033-41` in
`scripts/tests/bootstrap-capability-catalog.bats`) does **not** assert that the
gate exits 0. It runs the gate and then greps for exactly 6 `AC-016-02:
templates/` PASS lines, explicitly ignoring the gate's other checks with a
comment that they "assert standards-repo artifacts … which a child does not
carry."

Empirically, `check-loop-files.sh` does **not** pass against a child repo.
Replicating the fixture (child repo with `.standards/` symlinks, then
`bootstrap.sh --with-loop`), the gate exits 1 with 5 violations:

command: bash scripts/check-loop-files.sh <child-fixture-repo>
exit: 1
at: 2026-10-26T00:04:15Z

Checking loop-engineering foundation bundle in: /tmp/tmp.0XVokIymSm/child

FAIL AC-016-01: docs/LOOP_ENGINEERING.md is missing or empty
PASS AC-016-02: templates/LOOP.md present and non-empty
PASS AC-016-02: templates/STATE.md present and non-empty
PASS AC-016-02: templates/loop-run-log.md present and non-empty
PASS AC-016-02: templates/loop-budget.md present and non-empty
PASS AC-016-02: templates/loop-constraints.md present and non-empty
PASS AC-016-02: templates/gate.yaml present and non-empty
PASS AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories
FAIL AC-016-03: AGENTS.md does not reference docs/LOOP_ENGINEERING.md
FAIL AC-016-03: AGENTS.md missing the never-skip-L1 rule
FAIL AC-016-05: .github/workflows/self-ci.yml does not run check-loop-files.sh
FAIL AC-016-04: scripts/check-loop-files.sh is missing or not executable

✘ Loop files check: 5 violation(s). Fix before merging.

The `--with-loop` capability writes only the six `templates/*` files; the gate
additionally demands four standards-repo artifacts at the child root
(`docs/LOOP_ENGINEERING.md`, `AGENTS.md` loop references, self-ci wiring, and
`scripts/check-loop-files.sh`), which `--with-loop` does not (and per task 8 is
not required to) write. The scenario as written is therefore **not satisfied**:
the test narrows it to a subset and asserts less than the scenario requires.

Result: **FAIL** — gate ID **AC-033-41**.

---

## Check 5 — No unaccounted behavior

Finding (not a command): the change set is
`scripts/bootstrap.sh` (rewrite into a thin dispatcher), five new sourced
modules (`bootstrap-catalog-lib.sh`, `bootstrap-detect-lib.sh`,
`bootstrap-lib.sh`, `bootstrap-plan-lib.sh`, `bootstrap-actions.sh`),
`scripts/capabilities.tsv` (the catalog), `scripts/init-ci.sh` (backend
python/rust + frontend ionic extension, plus a `_caller_permissions` helper
extraction), `scripts/tests/bootstrap-capability-catalog.bats`, and five
`templates/ci-wrappers/*.yml` copy-template sources. Every item traces to
tasks 1–10 or is a behavior-preserving helper (`_caller_permissions` extraction
is a DRY refactor; the ci-wrappers are the catalog's copy-template sources). No
unaccounted behavior found.

---

## Overall verdict

**FAIL** — the scenario-to-behavior spot check found a test that asserts less
than its scenario. The acceptance scenario **AC-033-41** requires
`scripts/check-loop-files.sh` to pass (exit 0) against the child repo; the
shipped test narrows this to only the six template checks and ignores the gate's
other failing checks. `check-loop-files.sh` empirically exits 1 (5 violations)
against a `--with-loop` child fixture. This is a false green, not a pass.

Every other gate ran clean: traceability (exit 0), full test suite (exit 0,
twice), complexity (exit 0 scoped), design-principles (exit 0 scoped; the
full-tree `skills/hallmark` CC=10 FAIL is pre-existing and out of scope).

Pipeline stops here. AC-033-41 is the exact gate ID to resolve — either the
scenario's "gate passes" requirement is rewritten to match what `--with-loop`
can write, or the test is made to assert the gate's actual exit code (and the
capability is extended to satisfy it). The fix belongs to the Coder
(behavior/test narrowing), not the Verifier.

---

# Remediation cycle 1 — AC-033-41 (attempt 2, phase 1)

Scoped re-verification. Base ref `main` (6eb2c99), branch
`spec/033-bootstrap-capability-catalog`. Fix under review: the Coder added a
`--scope standards|child` mode to `scripts/check-loop-files.sh` and rewrote the
AC-033-41 test to assert the gate's real exit codes in both directions (child
scope exit 0, default scope exit 1). Prior Check-4 FAIL evidence (above) is
retained; only the previously failing gate and the gates the fix could touch
are re-run: AC-033-41, `scripts/tests/check-loop-files.bats`, and
`make test-scripts` (the fix edits a shared gate script).

## Evidence: scenario-to-behavior spot check

command: bats --tap -f 'AC-033-41' scripts/tests/bootstrap-capability-catalog.bats
exit: 0
at: 2026-10-26T00:21:12Z

1..1
ok 1 AC-033-41: --with-loop writes the loop files the gate validates

Result: **PASS**. The rewritten test now asserts the scenario's two clauses
directly, not a narrowed substring:

- The six loop files are written and byte-identical to `templates/`
  (`[ -s "$CHILD/templates/$f" ]` + `cmp -s` against the repo template).
- The gate passes against the child repo — via the newly added child scope:
  `check-loop-files.sh --scope child "$CHILD"` asserts exit 0 and greps the
  documented clean line `Loop files check (child scope): every check passed`.
- The default (standards) scope still rejects the same child: exit 1 with
  `docs/LOOP_ENGINEERING.md is missing or empty` — pinning that child scope
  narrows the gate, not turns it into a blanket pass.

The prior false green (grep 6 PASS lines while ignoring the gate's exit-1) is
gone; the test asserts real exit codes in both directions.

## Evidence: check-loop-files.bats (scoped re-run, shared-gate characterization)

command: bats --tap scripts/tests/check-loop-files.bats
exit: 0
at: 2026-10-26T00:21:12Z

1..6
ok 1 check-loop-files: clean repo exits 0 and prints its documented clean line
ok 2 check-loop-files: empty tree exits 1 and names the missing artifact
ok 3 check-loop-files: child scope passes a child that has only the six loop templates
ok 4 check-loop-files: child scope still fails when a loop template is missing
ok 5 check-loop-files: default standards scope still rejects a child-shaped tree
ok 6 check-loop-files: an unknown scope is a usage error, not a pass

Result: **PASS**. Six characterization tests green. Test 3 and 4 prove child
scope is discriminating (passes a complete child, fails a missing template);
test 5 proves default scope still rejects a child-shaped tree; test 6 proves an
unknown scope is a usage error (exit 2), not a pass.

## Evidence: full test suite (scoped re-run, make test-scripts)

command: make test-scripts
exit: 0
at: 2026-10-26T00:21:12Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..539
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
...
ok 207 AC-033-41: --with-loop writes the loop files the gate validates
...
ok 213 AC-033-47: orchestration references resolve
ok 214 AC-033-48: skills and gate-consistency gates stay green
ok 215 AC-033-49: no regression in default output or existing init-ci flags
...
ok 539 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Summary: 539 `ok`, 0 `not ok`.

Result: **PASS**. Suite grew from 535 → 539 tests (the four new
`check-loop-files.bats` scope tests). All 539 green, 0 failures. The fix
touches a shared gate script, so the full suite re-run confirms no other gate
regressed (AC-033-47 orchestration, AC-033-48 skills + gate-consistency, and
AC-033-49 no-regression all green).

## Evidence: two-direction claim — real --with-loop fixture

command: manual child fixture (`.standards/` symlinks + `bootstrap.sh --with-loop`), then `bash scripts/check-loop-files.sh {--scope child,} <child>`
exit: child scope 0; default scope 1
at: 2026-10-26T00:21:12Z

bootstrap exit=0
=== CHILD SCOPE ===
Checking loop-engineering foundation bundle (child scope) in: /tmp/opencode/withloop.wLejgn/child

PASS AC-016-02: templates/LOOP.md present and non-empty
PASS AC-016-02: templates/STATE.md present and non-empty
PASS AC-016-02: templates/loop-run-log.md present and non-empty
PASS AC-016-02: templates/loop-budget.md present and non-empty
PASS AC-016-02: templates/loop-constraints.md present and non-empty
PASS AC-016-02: templates/gate.yaml present and non-empty

PASS AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories

✔ Loop files check (child scope): every check passed.
child-scope exit=0
=== DEFAULT SCOPE ===
Checking loop-engineering foundation bundle in: /tmp/opencode/withloop.wLejgn/child

FAIL AC-016-01: docs/LOOP_ENGINEERING.md is missing or empty
PASS AC-016-02: templates/LOOP.md present and non-empty
PASS AC-016-02: templates/STATE.md present and non-empty
PASS AC-016-02: templates/loop-run-log.md present and non-empty
PASS AC-016-02: templates/loop-budget.md present and non-empty
PASS AC-016-02: templates/loop-constraints.md present and non-empty
PASS AC-016-02: templates/gate.yaml present and non-empty
PASS AC-016-02/AC-016-04: gate.yaml has denylist + autoMergeAllowlist keys with all six categories
FAIL AC-016-03: AGENTS.md does not reference docs/LOOP_ENGINEERING.md
FAIL AC-016-03: AGENTS.md missing the never-skip-L1 rule
FAIL AC-016-05: .github/workflows/self-ci.yml does not run check-loop-files.sh
FAIL AC-016-04: scripts/check-loop-files.sh is missing or not executable

✘ Loop files check: 5 violation(s). Fix before merging.
  Reference: docs/LOOP_ENGINEERING.md
default-scope exit=1

Result: **PASS**. Both directions hold on a real `--with-loop` fixture: child
scope exits 0 (the six files the bootstrap writes are validated); the default
scope still exits 1 with the same 5 violations the prior report recorded.

## Evidence: default-scope output byte-identical to main

command: `git show main:scripts/check-loop-files.sh > /tmp/…/main.sh`, then `bash {main,new} scripts/check-loop-files.sh <tree>` over the clean standards tree and an empty tree; `diff` stdout+stderr
exit: clean tree 0/0; empty tree 1/1; diffs empty in both cases
at: 2026-10-26T00:21:12Z

extracted main version, 128 lines
--- clean standards tree comparison ---
new exit=0
main exit=0
CLEAN TREE: BYTE-IDENTICAL
--- empty tree comparison (default scope) ---
new exit=1
main exit=1
EMPTY TREE: BYTE-IDENTICAL

Result: **PASS**. The default (standards) scope of the edited script produces
byte-identical stdout+stderr and the same exit codes as the `main` version over
both a clean standards tree and an empty tree — the `--scope` addition did not
alter existing default-scope behavior.

---

# Remediation cycle 1 — overall verdict

**PASS.** The AC-033-41 spot-check FAIL is resolved. The test now asserts the
scenario's clauses (files written byte-identically; the gate passes against the
child repo in child scope) with the gate's real exit codes, no longer narrowing
the assertion to a six-line substring. The two-direction claim holds on a real
`--with-loop` fixture, and the default scope is byte-identical to `main`. No
other gate regressed: `make test-scripts` is green (539 ok, 0 not ok) including
the orchestration, skills, gate-consistency, and no-regression tests.

Prior FAIL evidence for Check 4 (above) is retained for the audit trail.

## Quality gates

# 30-report.md — Mutation Runner report (spec 033)

Stage 5a. Branch `spec/033-bootstrap-capability-catalog`, base ref `main`
(6eb2c99). Working tree dirty — expected at this stage; only the PR Opener
(stage 5b) commits.

Change set under review (bash-only): `scripts/bootstrap.sh` (rewritten into a
thin dispatcher), five new sourced modules (`bootstrap-lib.sh`,
`bootstrap-catalog-lib.sh`, `bootstrap-detect-lib.sh`, `bootstrap-plan-lib.sh`,
`bootstrap-actions.sh`), `scripts/capabilities.tsv`,
`scripts/init-ci.sh`, `scripts/check-loop-files.sh`,
`scripts/tests/bootstrap-capability-catalog.bats`,
`scripts/tests/check-loop-files.bats`, five
`templates/ci-wrappers/*.yml` copy-template sources.

---

## Verifier verdict (carried forward)

**PASS** — `specs/033-bootstrap-capability-catalog/25-verification.md`,
§Remediation cycle 1 — overall verdict (attempt 2, phase 1).

The first Verifier attempt returned **FAIL** on gate ID **AC-033-41** (the
scenario-to-behavior spot check found a test asserting less than its scenario:
the shipped test grepped six `PASS` lines and ignored the gate's exit code,
while `check-loop-files.sh` empirically exited 1 against a `--with-loop` child
repo). The fix came back through the Coder as a `--scope standards|child` mode
plus a two-direction exit-code test, and the scoped re-verification passed.
Remediation accounting is in §Remediation record below.

Stage 5a precondition therefore satisfied.

---

## ⚠ BLOCKING handoff defect — `check-audit-trail.sh` is RED on `25-verification.md`

Not my gate to fix (it belongs to the Verifier's artifact and to the PR
Opener's pre-push check), and I have not touched it. Reporting it because my
own precondition re-check caught it: **the pipeline cannot reach a green draft
PR until it is resolved.**

`scripts/check-audit-trail.sh` requires the five Verifier evidence headings to
match the canonical check names **exactly** (`scripts/check-audit-trail.sh:202-215`:
`tolower(name) == tolower(want)` after stripping only `## Evidence:` and
trailing whitespace). `25-verification.md` heads four of the five blocks with a
suffix, so none of those four match:

| Canonical name the gate wants | Heading actually present |
|---|---|
| `## Evidence: full test suite` | `## Evidence: full test suite (run 1 of 2)`, `(run 2 of 2)`, `(scoped re-run, make test-scripts)` |
| `## Evidence: complexity gate` | `## Evidence: complexity gate (scoped to the change)` |
| `## Evidence: design-principles gate` | `## Evidence: design-principles gate (scoped, -BaseRef main)`, `(full tree)` |
| `## Evidence: scenario-to-behavior spot check` | `## Evidence: scenario-to-behavior spot check — AC-033-41 test (scoped re-run)` |
| `## Evidence: scenario traceability` | exact — the only one that matches |

## Evidence: audit-trail gate (spec folder completeness)

command: bash scripts/check-audit-trail.sh 033-bootstrap-capability-catalog
exit: 1
at: 2026-10-26T00:28:23Z

PASS 033-bootstrap-capability-catalog: 10-tasks.md present and non-empty
PASS 033-bootstrap-capability-catalog: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 033-bootstrap-capability-catalog: 25-verification.md present and non-empty
PASS 033-bootstrap-capability-catalog: 30-report.md present and non-empty
PASS 033-bootstrap-capability-catalog: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T00:04:48Z
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'full test suite' (AC-015-04/AC-015-14)
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'complexity gate' (AC-015-04/AC-015-14)
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'design-principles gate' (AC-015-04/AC-015-14)
FAIL 033-bootstrap-capability-catalog: 25-verification.md has no evidence block for 'scenario-to-behavior spot check' (AC-015-04/AC-015-14)
✘ Audit-trail check: 4 violation(s).

Folder completeness is fine (`30-report.md` present, this file included); the
only failures are the four heading names.

**Prior art shows the intended shape**: archived specs carry a block whose
heading is the exact canonical name — `grep -hE '^## Evidence: (scenario
traceability|full test suite|complexity gate|design-principles gate|scenario-to-behavior spot check)$' docs/changes/*.md`
yields 58 exact-name headings across the archive (10/10/18/10/10). Suffixed
blocks appear there too, but always *alongside* an exact-named block, never
instead of one.

**Minimal correct fix (owner: the Verifier, not me):** rename the four
canonical blocks to the exact names — `## Evidence: full test suite`,
`## Evidence: complexity gate`, `## Evidence: design-principles gate`,
`## Evidence: scenario-to-behavior spot check` — keeping every `command:` /
`exit:` / `at:` marker and all raw output byte-for-byte, and keeping the
suffixed scoped-re-run blocks as additional (non-canonical) evidence. That is a
phase-1 scoped re-verification (attempt 3), not a gate change: `check-audit-trail.sh`
and its `FIVE_CHECKS` array are gate config and off-limits to agents per the
Stop-and-Ask matrix ("fix the code, never the threshold").

I deliberately did **not** edit `25-verification.md`. It is the Verifier's
independent re-check record; a heading rewrite performed by a downstream stage
would blur who asserted what, and the audit contract's whole point is that the
record is self-attested per stage. This is an out-of-scope finding recorded per
the matrix, escalated to the orchestrator for routing.

---

## Conformance tier and whether mutation testing applies

Tier: **`mvp`**.

Determination (no `Conformance tier:` declaration exists in `AGENTS.md` or any
`AGENTS_*.md`, so the floor applies per `docs/CONFORMANCE_TIERS.md` §Tier
assignments — "rules not listed here are `mvp`" — and per
`docs/SPEC_PIPELINE.md` §Stop-and-Ask decision matrix, row "Project type
ambiguous … defer to the harness default (`mvp` tier)"):

## Evidence: conformance tier declaration grep

command: grep -rn "Conformance tier: *\(mvp\|production\|multi-service\)" AGENTS.md AGENTS_*.md
exit: 2
at: 2026-10-26T00:21:55Z

(no matches; `AGENTS_*.md` does not exist, so grep exits 2 — no declaration,
no `production` opt-in)

Corroborated by the repo's own gate, which auto-detects the same tier:
`25-verification.md` Check 3 and Check 3.5 both record `"tier": "mvp"` from
`scripts/check-code-principles.sh`.

Per `docs/SPEC_PIPELINE.md` §Conformance tiers, mutation testing is a
`production`-tier gate ("Architect — mutation testing: skip" at `mvp`;
§Tooling by language: "Mutation testing (`production`+)").

### Tooling fact, independent of tier

No bash/shell mutation lane exists in this repo, at any tier:

- `docs/SPEC_PIPELINE.md` §Tooling by language lists mutation tooling for
  Java (PiTest), Go (`go-mutesting`/`gremlins`), and JS/TS (Stryker) only.
- The repo's mutation template catalog carries one lane per supported
  non-shell language — `ci/templates/go-feature/Makefile` (gremlins),
  `ci/templates/js-feature/package.json` (Stryker), `ci/templates/mutation.mk`,
  `ci/templates/mutants.toml` (cargo-mutants), `ci/templates/mutmut-pyproject.toml`
  (mutmut, Python) — and no shell/bash lane. `make mutation` itself only names
  `mvn verify -Pmutation` / `gremlins unleash` / `npx stryker run`.
- No mutation binary is installed in this environment (checked: `pitest`,
  `stryker`, `go-mutesting`, `gremlins`, `mull` — all absent).

So: mutation score **skipped — `mvp` tier**. This is a recorded skip with
evidence, not a re-run-until-green omission. Had this project been
`production`-tier, bash mutation would still have no lane in this repo's
catalog — a tooling gap to raise as a follow-up, never a threshold to relax.

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-10-26T00:21:58Z

skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)

## Mutation-kill work

None performed — no mutation run happened, so there are no surviving mutants
and no tests were added by this stage. This stage wrote only this report; it
changed no production code and no test file.

---

## Equivalent mutants

**None.** An equivalent mutant is by definition a survivor of an actual
mutation run; with the run skipped there is no survivor list to adjudicate.
Nothing is being waved through as "un-killable" here — the gate did not run.

This is deliberately not the same claim as "no mutants survive". A bash
mutation lane (e.g. mutating tab-field indexes in `bootstrap-catalog-lib.sh`,
`--dry-run` flag comparisons in `bootstrap-plan-lib.sh`, or the `--scope`
branch in `scripts/check-loop-files.sh`) would produce real, killable
survivors. The skip is tier-and-tooling driven, and recording it as such keeps
that distinction auditable.

---

## Complexity summary (carried from the Refactorer, via Verifier Check 3)

Carried forward from `25-verification.md` §Check 3 and §Check 3.5 — the
Refactorer's before/after measurements are re-recorded there, per the audit
contract.

| Measurement | Result |
|---|---|
| Complexity gate, scoped to the diff (`-BaseRef main`) | exit 0 — `fails: []`, `warns: []` |
| Complexity gate, full tree | exit 1 — 1 FAIL, pre-existing, out of scope (below) |
| Design-principles gate, scoped (`-BaseRef main`) | exit 0 — `fails: []`, `warns: []` |
| Design-principles gate, full tree | exit 1 — same pre-existing FAIL; 16 pre-existing WARNs, all outside the change set |
| Pre-existing FAIL (not this spec) | `./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10` |

Structural claim the Refactorer made — `scripts/bootstrap.sh` split into five
sourced modules so each unit stays small and single-purpose. Measured size of
the resulting units (this stage's own `wc -l`, corroborating the split):

| File | Lines |
|---|---|
| `scripts/bootstrap.sh` (dispatcher) | 311 |
| `scripts/bootstrap-lib.sh` | 431 |
| `scripts/bootstrap-actions.sh` | 439 |
| `scripts/bootstrap-plan-lib.sh` | 178 |
| `scripts/bootstrap-catalog-lib.sh` | 138 |
| `scripts/bootstrap-detect-lib.sh` | 112 |

Honest limitation, same as the Verifier recorded: bash is outside
`check-code-principles.sh`'s CC analyzer (Java/Go/JS-TS/Python/Rust only), so
none of these units has a measured cyclomatic complexity. `shellcheck` is not
installed in this environment, so no bash static analysis backstops it either.
No WARN is being suppressed by this — the scoped gate genuinely finds nothing
in the change because it cannot analyze the language, not because the diff is
clean by measurement.

No design-gate WARN was raised against this change set, so there is nothing to
flag to the PR Opener beyond the pre-existing full-tree items recorded above.

---

## Final test status

Re-run by this stage because the remediation fix touched a shared gate script
and added tests after the Verifier's last run. Full suite, then the spec's own
bats file.

## Evidence: final full test suite

command: make test-scripts
exit: 0
at: 2026-10-26T00:27:37Z

Checking bats assertions are not vacuous...

PASS check-bats-assertions: 56 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..539
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
... (539 `ok` lines total, 0 `not ok`) ...
ok 535 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 536 wire: mixed choice+noul request — low confidence exits 10 with BOTH answers printed
ok 537 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 538 wire: non-numeric confidence is invalid, exits 10
ok 539 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq

Counts: `ok` = 539, `not ok` = 0, plan `1..539`. Includes all 49 `AC-033-*`
scenarios (`ok 167 AC-033-01` … `ok 215 AC-033-49`).

## Evidence: spec 033 bootstrap bats file

command: bats --tap scripts/tests/bootstrap-capability-catalog.bats
exit: 0
at: 2026-10-26T00:22:43Z

1..49
ok 1 AC-033-01: --list prints every catalog entry as id<TAB>label<TAB>category
ok 2 AC-033-02: --list output is generated from the catalog byte-for-byte
ok 3 AC-033-03: menu, --list and --all all read the one catalog
ok 4 AC-033-04: every catalog entry carries complete fields
... (49 `ok` lines total, 0 `not ok`) ...
ok 47 AC-033-47: orchestration references resolve
ok 48 AC-033-48: skills and gate-consistency gates stay green
ok 49 AC-033-49: no regression in default output or existing init-ci flags

Counts: `ok` = 49, `not ok` = 0.

Harness note for timestamp honesty: a first `make test-scripts` invocation at
`2026-10-26T00:22:01Z` was killed by this stage's tool-call timeout at 120 s
before bats finished — a harness limit, not a test failure. It was re-run with
a 600 s timeout; the run recorded above (00:24:03Z → 00:27:37Z) is the
completed one and is the authoritative result.

**Final test status: PASS** — 539/539 in the full suite, 49/49 in the spec's
own bats file, both exit 0. No failures, no flake observed (the Verifier's two
runs plus this one are all clean).

---

## Gate results (rolled up)

| Gate | Command | Exit | Verdict | Where recorded |
|---|---|---|---|---|
| Scenario traceability | `scripts/check-scenario-traceability.sh --json` | 0 | PASS — 49/49 traced, no dangling refs | `25-verification.md` Check 1 |
| Full test suite | `make test-scripts` | 0 | PASS — 539 ok, 0 not ok (this stage re-ran) | §Final test status above |
| Spec bats file | `bats --tap scripts/tests/bootstrap-capability-catalog.bats` | 0 | PASS — 49 ok, 0 not ok (this stage) | §Final test status above |
| Complexity (scoped) | `scripts/check-code-principles.sh --gates complexity -BaseRef main --json` | 0 | PASS — no FAIL, no WARN in the diff | `25-verification.md` Check 3 |
| Design-principles (scoped) | `scripts/check-code-principles.sh -BaseRef main --json` | 0 | PASS — no FAIL, no WARN in the diff | `25-verification.md` Check 3.5 |
| Design-principles (full tree) | `scripts/check-code-principles.sh --json` | 1 | Pre-existing, out of scope — 1 FAIL + 16 WARNs, none in this change set | `25-verification.md` Check 3.5 |
| Scenario-to-behavior spot check | manual, 4 scenarios probed | — | PASS after remediation (AC-033-41 resolved) | `25-verification.md` Check 4 + cycle 1 |
| Mutation testing | `make mutation` | 0 | **SKIP** — `mvp` tier; no bash mutation lane exists at any tier | §Conformance tier above |
| Property tests | — | — | SKIP — `production` tier gate; exercised by the scoped design-principles run at `mvp` | `25-verification.md` Check 3.5 |
| Audit trail (folder + evidence blocks) | `bash scripts/check-audit-trail.sh 033-bootstrap-capability-catalog` | **1** | **RED — blocks stage 5b**: 4/5 evidence headings missing their exact canonical names in `25-verification.md` | §⚠ BLOCKING handoff defect above |

---

## Remediation record

Bounded-loop accounting per `docs/SPEC_PIPELINE.md` §Remediation budget,
carried forward from `25-verification.md`'s attempt entries and the
orchestrator's loop summary — not guessed.

| # | Gate ID | Phase | Attempt | Resolved by | Status |
|---|---|---|---|---|---|
| 1 | **AC-033-41** (scenario-to-behavior spot check) | **1 — pre-PR** | Verifier attempt 2 (1 retry after the attempt-1 BLOCK) | Coder: added `check-loop-files.sh --scope standards\|child`; rewrote the test to assert real exit codes both ways | **Resolved** — scoped re-verification PASS |

Loop counters from the orchestrator's loop summary (`runs.jsonl`, appended by
the orchestrator, verbatim):

```
{"specSlug":"033-bootstrap-capability-catalog","gatesFailed":["spot-check"],"warnings":[],"durationSec":660,"outcome":"fail","runId":"19d88ed3-22bf-4cc5-adcb-7f72b84bff40","loopCount":1,"phase1Retries":0,"phase2Retries":0}
{"specSlug":"033-bootstrap-capability-catalog","gatesFailed":[],"warnings":[],"durationSec":300,"outcome":"pass","runId":"e8c46977-5718-47f7-9732-83a4e41de941","loopCount":2,"phase1Retries":1,"phase2Retries":0}
```

So: **phase 1, cycle 1, one retry, resolved at attempt 2** — consistent with
`25-verification.md` §Remediation cycle 1.

- **Phase 2 (post-PR CI):** none — `phase2Retries: 0`; the PR is not open yet.
- **Phase 3 (deploy verification):** not reached (non-frontend lane; runs only
  after stage 5b).
- **Budget state:** phase 1 used 1 of 3, phase 2 used 0 of 3. Neither budget was
  exhausted; no escalation is due.

---

## Out-of-scope findings (recorded, not fixed)

1. **`check-audit-trail.sh` exits 1 on this spec folder** — the four suffixed
   Verifier evidence headings. Full detail in §⚠ BLOCKING handoff defect above;
   listed here too because it is the one item on this list that actually stops
   the pipeline rather than merely being noted. Owner: Verifier (heading rename
   in a phase-1 scoped re-verification). **Do not open the draft PR before it is
   green.**
2. **`runs.jsonl` is modified in the working tree** — `git diff --stat` shows
   2 insertions, both orchestrator telemetry lines for this spec (the two
   JSONL records quoted above). It is a tracked file, outside spec 033's
   subject matter. The PR Opener decides whether pipeline telemetry belongs in
   this commit (prior specs appear to have committed it); this stage neither
   reverts nor commits it.
3. **Full-tree design-principles FAIL is pre-existing** —
   `skills/hallmark/site/examples/cobalt-01/script.js` CC=10, plus 16 WARNs in
   `ci/templates/*` and `skills/hallmark/*`. Untouched by this change set; not
   this spec's defect. A separate follow-up spec, not a silent fix here.
4. **No bash mutation lane and no `shellcheck`** — the change set is 1,000+
   lines of shell whose only verification is bats behavioral tests plus a
   language-blind complexity gate. Worth a follow-up spec if this repo ever
   graduates to `production` tier; recorded so the gap is visible rather than
   implied-green.

---

## Summary for the PR Opener

- Verifier: **PASS** (remediation cycle 1, phase 1, attempt 2).
- Mutation score: **skipped — `mvp` tier** (and no bash mutation lane exists at
  any tier). No equivalent mutants — no run, no survivors.
- Final full suite: **539 ok / 0 not ok**, exit 0. Spec bats file: **49 ok /
  0 not ok**, exit 0.
- Complexity: scoped gate exit 0 with no FAIL/WARN; the one full-tree FAIL is
  pre-existing and out of scope.
- No production code and no test file was changed by this stage — this report
  is its only artifact.
- **STAGE 5A VERDICT: GREEN** on its own gates (mutation skip recorded, full
  suite green, complexity carried).
- **BUT: do not open the PR yet.** Your pre-push gate
  `scripts/check-audit-trail.sh` exits **1** on this folder: four of the five
  Verifier evidence headings in `25-verification.md` are suffixed rather than
  the exact canonical names the gate matches. Route to the Verifier for the
  heading rename (§⚠ BLOCKING handoff defect). Re-run the audit gate before
  trusting a green PR.


---

## PR record (stage 5b)

PR: https://github.com/RexiAI/my-engineering-standards/pull/100
Commit count: 9 (8 task/spec commits + 1 record commit)

## 40-deploy.md

# 40-deploy.md — Deploy Verifier (spec 033-bootstrap-capability-catalog)

Stage 5c, phase 3. Attempt 1 (phase-3 budget: max 3, independent counter).
PR: https://github.com/RexiAI/my-engineering-standards/pull/100
Branch: `spec/033-bootstrap-capability-catalog`
PR head at verification: `2ddee56c007021eb1a57f4e7b55458ad8032cee2`
Evidence run: `2026-10-26T00:33:41Z` – `2026-10-26T00:34:01Z`

Repo classification: **non-frontend**. This repo is a standards/tooling
repository — bash gate scripts, bats tests, docs, ADRs, CI workflow templates.
It declares no frontend stack signal, carries no `vercel.json`, no root
`package.json`, and no `.vercel` project link. The deploy lane therefore does
not apply and no deployment, build, health check, or E2E run was executed.

## Status summary

| Check | Result | Detail |
|---|---|---|
| Repo classification | non-frontend | 0 root frontend signals; no framework dependency; no Vercel project link |
| Deploy URL | n/a | no Vercel project linked to this repository |
| Build status | SKIP | not applicable — non-frontend repo |
| Health check | SKIP | not applicable — non-frontend repo |
| E2E verdict | SKIP | not applicable — no preview URL exists to point `e2e-runner` at |
| Phase-3 attempt count | 1 | classification evidence run only; 0 fix-and-redeploy rounds consumed |
| `vercel deploy` invoked | no | prohibited; no deploy was created by this stage |

---

## Evidence: root frontend signal scan

command: for f in vercel.json package.json angular.json next.config.js next.config.mjs next.config.ts ionic.config.json .vercel/project.json; do [ -e "$f" ] && echo "PRESENT $f" || echo "ABSENT  $f"; done
exit: 0
at: 2026-10-26T00:33:56Z

ABSENT  vercel.json
ABSENT  package.json
ABSENT  angular.json
ABSENT  next.config.js
ABSENT  next.config.mjs
ABSENT  next.config.ts
ABSENT  ionic.config.json
ABSENT  .vercel/project.json
root-frontend-signal-count=0

Every deterministic frontend signal from `scripts/check-audit-trail.sh
frontend_repo()` is absent at the project root.

## Evidence: tracked frontend manifests

command: git ls-files | grep -E '(^|/)(vercel\.json|package\.json|angular\.json|next\.config\.[a-z]+|ionic\.config\.json)$'
exit: 0
at: 2026-10-26T00:33:56Z

ci/templates/js-feature/package.json
scripts/media/voice-chat/package.json

Only two `package.json` files are tracked, and neither is a project manifest:
one is a CI template fixture for child repos, the other a private tooling
package for the media-voice agent. There is no root `package.json` and no
`vercel.json` anywhere in the tracked tree.

## Evidence: framework dependency scan

command: grep -nE '"(next|react|@angular/core|@ionic/angular)"[[:space:]]*:' ci/templates/js-feature/package.json scripts/media/voice-chat/package.json
exit: 1
at: 2026-10-26T00:34:01Z

(no output — no frontend framework dependency declared)

The only tracked manifests declare `vitest`, `fast-check`, `@stryker-mutator/*`,
and `eslint` (CI template fixture), or no dependencies at all (voice-chat
tooling). No Angular, React, Next.js, or Ionic dependency exists.

## Evidence: Vercel project link and credentials

command: ls -la .vercel; for v in VERCEL_TOKEN VERCEL_ORG_ID VERCEL_PROJECT_ID; do [ -n "${!v:-}" ] && echo "$v=set" || echo "$v=unset"; done
exit: 2
at: 2026-10-26T00:34:01Z

ls: cannot access '.vercel': No such file or directory
VERCEL_TOKEN=unset
VERCEL_ORG_ID=unset
VERCEL_PROJECT_ID=unset

No Vercel project link exists (`.vercel/project.json` absent) and per-machine
Vercel credentials are unset for this workspace. Because the repo classifies as
non-frontend on deterministic filesystem evidence, no `vercel inspect`,
`vercel ls`, or `vercel logs` call was attempted — there is no project to poll.
Token values were never read or echoed, only their presence tested.

## Evidence: repo composition

command: git ls-files | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -8; git ls-files | grep -cE '\.bats$'; git ls-files | grep -cE '^(src/app|src/components|pages/|app/routes)/'
exit: 1
at: 2026-10-26T00:34:01Z

    294 md
     69 sh
     62 yml
     56 bats
     13 go
     11 json
     11 java
     11 drawio
56
0

595 tracked files: prose, shell gates, workflow templates, and bats tests. No
application source tree exists (0 files under a frontend app layout).

## Evidence: phase-2 CI state at PR head (observed, not a deploy check)

command: gh run view 40249878740 --json event,headSha,conclusion,jobs --jq '{event,headSha,conclusion,jobs:[.jobs[]|{name,conclusion,failingSteps:[.steps[]|select(.conclusion=="failure")|.name]}]}'
exit: 0
at: 2026-10-26T00:34:01Z

{"conclusion":"failure","event":"pull_request","headSha":"2ddee56c007021eb1a57f4e7b55458ad8032cee2","jobs":[{"conclusion":"failure","failingSteps":["Check finished specs are archived"],"name":"Validate"}]}

The same single step fails on the `push` run (40249874038) at the same head.
It is the expected pre-archive state, not a code or test failure: the spec has
`30-report.md` (so it is "finished") but has not yet been archived, and
`scripts/check-specs-archived.sh` only exempts phase-3 budget exhaustion.
Archival is stage 5d's final commit, so this gate can only go green after 5d
runs. Every other Validate step passed. Recorded here for the Archiver's
visibility; it carries no deploy-lane verdict and did not change the
classification above.

## Evidence: audit-trail gate (pre-write baseline)

command: scripts/check-audit-trail.sh 033-bootstrap-capability-catalog
exit: 0
at: 2026-10-26T00:33:41Z

PASS 033-bootstrap-capability-catalog: 10-tasks.md present and non-empty
PASS 033-bootstrap-capability-catalog: 20-acceptance/ has an AC-*.md with a '## AC-NNN-NN' heading (AC-015-10)
PASS 033-bootstrap-capability-catalog: 25-verification.md present and non-empty
PASS 033-bootstrap-capability-catalog: 30-report.md present and non-empty
PASS 033-bootstrap-capability-catalog: evidence block 'scenario traceability' — command: scripts/check-scenario-traceability.sh --json, exit: 0, at: 2026-10-26T00:04:48Z
PASS 033-bootstrap-capability-catalog: evidence block 'full test suite' — command: make test-scripts, exit: 0, at: 2026-10-26T00:03:46Z
PASS 033-bootstrap-capability-catalog: evidence block 'complexity gate' — command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json, exit: 0, at: 2026-10-26T00:05:03Z
PASS 033-bootstrap-capability-catalog: evidence block 'design-principles gate' — command: scripts/check-code-principles.sh -BaseRef main --json, exit: 0, at: 2026-10-26T00:04:51Z
PASS 033-bootstrap-capability-catalog: evidence block 'scenario-to-behavior spot check' — command: bats --tap -f 'AC-033-41' scripts/tests/bootstrap-capability-catalog.bats, exit: 0, at: 2026-10-26T00:21:12Z
✔ Audit-trail check: specs/033-bootstrap-capability-catalog complete, verifier evidence recorded.

## Evidence: audit-trail gate (post-write, both invocation modes)

command: scripts/check-audit-trail.sh 033-bootstrap-capability-catalog && scripts/check-audit-trail.sh --require-deploy 033-bootstrap-capability-catalog
exit: 0
at: 2026-10-26T00:34:17Z

PASS 033-bootstrap-capability-catalog: 40-deploy.md skip reason acceptable for a non-frontend repo (AC-031-19): Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable
✔ Audit-trail check: specs/033-bootstrap-capability-catalog complete, verifier evidence recorded.

Both the stage-5b pre-push invocation and the stage-5d `--require-deploy`
invocation exit 0 with this artifact present and non-empty.

---

## Notes for stage 5d

- Working tree was dirty at verification time on `runs.jsonl` only (one
  appended pipeline telemetry row for spec 033, written by the orchestrator).
  Not stashed, not committed, not touched by this stage — routed to the PR
  Opener per the existing convention.
- No commit, push, tag, or PR was created by this stage.
- The verdict below is the recorded skip the audit-trail gate accepts for a
  non-frontend repo (AC-031-19); stage 5d may run `--require-deploy` and this
  artifact satisfies it because the flag is non-frontend-behavior-independent.

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

---

## Phase-2 CI verification (round 1)

Round 1 of 3. Post-PR CI check on head
`2393d4348156fbd4bfe34c656e235fd2da705700` (branch
`spec/033-bootstrap-capability-catalog`), PR #100.

## Evidence: post-PR CI check-runs

command: gh api repos/RexiAI/my-engineering-standards/commits/2393d4348156fbd4bfe34c656e235fd2da705700/check-runs --jq '.check_runs[] | "\(.id)\t\(.name)\t\(.status)\t\(.conclusion)"'
exit: 0
at: 2026-10-26T01:35:16Z

121339867606	Review PR / Review PR	in_progress	null
121339804058	Validate	completed	success
121339789908	Validate	completed	success

## Evidence: post-PR CI pr checks

command: gh pr checks 100 --json name,state,bucket,workflow
exit: 0
at: 2026-10-26T01:35:16Z

[{"bucket":"pending","name":"Review PR / Review PR","state":"IN_PROGRESS","workflow":"PR Review Agent"},{"bucket":"pass","name":"Validate","state":"SUCCESS","workflow":"Self CI"},{"bucket":"pass","name":"Validate","state":"SUCCESS","workflow":"Self CI"}]

## Evidence: previously-red step "Check finished specs are archived"

command: gh run view 40250057971 --json jobs --jq '.jobs[].steps[] | select(.name=="Check finished specs are archived") | "\(.name)\t\(.conclusion)"' && gh run view 40250062742 --json jobs --jq '.jobs[].steps[] | select(.name=="Check finished specs are archived") | "\(.name)\t\(.conclusion)"'
exit: 0
at: 2026-10-26T01:35:16Z

(push run 40250057971)
Check finished specs are archived	success
(pull_request run 40250062742)
Check finished specs are archived	success

## Per-check table

| Check ID | Name | Workflow | Status | Conclusion | Verdict |
|---|---|---|---|---|---|
| 121339789908 | Validate | Self CI (push) | completed | success | **PASS** |
| 121339804058 | Validate | Self CI (pull_request) | completed | success | **PASS** |
| 121339867606 | Review PR / Review PR | PR Review Agent | in_progress | null | **PENDING** (not a Self CI gate; separate non-blocking review agent) |

Both Self CI runs (`push` 40250057971 and `pull_request` 40250062742) at head
`2393d43` completed green. The previously-red step **"Check finished specs are
archived"** now reports `success` on both runs — the archive commit resolved the
stage-5d pre-archive failure recorded in `40-deploy.md` (head `2ddee56`).

The third check, `Review PR / Review PR` (PR Review Agent workflow), remained
`in_progress` on its LLM review step for the entire observation window and is
not a Self CI gate. It is a separate non-blocking review agent and is reported
here as pending, not as a pass or fail.

## Verdict

**PASS** — both Self CI runs green; the previously-red "Check finished specs are
archived" step is now green on both push and pull_request. No failing check to
route.
