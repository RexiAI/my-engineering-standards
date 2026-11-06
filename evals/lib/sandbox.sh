#!/bin/bash
# sandbox.sh — run the agent under a real container boundary.
#
# EVAL_SANDBOX=docker (default) starts the agent in a minimal container whose
# only mounts are the eval temp root (same absolute path, so worktree paths
# resolve) and the host opencode binary (read-only at /usr/local/bin/opencode).
# The container drops all capabilities, forbids privilege escalation, joins its
# own PID/mount/network namespace, and never receives the host home directory,
# the Docker socket, or a path to the source repository.
#
# EVAL_SANDBOX=none is an explicit opt-out for hermetic unit tests only. Those
# runs execute a stub binary directly on the host, must set the variable by
# hand, and must never claim isolation.
#
# Network policy: EVAL_SANDBOX_NETWORK defaults to `default` because a real
# agent needs the LLM endpoint. The isolation control sets `none`; with no
# interface it can neither resolve DNS nor reach a remote.
#
# Fail closed: callers must run `sandbox_preflight` before starting a run. It
# returns non-zero when the mode is unknown, Docker is absent, or the pinned
# image has not been built, and the caller then exits 2 without recording.

EVAL_SANDBOX="${EVAL_SANDBOX:-docker}"
EVAL_SANDBOX_IMAGE="${EVAL_SANDBOX_IMAGE:-spec-eval-sandbox:734a72b3d614}"
EVAL_SANDBOX_DOCKER="${EVAL_SANDBOX_DOCKER:-docker}"
EVAL_SANDBOX_NETWORK="${EVAL_SANDBOX_NETWORK:-default}"

# sandbox_mode — print the selected mode (`docker` or `none`).
sandbox_mode() {
  printf '%s\n' "$EVAL_SANDBOX"
}

# sandbox_preflight — validate the selected mode and its dependencies.
# Prints the reason on failure; callers turn a failure into exit 2.
sandbox_preflight() {
  case "$EVAL_SANDBOX" in
    none)
      return 0
      ;;
    docker)
      ;;
    *)
      echo "sandbox: unknown EVAL_SANDBOX '$EVAL_SANDBOX' (want docker or none)" >&2
      return 1
      ;;
  esac
  if ! command -v "$EVAL_SANDBOX_DOCKER" >/dev/null 2>&1; then
    echo "sandbox: docker not found ('$EVAL_SANDBOX_DOCKER'); refusing to run the agent unisolated" >&2
    return 1
  fi
  if ! "$EVAL_SANDBOX_DOCKER" info >/dev/null 2>&1; then
    echo "sandbox: docker daemon is unreachable; refusing to run the agent unisolated" >&2
    return 1
  fi
  if ! "$EVAL_SANDBOX_DOCKER" image inspect "$EVAL_SANDBOX_IMAGE" >/dev/null 2>&1; then
    echo "sandbox: image '$EVAL_SANDBOX_IMAGE' is not built; run 'make eval-sandbox'" >&2
    return 1
  fi
  return 0
}

# sandbox_run <tmp-root> <workdir> <opencode-bin> <command...>
# Run <command...> in the container. SANDBOX_ENV (an array of KEY=VALUE) is the
# complete environment allow-list handed to the container.
sandbox_run() {
  local root="$1" workdir="$2" opencode="$3"
  shift 3
  local -a args=(
    run --rm --init
    --cap-drop=ALL
    --security-opt no-new-privileges
    --pids-limit 256
    --memory 1g
    --user "$(id -u):$(id -g)"
    --network "$EVAL_SANDBOX_NETWORK"
    -w "$workdir"
    -v "$root:$root"
    -v "$opencode:/usr/local/bin/opencode:ro"
  )
  local assignment
  for assignment in ${SANDBOX_ENV[@]+"${SANDBOX_ENV[@]}"}; do
    [ -n "$assignment" ] && args+=(-e "$assignment")
  done
  "$EVAL_SANDBOX_DOCKER" "${args[@]}" "$EVAL_SANDBOX_IMAGE" "$@"
}
