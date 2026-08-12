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
