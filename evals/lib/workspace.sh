#!/bin/bash
# workspace.sh — throwaway standalone eval workspaces and probe setup.
#
# The oracle's workspace is a standalone `git init` repository under a
# `mktemp -d` root. The runner's agent workspace is a detached `git worktree`
# whose parent is a *scratch* repository created under the same temp root — not
# the source repository. Either way the workspace has no shared common
# directory with the source, no inherited `origin`, and no `git rev-parse
# --git-common-dir` path back to the source. `make_workspace` copies a task's
# environment into the standalone repository and commits a baseline, so probe
# setup and verifiers see a stable HEAD count; `init_scratch_repo` seeds the
# runner's scratch parent the same way.
#
# `apply_probe_setup` creates the local bare remote, captures the baseline
# refs, checks out the probe branch, and exports the probe's environment
# deltas. `snapshot_repo_state` captures a byte-comparable view of a repository
# so the runner can prove the agent never mutated the source tree.
# `destroy_workspace` removes the whole temp root.

# init_git_workspace <dest> [detach] — make <dest> a standalone repository with
# a baseline commit. `detach` leaves HEAD detached so the workspace branch state
# does not leak into a probe.
init_git_workspace() {
  local dest="$1" detach="${2:-}"
  # Always start from a fresh repository: a fixture that shipped a `.git`
  # directory (or a worktree pointer) must not inherit remotes or a common dir.
  rm -rf "$dest/.git"
  git -C "$dest" init -q
  git -C "$dest" config user.email "eval@example.com"
  git -C "$dest" config user.name "Eval"
  git -C "$dest" config core.autocrlf false
  mkdir -p "$dest/.git/eval-no-hooks"
  git -C "$dest" config core.hooksPath "$dest/.git/eval-no-hooks"
  git -C "$dest" add -A
  git -C "$dest" commit -q -m "eval baseline" --allow-empty
  if [ "$detach" = "detach" ]; then
    git -C "$dest" checkout -q --detach
  fi
}

# init_scratch_repo <scratch> <environment-dir> — create the standalone
# repository that parents the runner's detached worktree. It is seeded with one
# commit from the task's `environment/` and carries no remote: a fresh `git
# init` has none, and any that a copied fixture smuggled in is removed. Its
# common directory lives inside the eval temp root, so the agent's `.git` link
# can never resolve to the source repository.
init_scratch_repo() {
  local scratch="$1" environment="$2" remote
  rm -rf "$scratch"
  mkdir -p "$scratch"
  cp -a "$environment/." "$scratch/"
  init_git_workspace "$scratch"
  while remote="$(git -C "$scratch" remote 2>/dev/null | head -1)" && [ -n "$remote" ]; do
    git -C "$scratch" remote remove "$remote"
  done
}

# add_detached_worktree <scratch> <worktree> — add <worktree> as a detached
# worktree of <scratch>. The existing path must not exist: `git worktree add`
# creates it, checking out the scratch repo's baseline commit.
add_detached_worktree() {
  local scratch="$1" worktree="$2"
  git -C "$scratch" worktree add --detach "$worktree" >/dev/null
}

# make_workspace <task-dir> — sets EVAL_TMP_ROOT and EVAL_WORKSPACE.
make_workspace() {
  local task="$1"
  EVAL_TMP_ROOT="$(mktemp -d)"
  EVAL_WORKSPACE="$EVAL_TMP_ROOT/ws"
  mkdir -p "$EVAL_WORKSPACE"
  cp -a "$task/environment/." "$EVAL_WORKSPACE/"
  init_git_workspace "$EVAL_WORKSPACE"
  export EVAL_TMP_ROOT EVAL_WORKSPACE
}

# probe_setup_fields <task-dir> — evaluate the probe table into shell variables:
# EVAL_PROBE_ID, EVAL_PROBE_REMOTE, EVAL_PROBE_BRANCH, EVAL_PROBE_UNSET_ENV,
# EVAL_PROBE_ENV.
probe_setup_fields() {
  local task="$1"
  eval "$(python3 - "$task" <<'PY'
import os, shlex, sys, tomllib
task = sys.argv[1]
with open(os.path.join(task, "task.toml"), "rb") as fh:
    probe = tomllib.load(fh).get("probe", {}) or {}
unset_env = "\n".join(probe.get("unsetEnv", []) or [])
set_env = "\n".join(f"{k}={v}" for k, v in (probe.get("env", {}) or {}).items())
print("EVAL_PROBE_ID=" + shlex.quote(str(probe.get("id", ""))))
print("EVAL_PROBE_REMOTE=" + shlex.quote("true" if probe.get("remote") else "false"))
print("EVAL_PROBE_BRANCH=" + shlex.quote(str(probe.get("branch", ""))))
print("EVAL_PROBE_UNSET_ENV=" + shlex.quote(unset_env))
print("EVAL_PROBE_ENV=" + shlex.quote(set_env))
PY
)"
}

# apply_probe_setup <task-dir> <workspace> — apply the optional probe contract.
apply_probe_setup() {
  local task="$1" workspace="$2"
  probe_setup_fields "$task"

  if [ "$EVAL_PROBE_REMOTE" = "true" ]; then
    local root="${EVAL_TMP_ROOT:-$(dirname "$workspace")}"
    EVAL_REMOTE="$root/remote.git"
    rm -rf "$EVAL_REMOTE"
    git clone --bare -q "$workspace" "$EVAL_REMOTE"
    EVAL_BASELINE_HEAD_COUNT="$(git -C "$workspace" rev-list --count HEAD)"
    EVAL_REMOTE_BASELINE="$(git ls-remote "$EVAL_REMOTE" | sort)"
    git -C "$workspace" remote remove eval 2>/dev/null || true
    git -C "$workspace" remote add eval "$EVAL_REMOTE"
    export EVAL_REMOTE EVAL_REMOTE_BASELINE EVAL_BASELINE_HEAD_COUNT
  fi

  if [ -n "$EVAL_PROBE_BRANCH" ]; then
    git -C "$workspace" checkout -q -B "$EVAL_PROBE_BRANCH"
  fi

  export EVAL_PROBE_ID EVAL_PROBE_REMOTE EVAL_PROBE_BRANCH
  export EVAL_PROBE_UNSET_ENV EVAL_PROBE_ENV
}

# snapshot_repo_state <repo> — print a stable, byte-comparable snapshot of a
# repository's refs (packed, remote-tracking, and notes included), reflog,
# working-tree status (including ignored files), hooks, info/exclude, and local
# config. The runner takes it before and after a probe; any difference means the
# agent reached the source repository and the run is an environment block, never
# a pass. In the default Docker mode the source is not mounted at all, so this
# snapshot is defense in depth for the explicit `EVAL_SANDBOX=none` test mode.
snapshot_repo_state() {
  local repo="$1" gitdir hooks_path h
  printf '%s\n' '--- refs ---'
  git -C "$repo" for-each-ref --format='%(refname) %(objectname)' 2>/dev/null | sort || true
  printf '%s\n' '--- reflog ---'
  git -C "$repo" reflog --all 2>/dev/null || true
  printf '%s\n' '--- status ---'
  git -C "$repo" status --porcelain --ignored 2>/dev/null || true
  printf '%s\n' '--- config ---'
  git -C "$repo" config --local --list 2>/dev/null | sort || true
  gitdir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null || true)"
  printf '%s\n' '--- packed-refs ---'
  [ -n "$gitdir" ] && cat "$gitdir/packed-refs" 2>/dev/null || true
  printf '%s\n' '--- info-exclude ---'
  [ -n "$gitdir" ] && cat "$gitdir/info/exclude" 2>/dev/null || true
  printf '%s\n' '--- hooks ---'
  hooks_path="$(git -C "$repo" config --get core.hooksPath 2>/dev/null || true)"
  for h in "$gitdir/hooks" "$repo/$hooks_path"; do
    [ -n "$h" ] && [ -d "$h" ] || continue
    find "$h" -maxdepth 1 -type f -exec sha256sum {} + 2>/dev/null | sort || true
  done
}

# remove_eval_remote <repo> — drop an `eval` remote the harness may have left
# behind. Idempotent; used by the runner's cleanup on every exit path.
remove_eval_remote() {
  local repo="$1"
  [ -n "$repo" ] || return 0
  if git -C "$repo" remote get-url eval >/dev/null 2>&1; then
    git -C "$repo" remote remove eval >/dev/null 2>&1 || true
  fi
}

# destroy_workspace — remove the temp root make_workspace returned. Safe to
# call twice, and safe when no workspace was made.
destroy_workspace() {
  if [ -n "${EVAL_TMP_ROOT:-}" ] && [ -d "$EVAL_TMP_ROOT" ]; then
    rm -rf "$EVAL_TMP_ROOT"
  fi
}
