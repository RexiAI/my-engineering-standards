#!/bin/bash
# autopilot-preflight.sh — Fail fast before an unattended queue run burns a
# night (spec 035 Task 8, docs/SPEC_PIPELINE.md §Autopilot mode).
#
# Usage:
#   scripts/autopilot-preflight.sh [--root <dir>] [SLUG ...]
#
# Checks, in this order, stopping at the first failure:
#   1. inside a git repo with a resolvable HEAD
#   2. `gh auth status` succeeds
#   3. GITHUB_TOKEN and GH_TOKEN are non-empty
#   4. the clean-tree rule: every dirty path is inside specs/<slug>/ for one of
#      the named slugs (no named slug ⇒ no spec folder is allowed to be dirty)
#   5. each named slug's spec folder exists
#   6. best-effort judgment backend probe — never fails preflight
#
# The orchestrator runs this before each queue item, so the clean-tree rule is
# re-evaluated against the slug actually being processed.
#
# On the first failure it prints exactly one `preflight: <reason>` line to
# stderr and exits non-zero; later checks do not run.
#
# Exit codes:
#   0 — every prerequisite holds (a judgment-backend warning may be printed)
#   1 — a prerequisite failed
#   2 — usage error
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Autopilot mode
set -euo pipefail

ROOT=""
SLUGS=()

usage() {
  cat <<'EOF'
Usage:
  scripts/autopilot-preflight.sh [--root <dir>] [SLUG ...]

Fails fast with `preflight: <reason>` on the first unmet prerequisite.
EOF
}

die() { echo "preflight: $1" >&2; exit 1; }

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --root) ROOT="${2:-}"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      --*) echo "autopilot-preflight: unknown option: $1" >&2; exit 2 ;;
      *) SLUGS+=("$1"); shift ;;
    esac
  done
}

warn() { echo "preflight: warning: $1" >&2; }

# resolve_root — 1. a work tree: resolve the root when not given, and make sure
# the directory exists.
resolve_root() {
  if [ -z "$ROOT" ]; then
    ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    [ -n "$ROOT" ] || die "not inside a git work tree"
  fi
  [ -d "$ROOT" ] || die "root directory not found: $ROOT"
}

# check_git — the root must be a work tree with a resolvable HEAD.
check_git() {
  git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "not inside a git work tree: $ROOT"
  git -C "$ROOT" rev-parse --verify HEAD >/dev/null 2>&1 \
    || die "git HEAD is not resolvable in $ROOT (no commit yet)"
}

# check_gh_auth — 2. the gh CLI is installed and authenticated.
check_gh_auth() {
  command -v gh >/dev/null 2>&1 || die "gh CLI not found on PATH"
  gh auth status >/dev/null 2>&1 || die "gh auth status failed — run 'gh auth login'"
}

# check_tokens — 3. both GitHub credentials are present.
check_tokens() {
  [ -n "${GITHUB_TOKEN:-}" ] || die "GITHUB_TOKEN is empty"
  [ -n "${GH_TOKEN:-}" ] || die "GH_TOKEN is empty"
}

# status_path <porcelain-line> — the path part, following a rename and
# stripping the quotes git adds around unusual names.
status_path() {
  local path="${1:3}"
  case "$path" in
    *' -> '*) path="${path##* -> }" ;;
  esac
  path="${path#\"}"
  path="${path%\"}"
  printf '%s' "$path"
}

# path_allowed <path> — inside specs/<slug>/ for one of the named slugs.
path_allowed() {
  local slug
  for slug in ${SLUGS[@]+"${SLUGS[@]}"}; do
    case "$1" in
      "specs/$slug/"*) return 0 ;;
    esac
  done
  return 1
}

# check_clean_tree — 4. every dirty path is inside the current spec folder.
check_clean_tree() {
  local dirty line path
  dirty="$(git -C "$ROOT" status --porcelain -uall || true)"
  [ -n "$dirty" ] || return 0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    path="$(status_path "$line")"
    path_allowed "$path" || die "dirty path outside the current spec folder: $path"
  done <<< "$dirty"
}

# check_slug_folders — 5. every named slug has a spec folder.
check_slug_folders() {
  local slug
  for slug in ${SLUGS[@]+"${SLUGS[@]}"}; do
    [ -d "$ROOT/specs/$slug" ] || die "spec folder not found: specs/$slug"
  done
}

# check_judgment_backend — 6. the backend is optional: probe when configured,
# warn, never fail preflight.
check_judgment_backend() {
  [ -n "${JUDGMENT_BACKEND:-}" ] || return 0
  if [ -z "${JUDGMENT_API_URL:-}" ]; then
    warn "JUDGMENT_BACKEND=$JUDGMENT_BACKEND set but JUDGMENT_API_URL is unset; continuing"
  elif ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; cannot probe judgment backend; continuing"
  elif ! curl -fsS --max-time 2 -o /dev/null "$JUDGMENT_API_URL" >/dev/null 2>&1; then
    warn "judgment backend unreachable at $JUDGMENT_API_URL; continuing"
  fi
}

parse_args "$@"
resolve_root
check_git
check_gh_auth
check_tokens
check_clean_tree
check_slug_folders
check_judgment_backend
exit 0
