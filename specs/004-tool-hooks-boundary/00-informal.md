# 004 — Tool hooks: gate every bash and edit

## Why

The spec pipeline has no per-tool guards today. An agent can edit a file
outside its plan and the diff goes out. An agent can `git push` from
`main` and skip the `spec/NNN-slug` convention. An agent can skip a build
check between commits and CI only catches the failure later.

Reference: ACDC solves this with `hooks.json`
(`preToolUse`/`postToolUse` matchers wired to the harness) plus a
`pre-push` Git hook that runs the fast gate subset before push. The
harness from Phase B already exists by the time this lands.

This is **Phase C**. It depends on Phase B (the gate-runner must exist
before the hook can call it).

## What I want

A new `agents/hooks/` directory containing:

- `hooks.json` — `preToolUse` matcher `bash|powershell` → guard calls
  `scripts/gates/find-harness.sh` then `gate-runner.sh -Phase local
  -Gates G0,G6,S1` on each shell-out, BLOCK on failure. `postToolUse`
  matcher `edit|create` → format-guard (delegates to the project's own
  format command; soft WARN if absent).
- `pre-push` — Git hook that runs
  `gate-runner.sh -Phase local -Gates G0,G1,G6,S1` on the spec branch.
  Aborts the push on BLOCK. Activated via
  `git config core.hooksPath agents/hooks`.
- `commit-msg` — validates Conventional Commits prefix on `spec/*`
  branches. Bypassable via `git commit --no-verify` (logged, not
  blocked).
- `find-harness.sh` + `format-guard.sh` — local copies that delegate to
  `scripts/gates/` so the hooks resolve the same way everything else
  does.

Plus an `init-ci.sh --with-hooks` flag for child repos: copies the hooks
into the child repo's `agents/hooks/`, sets `core.hooksPath`.

Every hook is wrapped in a soft-fail pattern (`sh -c '[ -f "$0" ] ||
exit 0; sh "$0"'`) so a partial install never breaks an agent tool call.

## What I don't want

- Any change to existing `.git/hooks/*`. The new hooks live under
  `agents/hooks/` and are activated via `core.hooksPath`.
- A `[JIRA-ID]` prefix in `commit-msg` — this repo has no Jira
  convention.
- Hook enforcement on `main`/`develop`. Spec pipeline agents are the
  only intended consumers.
- Cross-tool wiring beyond `bash|powershell|edit|create`. Future tools
  (file search, network) are out of scope.

## Out of scope

- Changes to any agent spec (those are Phase D).
- New gate implementations (Phase B).

## How child repos will use this

`init-ci.sh --with-hooks` installs them. A child repo that does not run
init-ci.sh will still vendor the files (submodule bump), but no hook
fires. Activation is opt-in.

## Dependency

Phase B's `scripts/gates/` exists before this lands.
