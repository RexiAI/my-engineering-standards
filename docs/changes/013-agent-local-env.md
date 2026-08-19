# 013-agent-local-env

> Spec pipeline archive. Original source: `specs/013-agent-local-env/` (deleted by this script).
> Archived: 2026-08-19

## Original ask

# Agent local environment organization (secrets per machine)

Each developer machine holds its own credentials for the pipeline agents —
Atlassian MCP tokens, GitHub/Bitbucket tokens, CI API tokens — but nothing
secret may ever be committed. acdc-civ solves this with a committed template +
gitignored real file + a loader script:

- `config/agent.local.env.example` — committed, lists every credential the
  pipeline needs with placeholder values and a comment per variable.
- `config/agent.local.env` — gitignored, holds the real values on each machine.
- `scripts/load-env.sh` (+ `.ps1` twin) — sources the real file and exports the
  variables; fails loudly if the real file is missing but the template exists.

Bring the same pattern to this repo:

## What it must provide

- A committed template enumerating every credential the pipeline agents can use
  (Jira/Confluence MCP tokens, GitHub token, Jenkins API token, kubeconfig paths).
- A gitignore rule that keeps the real `agent.local.env` out of every commit.
- A guard (hook or gate script) that refuses to commit the real env file — the
  same class of failure as "agent commits `.env`" which this repo already forbids.
- A `load-env` script that the agents source at run start, never hardcoding a
  value anywhere in agents/, commands/, or scripts/.
- Cross-references: agents that need a credential read it via the loader, never
  via a literal in a prompt or script.

## Acceptance criteria

- AC-001: `config/agent.local.env.example` exists, committed, with one
  placeholder variable per credential and a comment describing each.
- AC-002: the real file is gitignored; a pre-commit hook or gate script exits
  non-zero if a real env file is staged.
- AC-003: `scripts/load-env.sh` sources the real file and exports every variable;
  errors if the file is absent while the example exists.
- AC-004: no hardcoded credential value appears in agents/, commands/, scripts/,
  or docs/ (grep check, exit 1 on a match).
- AC-005: AGENTS.md / README documents the per-machine setup (copy example → fill
  real → gitignored).

## Tasks

# Tasks — Agent local environment (secrets per machine)

Formalization of `specs/013-agent-local-env/00-informal.md`. Bring the acdc-civ
per-machine secrets pattern to this repo: a committed credential template +
gitignored real file + a loader script + commit guards + per-machine setup docs.

Two of the informal spec's premises did **not** survive grounding against the
real repo and are corrected below (§Grounded reality, §Open questions):

1. **No `hooks.json` exists in this repo.** The informal spec references a
   `hooks.json` with `guard-java-home` / `guard-commit-msg`. Nothing matching
   exists anywhere in the tree (verified by `find` + grep across the checkout).
   This repo's *documented* local-hook mechanism is `.githooks/` wired via
   `core.hooksPath` (`docs/GIT_WORKFLOW.md` §Git Hooks: Local Enforcement), but
   this standards repo itself ships no hook files. The realistic enforcement
   point of record is therefore a **self-ci gate**, with the guard written as a
   standalone script so child repos can wire it into `.githooks/pre-commit` per
   the documented convention.
2. **The informal spec's credential enumeration is mostly invented.**
   Jira/Confluence MCP tokens, a Jenkins API token, and kubeconfig paths appear
   nowhere in this repo — no Jira/Confluence/Jenkins/Bitbucket/kubeconfig
   references exist in `agents/`, `commands/`, `scripts/`, `docs/`, or `okf/`
   (only Atlassian **design-system** mentions in the vendored
   `skills/design-taste-frontend/` skill, which are not credentials). The only
   credentials the pipeline agents actually consume are **GitHub tokens**
   (`GITHUB_TOKEN`, `GH_TOKEN`). Per the task instruction "do not invent
   credentials", the template enumerates exactly those two.

## Grounded reality (verified against this repo by executing the real tree)

### Credentials the pipeline agents actually use

| Env var | Where it is real in this repo | Used by |
|---|---|---|
| `GITHUB_TOKEN` | `okf/mcp-server-connection.md:76` — GitHub MCP server auth, "personal access token with `repo` scope" | GitHub MCP server; `docs/TESTING.md:270` uses `github.token` for PR diagnostic comments |
| `GH_TOKEN` | `docs/CI_CD.md:376` — release automation ("Required secrets: `GH_TOKEN` (GitHub)") | `gh` CLI; `agents/spec-pr-opener.md` pushes the spec branch and opens the draft PR |

Everything else in the informal spec's list (Jira/Confluence MCP tokens, Jenkins
API token, kubeconfig paths) is absent. This repo's `opencode.json` has **no
`mcp` section at all** — only `agent.<name>.model` pins — so no MCP server is
declared in-repo; `okf/mcp-server-connection.md` is the runbook for how a child
repo adds one.

### Live defect the hardcoded-secrets check must also fix

`okf/mcp-server-connection.md:79` contains a literal credential-style value:
`export GITHUB_TOKEN=ghp_...`. This is exactly the defect class AC-004 exists to
prevent, sitting in the tree today. It is outside the four scan dirs the
informal spec names (`agents/`, `commands/`, `scripts/`, `docs/`), so the check
will not enforce its removal — Task 5 therefore also rewrites that line to the
placeholder form, and §Open questions asks whether `okf/` should join the scan
scope.

### Repo facts the tasks must respect

- **`.gitignore`** (22 lines): ignores `.env`, `.env.local`, `.serena/`, and
  `specs` — but **no `config/` rule and no `agent.local.env` pattern**. A rule
  for `config/agent.local.env` must be added (Task 2). `config/` does not exist
  as a directory today; Task 1 creates it.
- **No `hooks/` dir, no `hooks.json`.** Local-hook convention documented at
  `docs/GIT_WORKFLOW.md:204-214`: `.githooks/` + `git config core.hooksPath
  .githooks`, with `SKIP_HOOKS=1` as the escape hatch (`docs/GIT_WORKFLOW.md:256-258`).
  Child repos get `make hooks-install` (`templates/Makefile.bridge:15`,
  `language-specific/go/SKILL.md:26`). This repo ships no hook files.
- **`.github/workflows/self-ci.yml`** — one `validate` job on push/PR with
  steps: CRLF check on committed blobs, `bash -n` over all `*.sh`, `make
  validate-all`, `make lint`, shellcheck (continue-on-error), scoped YAML
  syntax check. New shell scripts are automatically covered by the `bash -n`
  step; new gates need an explicit step. `permissions: contents: read` — no
  secrets available in the job, which is fine: the guards are pure-path/grep
  checks.
- **`Makefile`** root targets: `validate`, `validate-docs`, `validate-refs`,
  `validate-all`, `lint`, `format`, `stats`. No `hooks-install` at root (only in
  `templates/Makefile.bridge`).
- **Script house style** (`scripts/check-scenario-traceability.sh`,
  `scripts/detect-saga-outbox.sh`, `scripts/init-ci.sh`): `#!/bin/bash`,
  `set -euo pipefail`, boxed or em-dash header comment with usage + exit codes,
  colored `fail()`/`pass()` or `err()`/`ok()` helpers, `# ──` section
  separators, no new dependencies (bash + `grep`/`sed`/`awk`/`mktemp`, all
  present in the self-ci `ubuntu-latest` image).

## Tasks

### Task 1 — `config/agent.local.env.example`: committed template, placeholder per credential, comment per variable

Create `config/` and a committed `config/agent.local.env.example`.

Acceptance criteria:
- One `KEY=value` line per credential, value a placeholder (`<...>` form), with
  a comment line directly above it explaining what the credential is, which
  agent/tool consumes it, and how to create it.
- Enumerates exactly the two real credentials:
  - `GITHUB_TOKEN=<your-github-personal-access-token>` — GitHub MCP server +
    `gh`; fine-grained PAT with `repo` scope.
  - `GH_TOKEN=<your-github-personal-access-token>` — `gh` CLI /
    release-automation alternative.
- Header comment block states: copy this file to `config/agent.local.env`,
  fill in real values, never commit the real file (guard + gitignore enforce
  this).
- No invented credentials (no Jira/Confluence/Jenkins/kubeconfig lines).

Scenarios: `20-acceptance/AC-013-01-template.md`

### Task 2 — `.gitignore` rule keeping the real file out of every commit

Add a rule so `config/agent.local.env` can never be committed.

Acceptance criteria:
- `.gitignore` gains an entry matching `config/agent.local.env` (exact path or
  `config/agent.local.env` — enough that `git check-ignore
  config/agent.local.env` exits 0 even when the file does not exist on disk).
- The committed `.example` is **not** ignored (it must stay trackable).

Scenarios: `20-acceptance/AC-013-02-guard-gitignore.md`

### Task 3 — `scripts/load-env.sh` (+ `scripts/load-env.ps1` twin)

A model-free bash loader that sources the real file and exports its variables;
fails loudly when the real file is missing but the example exists.

Acceptance criteria:
- If `config/agent.local.env` exists: source it and export every variable it
  defines (`set -a; source; set +a`). **Pre-existing exported variables are not
  clobbered** — a value already in the environment wins, so a machine-level
  override survives.
- If the real file is missing **but** `config/agent.local.env.example` exists:
  print a loud error to stderr naming the missing path and the copy-fill step,
  exit 1. This is the "fails loudly" requirement.
- If both files are missing: no-op, exit 0 (a repo with nothing configured runs
  fine).
- Bash-only, no new dependencies; runs from any cwd (resolve paths relative to
  the script's own location or the caller's repo root, documented in the
  header).
- `scripts/load-env.ps1` twin with the same behavior contract (source real file,
  export vars, fail loudly when real missing + example present, no-op when both
  missing, do not clobber pre-set vars). The self-ci `ubuntu-latest` image has
  no PowerShell, so the `.ps1` is **not executed in CI** — its acceptance is
  existence + a documented parity contract, and the `.sh` selftest asserts the
  `.ps1` file exists.

Scenarios: `20-acceptance/AC-013-03-loader.md`

### Task 4 — `scripts/guard-env.sh`: refuse to commit the real env file

A standalone bash guard that exits non-zero if the real env file is in the set
of files being committed. This is the enforcement point of record (self-ci) and
the file child repos wire into `.githooks/pre-commit` per
`docs/GIT_WORKFLOW.md` §Git Hooks.

Acceptance criteria:
- Default mode (CI): scans `git ls-files` — exits 1 with a message naming the
  offending path if `config/agent.local.env` is tracked (a forced-add or a
  previously-committed real file). Exits 0 otherwise.
- `--staged` mode (pre-commit hook): scans `git diff --cached --name-only
  --diff-filter=ACMRT` instead — exits 1 if the real file is staged.
- Clean repo (no real file in the scanned set): exit 0, brief PASS line.
- Model-free, no new dependencies. Works against a scratch repo in `/tmp` when
  the caller sets `GIT_DIR`/`--git-dir` (needed so the selftest can exercise
  both modes without touching this repo).

Scenarios: `20-acceptance/AC-013-02-guard-gitignore.md`

### Task 5 — `scripts/check-no-hardcoded-secrets.sh`: grep check over agents/, commands/, scripts/, docs/

A bash check, exit 1 on a match, proving AC-004 (no hardcoded credential value
in the four dirs). Also fixes the one live literal found in the tree.

Acceptance criteria:
- Greps `agents/`, `commands/`, `scripts/`, `docs/` for two classes of
  credential-looking content:
  1. Well-known token prefixes: `ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`,
     `github_pat_`, `AKIA` (AWS), `xox[baprs]-` (Slack), `sk-[A-Za-z0-9]{20,}`
     (OpenAI-style).
  2. Secret-style assignments whose right-hand side is not a placeholder or a
     variable reference: `^(export )?[A-Z0-9_]+(TOKEN|SECRET|KEY|PASSWORD|CREDENTIAL)=`
     with an RHS that is not empty and does not start with `${`, `<`, `"`, or `'`
     and is not the literal word `PLACEHOLDER`/`YOUR_`.
- Prints each match with file:line; exits 1 if any match, 0 if clean.
- **Self-trip constraint**: the check's own selftest lives under `scripts/` and
  is in scan scope — its fixture values must be constructed so they do **not**
  literally match the patterns (string concatenation at runtime, e.g.
  `TOK="ghp_""${RANDOM}"`, or fixture dirs built in `mktemp -d`, never inline
  literals). A literal fixture in the selftest would fail the check it proves.
- Fix the live literal: rewrite `okf/mcp-server-connection.md:79` from
  `export GITHUB_TOKEN=ghp_...` to the placeholder form
  (`export GITHUB_TOKEN=<your-github-personal-access-token>`). The check does
  **not** scan `okf/` (informal spec scope is the four dirs; okf inclusion is an
  open question), so this is a one-time cleanup, not a new enforcement surface.
- Model-free: bash + `grep`, no new dependencies.

Scenarios: `20-acceptance/AC-013-04-no-hardcoded-secrets.md`

### Task 6 — Agent cross-references: credentials read via the loader, never literals

The informal spec's "Cross-references" requirement: agents that need a
credential read it through the loader, never via a literal in a prompt or
script.

Acceptance criteria:
- `agents/spec-pr-opener.md` (the only agent that pushes and opens a PR) gains
  an explicit step: source `scripts/load-env.sh` before committing/pushing, and
  use `$GITHUB_TOKEN` / `$GH_TOKEN` from the environment — never a literal.
- `agents/spec-pipeline.md` documents that the shell it runs in already has the
  env loaded per the per-machine setup (AGENTS.md), so the pipeline needs no
  per-agent sourcing beyond the PR Opener's defensive one.
- `commands/spec.md` / `commands/build.md` unchanged unless they reference a
  credential literal (verified: they do not) — but a one-line pointer to the
  loader is acceptable.
- No literal credential value appears in any touched agent/command file (the
  Task 5 check enforces this over the same dirs).

Scenarios: `20-acceptance/AC-013-06-agent-crossrefs.md`

### Task 7 — Per-machine setup documented in AGENTS.md or README

The informal AC-005: how a developer sets up their machine.

Acceptance criteria:
- A "Per-machine agent environment" section in **either** `AGENTS.md` or
  `README.md` (pick the one that reads best; both may reference it) that walks:
  `cp config/agent.local.env.example config/agent.local.env` → fill real values
  → never commit (gitignored + guard) → `source scripts/load-env.sh` in the
  shell where `/spec` / `/build` run. Also mention `.ps1` twin for Windows
  shells.
- The section names the two credentials and their purpose (`GITHUB_TOKEN`,
  `GH_TOKEN`).
- The section links the guard (`scripts/guard-env.sh`) and the
  hardcoded-secrets check (`scripts/check-no-hardcoded-secrets.sh`) as the
  enforcement that makes the "never commit" instruction structural.

Scenarios: `20-acceptance/AC-013-05-per-machine-docs.md`

### Task 8 — Wire the gates + one selftest into `.github/workflows/self-ci.yml`

Make the enforcement real: both guard checks run on every push/PR, and a
selftest proves the three new behavior scripts actually fire.

Acceptance criteria:
- A new step in the existing `validate` job runs:
  `bash scripts/guard-env.sh` and `bash scripts/check-no-hardcoded-secrets.sh`
  in a single `run:` block. Either exiting non-zero fails the job (no
  `continue-on-error`). These run **after** the implementation files exist, so
  the working tree's four dirs are scanned.
- `scripts/agent-env.selftest.sh` — one model-free selftest (fixtures in
  `mktemp -d`, `trap` cleanup, no inline literals per Task 5's self-trip
  constraint) proving:
  - loader: example-only → exit 1 + loud message; real present → exports vars;
    both missing → exit 0; pre-set var not clobbered; `.ps1` exists.
  - guard: staged real file in a scratch repo → exit 1 (`--staged`);
    tracked real file in a scratch repo → exit 1 (default/CI mode); clean
    scratch repo → exit 0.
  - hardcoded-secrets: a fixture dir with a literal `ghp_…` and a
    `GITHUB_TOKEN=ghp_…` assignment → exit 1; clean scanned dirs → exit 0
    (verified against the real four dirs before wiring, since they must already
    be clean).
  - The selftest step runs in the same `run:` block (or the next step) and
    fails the job on regression. Shellcheck's existing `scripts/*.sh` glob picks
    up the new scripts (unchanged continue-on-error behavior); the `bash -n`
    step covers parse.
- The self-ci `permissions: contents: read` is unchanged — none of this needs a
  token.

Scenarios: folded into `AC-013-02-guard-gitignore.md`,
`AC-013-03-loader.md`, `AC-013-04-no-hardcoded-secrets.md` (one "wired into
self-ci" scenario per behavior file, mirroring `AC-012-03-selfci-wiring.md`).

## Acceptance criteria mapping

| Informal AC | Task(s) | Scenario file |
|---|---|---|
| AC-001 `config/agent.local.env.example` exists, committed, placeholder + comment per credential | 1 | `AC-013-01-template.md` |
| AC-002 real file gitignored; gate script exits non-zero if real env file is staged/committed | 2 + 4 (+ 8 wiring) | `AC-013-02-guard-gitignore.md` |
| AC-003 `load-env.sh` sources real file, exports vars, errors when real absent + example present | 3 (+ 8 selftest) | `AC-013-03-loader.md` |
| AC-004 no hardcoded credential value in agents/, commands/, scripts/, docs/ (grep, exit 1) | 5 (+ 8 wiring) | `AC-013-04-no-hardcoded-secrets.md` |
| AC-005 AGENTS.md / README documents per-machine setup | 7 | `AC-013-05-per-machine-docs.md` |
| (informal "What it must provide" → Cross-references) agents read credentials via loader, never literals | 6 | `AC-013-06-agent-crossrefs.md` |

## Open questions (need a human answer before /build)

1. **`hooks.json` premise is false.** The informal spec references a
   `hooks.json` with `guard-java-home`/`guard-commit-msg`; no such file exists
   in this repo. Resolution chosen here: guard as a standalone script + self-ci
   gate as the enforcement point of record, child repos wire it into `.githooks`
   per `docs/GIT_WORKFLOW.md`. Confirm this is acceptable rather than shipping
   new hook files this repo has never had.
2. **Credential scope narrowed.** The informal spec lists Jira/Confluence MCP
   tokens, a Jenkins API token, and kubeconfig paths. None exist in this repo;
   the template enumerates only `GITHUB_TOKEN` and `GH_TOKEN`. If you run the
   pipeline against an Atlassian-backed project, add an `ATLASSIAN_TOKEN` (or
   similar) placeholder to the template then — it does not belong in this repo
   now.
3. **Should `okf/` join the AC-004 scan scope?** `okf/mcp-server-connection.md:79`
   had a literal `GITHUB_TOKEN=ghp_...` (rewritten to a placeholder in Task 5),
   but the check itself scans only the four dirs the informal spec names. If
   okf/ should be enforced too, say so — Task 5's scan list is one line.
4. **Loader clobber policy.** Chosen: pre-existing exported variables win (a
   machine override survives sourcing). The alternative (file always wins, the
   acdc-civ default) is a one-line difference — confirm which you want.
5. **`.ps1` twin is not CI-executable** on the `ubuntu-latest` self-ci image
   (no PowerShell). Its acceptance is existence + a documented parity contract,
   not an executed test. Acceptable, or should self-ci install PowerShell?

## Acceptance scenarios

## AC-013-01-01 — The template file exists and is committed
## AC-013-01-02 — Every credential has a placeholder value and a comment
## AC-013-01-03 — The template enumerates exactly the real credentials
## AC-013-01-04 — The template header states the per-machine copy-fill workflow
## AC-013-02-01 — The real env file path is gitignored
## AC-013-02-02 — The guard exits non-zero when the real file is staged
## AC-013-02-03 — The guard exits non-zero when the real file is tracked (CI mode)
## AC-013-02-04 — The guard exits 0 on a clean repo
## AC-013-02-05 — The guard runs in self-ci and a violation fails the job
## AC-013-02-06 — The selftest proves the guard fires, and runs in self-ci
## AC-013-03-01 — Fails loudly when the real file is missing but the example exists
## AC-013-03-02 — Sources the real file and exports every variable
## AC-013-03-03 — Quiet no-op when both files are missing
## AC-013-03-04 — Does not clobber pre-existing exported variables
## AC-013-03-05 — The `.ps1` twin exists with a documented parity contract
## AC-013-04-01 — A literal token prefix in a scanned dir fails the check
## AC-013-04-02 — A secret-style assignment with a literal value fails the check
## AC-013-04-03 — Clean scanned dirs pass; placeholders and variable references do not trip
## AC-013-04-04 — The check runs in self-ci and a violation fails the job
## AC-013-04-05 — The selftest proves the check fires, without tripping it
## AC-013-05-01 — The setup walk-through is documented
## AC-013-05-02 — The section names the real credentials and the enforcement
## AC-013-06-01 — The PR Opener sources the loader before committing and pushing
## AC-013-06-02 — The orchestrator documents that the running shell has the env loaded
## AC-013-06-03 — No literal credential value appears in any agent or command file

## Verification

# Verification — spec 013: Agent local environment (secrets per machine)

- Stage: 4 (Verifier) — `agents/spec-verifier.md`
- Branch: `spec/013-agent-local-env`
- Verified against: `specs/013-agent-local-env/10-tasks.md`, `specs/013-agent-local-env/20-acceptance/*.md`
- `00-informal.md` was not read (information barrier).
- Date: 2026-08-15

Every check below is a real execution with its real exit code / output, not a
paraphrase of a prior stage's report.

---

## 1. Scenario traceability — PASS (spec 013 scope clean)

Command: `bash scripts/check-scenario-traceability.sh`

Full-repo run: **exit 1**, 125 violations. As anticipated for a mid-pipeline
state, every violation is outside spec 013:

- Untraced scenarios in sibling in-flight specs: AC-007..012, AC-014, AC-015,
  AC-017..019 (`specs/*/20-acceptance/` present, no test cites them yet).
- Stale test references to archived spec IDs: AC-001..006, AC-016, AC-020..022
  (tests cite IDs whose scenario headings no longer exist — archived specs'
  citations, per the known condition).

Spec-013 scoped result (grep of the script's output for `AC-013`):

```
PASS AC-013-01 — traced to a test
PASS AC-013-02 — traced to a test
PASS AC-013-03 — traced to a test
PASS AC-013-04 — traced to a test
PASS AC-013-05 — traced to a test
PASS AC-013-06 — traced to a test
```

Both directions checked:

- Every `## AC-013-NN` heading (25 sub-scenarios across 6 files) is exercised by
  `scripts/agent-env.selftest.sh` (AC-013-01-01..01-04, 02-01..02-05,
  03-01..03-05, 04-01..04-05, 05-01..05-02, 06-01..06-03 — all present in the
  selftest as PASS/FAIL cases).
- Zero dangling AC-013 references: grep of every AC-013-NN citation across the
  tree (`scripts/`, `docs/`, `.github/`) shows citations only in
  `agent-env.selftest.sh`, `10-tasks.md`, and the acceptance files — none
  reference a non-existent heading, none cite an ID the selftest lacks.

Judgement: **AC-013 scope is clean.** The full-repo exit 1 is entirely
attributable to sibling/archived specs, not to spec 013.

## 2. Full relevant suite — PASS

| Command | Exit | Result |
|---|---|---|
| `bash -n scripts/load-env.sh` | 0 | parses |
| `bash -n scripts/guard-env.sh` | 0 | parses |
| `bash -n scripts/check-no-hardcoded-secrets.sh` | 0 | parses |
| `bash -n scripts/agent-env.selftest.sh` | 0 | parses |
| `bash scripts/agent-env.selftest.sh` | **0** | **28 passed, 0 failed** (`selftest: 28 passed, 0 failed` / `✔ agent-env.selftest: all cases pass.`) |
| `bash scripts/guard-env.sh` (real repo, CI mode) | 0 | `PASS guard-env: no config/agent.local.env in the scanned set (tracked mode).` |
| `bash scripts/check-no-hardcoded-secrets.sh` (real repo) | 0 | `PASS check-no-hardcoded-secrets: no hardcoded credential values in agents/, commands/, scripts/, docs/.` |
| `scripts/check-orchestration.sh` | 0 | `All orchestration references valid.` |
| `bash scripts/check-model-env.sh` | 0 | `PASS check-model-env: all model values are {env:SPEC_*_MODEL} references, no tracked real env file, example wired.` (file is mode 644 — pre-existing from spec 020, invoked via `bash`; not in spec-013 scope) |
| `bash scripts/model-env.selftest.sh` | 0 | 30 passed, 0 failed |
| `make validate-all` | 0 | `All validations passed.` (1 WARN: `skills/hallmark/SKILL.md` body 562 lines — pre-existing, unrelated) |
| `make lint` | 0 | `Done.` |

Selftest parse caveat caught and re-run correctly: `bash -n f1 f2 ...` only
syntax-checks the **first** argument, so the initial 5-file batch exit 0 was a
false green for files 2–5. Re-ran per-file (as self-ci's `find -name '*.sh'`
loop does) — all four new `.sh` files parse cleanly, each exit 0.

`scripts/load-env.ps1` is PowerShell, not bash: `bash -n` errors on its
`param(` (line 22) — **expected and correct**. self-ci's `bash -n` step globs
only `*.sh` (`.github/workflows/self-ci.yml:58`), so the `.ps1` is out of parse
scope by design; its acceptance per Task 3 / AC-013-03-05 is existence + a
documented parity contract, both satisfied (selftest asserts existence and the
header's parity terms: no-op, clobber, load-env.sh).

**self-ci wiring** — `.github/workflows/self-ci.yml` parses as YAML (PyYAML,
`jobs: ['validate']`), and the new step exists:

```yaml
- name: Check agent env guard and hardcoded secrets
  run: |
    set -euo pipefail
    bash scripts/guard-env.sh
    bash scripts/check-no-hardcoded-secrets.sh
    bash scripts/agent-env.selftest.sh
```

No `continue-on-error` on the new step (the only `continue-on-error: true` in
the job is the pre-existing shellcheck step, line 118). The step sits after the
implementation files and after the model-env step — runs on the working tree's
four scanned dirs as Task 8 requires.

## 3. Complexity gate — PASS

No bash complexity linter exists in this repo (shellcheck is the only shell
tool and is not a complexity gate); the complexity claim is therefore
spot-checked by counting decision points (`if/elif/for/while/case`, the same
heuristic `check-code-principles.sh` uses) in the current files:

| Function | Refactorer claim | Measured (current) |
|---|---|---|
| `guard_env_main` (guard-env.sh) | 8 → 5 | **5** (for, case, if -z, if MODE, if grep) |
| `load_env_main` (load-env.sh) | 7 → 3 + 5 | **3** (if -z root, if real, elif example) |
| `_load_env_export` (load-env.sh) | (part of 3+5) | **5** (while, case x3, if) |
| `scan_root` (check-no-hardcoded-secrets.sh) | max 6 | **5** (for, if -d, while x3, if) |
| `is_ignored_rhs` / `report_hit` | — | **1 / 0** |

Every function is ≤6. The pre-refactor values (8, 7) are **not independently
verifiable** — all scripts are new/untracked files on this branch, so no git
history of an earlier form exists. The current values match the claimed
post-refactor numbers exactly and satisfy the ≤6 rule, which is the gate that
matters. Selftest "untouched": also not verifiable from git (new file); the
28/28 green run above is the operative evidence.

## 3.5. Design-principles gate — PASS (no finding attributable to spec 013)

Command: `bash scripts/check-code-principles.sh` (default mode, repo root)

**Exit code: 1** — pre-existing state, 5 FAILs / 17 WARNs, **every line confined
to `ci/templates/*`**. FAIL lines, verbatim:

```
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:CC=14
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:CC=10
FAIL Cyclomatic complexity >6 (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:CC=8
FAIL Cyclomatic complexity >6 (node): ./ci/templates/eslint-saga-rules/saga-compensation.js:56:getSagaStepOptions:CC=7
```

WARN lines, verbatim (all `ci/templates/*`, abbreviated to first occurrence —
full list is 17 lines):
```
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:main:KISS_LINES=28
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:checkCompensationPairs:KISS_LINES=59
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:163:checkOutboxCoLocation:KISS_LINES=42
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:207:checkSagaHandlerContext:KISS_LINES=38
WARN Method body >20 lines (go): ./ci/templates/go-saga-lint.go:275:resolveDirs:KISS_LINES=31
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:155): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:112): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:129): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:156): ...
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/go-saga-lint.go:104): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:130): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:198): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:199): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/go-saga-lint.go:197): ...
WARN Possible duplication (2x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:132): ...
WARN Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
WARN Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```
Summary line, verbatim: `✘ Design-principles check: 5 FAIL(s), 17 WARN(s).`

Scope note: the gate scans `.java/.go/.ts/.tsx/.js/.jsx` only — spec 013's
changed files are bash scripts, markdown, YAML, gitignore, and a `.env.example`
template, none of which the gate scans. A scoped run `bash
scripts/check-code-principles.sh scripts` exits **0** with no output (no
scanned-language files in scripts/). **No FAIL or WARN is attributable to spec
013.** The exit-1 root state is the documented pre-existing `ci/templates/*`
noise; flagged to the Architect as known/pre-existing, not a spec-013 defect.

Property-test tier: gate tier auto-detection finds **no `AGENTS_*.md`** at the
repo root (verified: `ls AGENTS_*.md` → not found), so no property-test check
applies — consistent with the mvp-tier claim (see §6).

## 4. Scenario-to-behavior spot check — PASS

Two scenarios manually executed against scratch trees in `/tmp` (independent of
the selftest, cleaned up after):

**AC-013-03-01 — loader fails loudly (example present, real missing):**
```
$ bash scripts/load-env.sh <scratch-only>
rc=1
stderr: ERROR: <scratch>/config/agent.local.env not found, but <scratch>/config/agent.local.env.example exists. Copy it and fill in real values:
  cp config/agent.local.env.example config/agent.local.env
```
Exit 1, names the missing path, prints the copy-fill step — matches the
Given/When/Then exactly.

**AC-013-02-02 — guard refuses a staged real file:**
```
$ printf 'GITHUB_TOKEN=rt-123\n' > <scratch>/config/agent.local.env
$ git -C <scratch> add config/agent.local.env
$ bash scripts/guard-env.sh --staged <scratch>
FAIL guard-env: config/agent.local.env is staged — the real env file must never be committed. Unstage it (git reset config/agent.local.env) before committing.
rc=1
```
Exit 1, names the offending path `config/agent.local.env` — matches. Clean
scratch repo → `PASS guard-env: no config/agent.local.env in the scanned set
(staged mode).`, rc=0 (AC-013-02-04).

Additional behaviors exercised (supporting scenarios AC-013-03-03/04,
AC-013-04-01/02, AC-013-02-01, Task 5's live fix):

- **No clobber (AC-013-03-04):** `export GITHUB_TOKEN=already-set` then source
  a fixture real file defining `GITHUB_TOKEN=file-value` → resulting env keeps
  `already-set`. Matches the scenario's "pre-existing exported variables are
  never clobbered". (Edge note, not a failure: the no-clobber test uses
  `${!var:-}`, so an *empty-but-exported* var would be refilled from the file —
  no scenario covers an empty pre-set; behavior is consistent with the model
  loader's empty-falls-through precedence.)
- **Both files missing (AC-013-03-03):** rc=0, 0 bytes on stderr.
- **Secrets check flags literals (AC-013-04-01/02):** fixture `agents/leak.txt`
  containing `GITHUB_TOKEN=ghp_abc123xyz` → exit 1, output prints
  `agents/leak.txt:1` twice (literal token prefix + secret-style assignment),
  summary `✘ check-no-hardcoded-secrets: 2 violation(s)`. Real repo → exit 0.
- **okf literal rewritten (Task 5):** `okf/mcp-server-connection.md:79` now
  reads `export GITHUB_TOKEN=<your-github-personal-access-token>` — the
  literal `ghp_...` is gone (verified by grep of the file).
- **.gitignore (AC-013-02-01):** `git check-ignore config/agent.local.env` →
  exit 0 (ignored, file absent on disk); `git check-ignore
  config/agent.local.env.example` → exit 1 (not ignored, trackable).
- **Template (AC-013-01):** `config/agent.local.env.example` exists; exactly
  two `KEY=value` lines (`GITHUB_TOKEN`, `GH_TOKEN`), both `<...>` placeholders
  with a comment line directly above each; header states
  copy → fill → never commit (confirmed by read + selftest AC-013-01-01..04).
- **Docs (AC-013-05, AC-013-06):** AGENTS.md §Per-machine agent environment
  walks copy/fill/source/never-commit, names both tokens + both enforcement
  scripts; `agents/spec-pr-opener.md` gains the defensive `source
  scripts/load-env.sh` step with `$GITHUB_TOKEN`/`$GH_TOKEN` from the
  environment; `agents/spec-pipeline.md` documents the pre-loaded shell
  (confirmed by read + selftest).

## 5. No unaccounted behavior — PASS

Diff skim (6 modified files + 5 new files). Every change traces to a task:

| Change | Task |
|---|---|
| `.github/workflows/self-ci.yml` — new validate step (guard + secrets + selftest, no continue-on-error) | Task 8 |
| `.gitignore` — `config/agent.local.env` rule | Task 2 |
| `AGENTS.md` — §Per-machine agent environment | Task 7 |
| `agents/spec-pipeline.md` — pre-loaded shell note | Task 6 |
| `agents/spec-pr-opener.md` — defensive loader sourcing | Task 6 |
| `okf/mcp-server-connection.md:79` — placeholder rewrite | Task 5 |
| `config/agent.local.env.example` (new) | Task 1 |
| `scripts/load-env.sh`, `scripts/load-env.ps1` (new) | Task 3 |
| `scripts/guard-env.sh` (new) | Task 4 |
| `scripts/check-no-hardcoded-secrets.sh` (new) | Task 5 |
| `scripts/agent-env.selftest.sh` (new) | Task 8 |

No orphan logic found. The two script-level design choices (no-clobber via
`${!var:-}`, guard `ROOT` positional arg for scratch-repo testing) are exactly
the mechanisms Task 3/Task 4 specify. Self-trip constraint verified: grep for
the literal token patterns in `agent-env.selftest.sh` and
`check-no-hardcoded-secrets.sh` finds nothing (fixtures built via `GHP="ghp""_"`
concatenation and `mktemp -d`), and the check passes over the real `scripts/`
dir — the selftest does not trip the check it proves (AC-013-04-05).

## 6. mvp-tier claim — CONFIRMED

No `AGENTS_*.md` exists at the repo root (`ls AGENTS_*.md` → not found). The
design-principles gate's tier auto-detection therefore applies no
property-test check, and the mvp-tier skips (no property-test gate, no
Architect mutation gate) per `docs/SPEC_PIPELINE.md` §Conformance tiers are
correct.

---

## Overall verdict: **PASS**

Every spec-013 check is green:

1. Traceability — AC-013-01..06 all traced, zero dangling refs (full-repo exit 1
   is entirely sibling/archived-spec noise).
2. Suite — selftest 28/28 exit 0; guard exit 0; secrets check exit 0;
   orchestration exit 0; model-env check + selftest exit 0; `make validate-all`
   exit 0; `make lint` exit 0; self-ci YAML parses with the new step, no
   continue-on-error.
3. Complexity — all new functions ≤6; measured values match the claimed
   post-refactor numbers (5 / 3+5 / max 5).
3.5. Design-principles gate — exit 1 from the pre-existing `ci/templates/*`
   FAILs/WARNs only; zero findings attributable to spec 013 (bash + docs out of
   the gate's language scope; `scripts`-dir scoped run exits 0).
4. Scenario-to-behavior — loader fail-loud, no-clobber, both-missing, guard
   `--staged`, secrets literal detection, okf rewrite, gitignore coverage all
   confirmed by manual execution.
5. No unaccounted behavior — every diff hunk traces to Tasks 1–8.
6. mvp-tier claim confirmed (no `AGENTS_*.md`), so the property-test/mutation
   skips are correct.

Architect may proceed. Flagged as review hints only (not failures): (a) the
root design-principles exit 1 is pre-existing `ci/templates/*` debt, already
known; (b) `scripts/check-model-env.sh` is mode 644 and must be invoked via
`bash` (pre-existing, spec 020); (c) load-env no-clobber treats empty pre-set
vars as unset (uncovered edge, consistent with existing precedence).

## Quality gates

# Mutation Runner report — spec 013: Agent local environment (secrets per machine)

- Stage: 5a (Mutation Runner) — `agents/spec-mutation-runner.md`
- Branch: `spec/013-agent-local-env`
- Date: 2026-08-15
- `00-informal.md` was not read (information barrier).

## Verifier verdict (carried forward)

**PASS** — `specs/013-agent-local-env/25-verification.md` exists and its verdict
is PASS. All spec-013 checks green: traceability (AC-013-01..06), full relevant
suite, complexity ≤6, design-principles gate (no spec-013 finding), scenario
spot checks, no unaccounted behavior, mvp-tier claim confirmed.

## Mutation score

**skipped — mvp tier**

This repo is `mvp` conformance tier (no `AGENTS_*.md` at repo root). Per
`docs/SPEC_PIPELINE.md` §Conformance tiers, mutation testing is a
`production`-tier gate and is skipped at `mvp`. No mutation tooling was run.

## Complexity summary (carried from the Refactorer, re-measured by the Verifier)

| Function | Complexity | Gate (≤6) |
|---|---|---|
| `guard_env_main` (scripts/guard-env.sh) | 5 | pass |
| `load_env_main` (scripts/load-env.sh) | 3 | pass |
| `_load_env_export` (scripts/load-env.sh) | 5 | pass |
| `scan_root` (scripts/check-no-hardcoded-secrets.sh) | 5 | pass |
| `is_ignored_rhs` / `report_hit` | 1 / 0 | pass |

All new functions ≤6. Changed code is bash + markdown + workflow YAML — out of
the design-principles gate's language scope; scoped `scripts/` run exits 0.

## Equivalent mutants

**None.** No mutation tooling ran (mvp tier), so no mutants were generated and
no equivalents were encountered.

## Final test status — GREEN

Re-run after the Verifier's PASS (this stage writes no test code, but the full
suite is re-confirmed per pipeline discipline):

| Check | Result |
|---|---|
| `bash -n` per-file (load-env.sh, guard-env.sh, check-no-hardcoded-secrets.sh, agent-env.selftest.sh) | 4/4 parse, rc 0 |
| `bash scripts/agent-env.selftest.sh` | **28 passed, 0 failed**, rc 0 |
| `bash scripts/guard-env.sh` | PASS, rc 0 |
| `bash scripts/check-no-hardcoded-secrets.sh` | PASS, rc 0 |
| `scripts/check-orchestration.sh` | All orchestration references valid, rc 0 |
| `bash scripts/check-model-env.sh` | PASS, rc 0 |
| `make validate-all` | All validations passed, rc 0 (1 pre-existing WARN: skills/hallmark/SKILL.md body 562 lines — unrelated) |

Spec 013 is finished. Handing off to stage 5b (PR Opener).
