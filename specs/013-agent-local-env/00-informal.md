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
