#!/bin/bash
set -euo pipefail

# update-submodules.sh - Move the .standards submodule pointer across child repos.
#
# Usage:
#   ./update-submodules.sh                    # discover siblings of the standards repo
#   ./update-submodules.sh --parent-dir DIR   # scan DIR's immediate children
#   ./update-submodules.sh --auto             # scan the current directory tree
#   ./update-submodules.sh repo1 repo2        # explicit repo paths
#   ./update-submodules.sh --local            # commit locally, never push or open a PR
#   ./update-submodules.sh --dry-run          # print the plan, touch nothing
#
# Discovery order (first match wins): explicit paths, --parent-dir, --auto,
# repo-list.txt at the standards repo root, then the standards repo's own parent.
# Default progression: branch chore/bump-engineering-standards, commit, push,
# and open a PR with gh. --local stops after the commit.
#
# Exit codes: 0 success (or nothing eligible), 1 an eligible child failed,
# 2 usage error.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STANDARDS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_REPO_LIST="$STANDARDS_ROOT/repo-list.txt"
DEFAULT_PARENT_DIR="$(cd "$STANDARDS_ROOT/.." && pwd)"

SUBMODULE_PATH=".standards"
BRANCH_NAME="chore/bump-engineering-standards"
COMMIT_MESSAGE="chore: bump engineering standards submodule"

LOCAL_ONLY=0
DRY_RUN=0
USE_AUTO=0
PARENT_DIR=""
POSITIONAL=()
# Words consumed by the last parse_one_arg call: 1 for a flag or a repo path,
# 2 for an option that carries a value. Keeps a single shift site in the loop.
ARGS_CONSUMED=1

SUCCESS=0
FAILED=0
SKIPPED=0
PLANNED=0
FAILED_CHILDREN=()

usage() {
    cat <<'EOF'
Usage: update-submodules.sh [OPTIONS] [REPO ...]

Options:
  --parent-dir DIR   Scan DIR's immediate child directories.
  --auto             Discover repos under the current directory (find . -maxdepth 2).
  --local            Commit locally only: no branch, no push, no PR.
  --dry-run          Print the planned action per child; touch nothing.
  -h, --help         Show this help.

With no discovery flag, explicit paths win, then repo-list.txt at the standards
repo root, then the standards repo's own parent directory.
EOF
}

usage_error() {
    echo "ERROR: $*" >&2
    echo "Run with --help for usage." >&2
    exit 2
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        parse_one_arg "$@"
        shift "$ARGS_CONSUMED"
    done
    validate_parent_dir
}

parse_one_arg() {
    ARGS_CONSUMED=1
    case "$1" in
        --parent-dir) take_parent_dir "$@" ;;
        --auto|--local|--dry-run) apply_flag "$1" ;;
        -h|--help) usage; exit 0 ;;
        --*) usage_error "unknown option: $1" ;;
        *) POSITIONAL+=("$1") ;;
    esac
}

take_parent_dir() {
    [ "$#" -ge 2 ] || usage_error "--parent-dir requires a directory argument"
    PARENT_DIR="$2"
    ARGS_CONSUMED=2
}

apply_flag() {
    case "$1" in
        --auto) USE_AUTO=1 ;;
        --local) LOCAL_ONLY=1 ;;
        --dry-run) DRY_RUN=1 ;;
    esac
}

validate_parent_dir() {
    [ -n "$PARENT_DIR" ] || return 0
    if [ ! -d "$PARENT_DIR" ]; then
        echo "ERROR: --parent-dir '$PARENT_DIR' is not an existing directory" >&2
        exit 2
    fi
}

is_git_repo() {
    [ -d "$1/.git" ] || [ -f "$1/.git" ]
}

declares_standards() {
    local modules="$1/.gitmodules"
    [ -f "$modules" ] || return 1
    tr -d '\r' < "$modules" | grep -qE '^[[:space:]]*path[[:space:]]*=[[:space:]]*\.standards[[:space:]]*$'
}

# print_if_candidate DIR — discovery's silent eligibility filter. A neighbour
# that is not a child project is not part of the discovered result, so it is
# left out instead of reported as a skip; explicitly named repos go through
# skip_if_ineligible, which does report why they were left alone.
print_if_candidate() {
    if is_git_repo "$1" && declares_standards "$1"; then
        printf '%s\n' "$1"
    fi
}

scan_parent() {
    local entry
    for entry in "$1"/*/; do
        print_if_candidate "${entry%/}"
    done
}

scan_auto() {
    local repo
    find . -maxdepth 2 -name ".git" -type d 2>/dev/null | sed 's|/\.git$||' |
        while IFS= read -r repo; do
            print_if_candidate "$repo"
        done
}

read_repo_list() {
    grep -vE '^[[:space:]]*#' "$DEFAULT_REPO_LIST" | grep -vE '^[[:space:]]*$' || true
}

resolve_candidates() {
    if [ "${#POSITIONAL[@]}" -gt 0 ]; then
        printf '%s\n' "${POSITIONAL[@]}"
        return 0
    fi
    if [ -n "$PARENT_DIR" ]; then
        scan_parent "$PARENT_DIR"
        return 0
    fi
    if [ "$USE_AUTO" -eq 1 ]; then
        scan_auto
        return 0
    fi
    if [ -f "$DEFAULT_REPO_LIST" ]; then
        read_repo_list
        return 0
    fi
    scan_parent "$DEFAULT_PARENT_DIR"
}

submodule_status_line() {
    git -C "$1" submodule status -- "$SUBMODULE_PATH" 2>/dev/null || true
}

submodule_initialized() {
    local line
    line=$(submodule_status_line "$1")
    [ -n "$line" ] && [ "${line:0:1}" != "-" ]
}

# The pointer recorded in the child's last commit (not the submodule worktree).
submodule_pointer() {
    git -C "$1" rev-parse "HEAD:$SUBMODULE_PATH" 2>/dev/null || true
}

# The commit the submodule worktree is actually checked out at.
submodule_worktree_head() {
    git -C "$1/$SUBMODULE_PATH" rev-parse HEAD 2>/dev/null || true
}

has_submodule_remote() {
    local url
    url=$(git -C "$1/$SUBMODULE_PATH" config --get remote.origin.url 2>/dev/null || true)
    [ -n "$url" ]
}

is_dirty() {
    local changes
    changes=$(git -C "$1" status --porcelain 2>/dev/null || true)
    [ -n "$changes" ]
}

has_diverged() {
    local upstream counts
    upstream=$(git -C "$1" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null) || return 1
    counts=$(git -C "$1" rev-list --left-right --count "HEAD...$upstream" 2>/dev/null) || return 1
    [ "${counts%%[[:space:]]*}" -gt 0 ] && [ "${counts##*[[:space:]]}" -gt 0 ]
}

has_branch_ref() {
    git -C "$1" show-ref --verify --quiet "refs/heads/$2"
}

has_remote_ref() {
    git -C "$1" show-ref --verify --quiet "refs/remotes/origin/$2"
}

bump_branch_exists() {
    has_branch_ref "$1" "$BRANCH_NAME" || has_remote_ref "$1" "$BRANCH_NAME"
}

checkout_bump_branch() {
    if has_branch_ref "$1" "$BRANCH_NAME"; then
        git -C "$1" checkout -q "$BRANCH_NAME"
    else
        git -C "$1" checkout -q -b "$BRANCH_NAME" --track "origin/$BRANCH_NAME"
    fi
}

default_branch() {
    local branch
    branch=$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || branch=""
    branch="${branch#origin/}"
    if [ -z "$branch" ] && has_branch_ref "$1" master && ! has_branch_ref "$1" main; then
        branch="master"
    fi
    printf '%s' "${branch:-main}"
}

open_pr_exists() {
    local count
    count=$(cd "$1" && gh pr list --head "$BRANCH_NAME" --state open --json number --jq 'length' 2>/dev/null) || return 1
    [ -n "$count" ] && [ "$count" != "0" ]
}

create_pr() {
    local base
    base=$(default_branch "$1")
    (cd "$1" && gh pr create --head "$BRANCH_NAME" --base "$base" \
        --title "$COMMIT_MESSAGE" \
        --body "Bumps the .standards submodule pointer to the latest upstream commit.") >/dev/null 2>&1
}

skip_child() {
    SKIPPED=$((SKIPPED + 1))
    echo "[SKIP] $1: $2"
}

fail_child() {
    FAILED=$((FAILED + 1))
    FAILED_CHILDREN+=("$1: $2")
    echo "[FAIL] $1: $2"
}

succeed_child() {
    SUCCESS=$((SUCCESS + 1))
    echo "[OK] $1: $2"
}

latest_child() {
    SUCCESS=$((SUCCESS + 1))
    echo "[LATEST] $1: already at latest"
}

plan_child() {
    PLANNED=$((PLANNED + 1))
    echo "[PLAN] $1: $2"
}

plan_action() {
    if [ "$LOCAL_ONLY" -eq 1 ]; then
        printf '%s' "would update .standards and commit locally"
    else
        printf '%s' "would update .standards, commit on $BRANCH_NAME, push, and open a PR"
    fi
}

structural_problem() {
    if ! is_git_repo "$1"; then
        printf '%s' "not a git repository"
        return 0
    fi
    if [ ! -f "$1/.gitmodules" ]; then
        printf '%s' "no .gitmodules file"
        return 0
    fi
    if ! declares_standards "$1"; then
        printf '%s' "no .standards submodule declared"
        return 0
    fi
    return 1
}

state_problem() {
    if ! submodule_initialized "$1"; then
        printf '%s' ".standards submodule not initialized — run: git submodule update --init .standards"
        return 0
    fi
    if is_dirty "$1"; then
        printf '%s' "dirty working tree"
        return 0
    fi
    if has_diverged "$1"; then
        printf '%s' "local branch diverged from upstream"
        return 0
    fi
    return 1
}

# skip_if_ineligible REPO — report and return 0 when the child must be left
# alone; return 1 when it is safe to update. Shape is checked before local
# state so the reported reason is the first one the user can act on.
skip_if_ineligible() {
    local reason
    reason=$(structural_problem "$1") || reason=$(state_problem "$1") || return 1
    skip_child "$1" "$reason"
}

# PR progression needs a GitHub origin and gh on PATH; --local needs neither.
ready_to_publish() {
    if [ "$LOCAL_ONLY" -eq 1 ]; then
        return 0
    fi
    require_child_remote "$1"
}

require_child_remote() {
    local url
    url=$(git -C "$1" remote get-url origin 2>/dev/null || true)
    if [ -z "$url" ]; then
        fail_child "$1" "no remote"
        return 1
    fi
    case "$url" in
        *github.com*) ;;
        *) fail_child "$1" "remote is not GitHub"; return 1 ;;
    esac
    if ! command -v gh >/dev/null 2>&1; then
        fail_child "$1" "gh CLI not available"
        return 1
    fi
    return 0
}

ensure_bump_branch() {
    bump_branch_exists "$1" || git -C "$1" checkout -q -b "$BRANCH_NAME"
}

commit_bump() {
    git -C "$1" add "$SUBMODULE_PATH" && git -C "$1" commit -q -m "$COMMIT_MESSAGE"
}

# commit_or_fail REPO — stage and commit the pointer; report and return 1 when
# either git step fails.
commit_or_fail() {
    if commit_bump "$1"; then
        return 0
    fi
    fail_child "$1" "commit failed"
    return 1
}

publish_bump() {
    if ! git -C "$1" push -q -u origin "$BRANCH_NAME"; then
        fail_child "$1" "push failed"
        return 1
    fi
}

commit_local() {
    commit_or_fail "$1" || return 0
    succeed_child "$1" "updated and committed"
}

report_publish() {
    if open_pr_exists "$1"; then
        succeed_child "$1" "updated, committed and pushed on $BRANCH_NAME, reused open PR"
    elif create_pr "$1"; then
        succeed_child "$1" "updated, committed and pushed on $BRANCH_NAME, PR opened"
    else
        fail_child "$1" "gh pr create failed"
    fi
}

commit_and_publish() {
    local repo="$1"
    if ! ensure_bump_branch "$repo"; then
        fail_child "$repo" "cannot create $BRANCH_NAME"
        return 0
    fi
    commit_or_fail "$repo" || return 0
    publish_bump "$repo" || return 0
    report_publish "$repo"
}

# resume_bump_branch REPO — in PR mode, check out the existing bump branch so a
# re-run commits onto it instead of starting a second one. Returns 1 when the
# checkout failed (already reported).
resume_bump_branch() {
    if [ "$LOCAL_ONLY" -eq 1 ]; then
        return 0
    fi
    if ! bump_branch_exists "$1"; then
        return 0
    fi
    if checkout_bump_branch "$1"; then
        return 0
    fi
    fail_child "$1" "cannot check out $BRANCH_NAME"
    return 1
}

advance_child() {
    local repo="$1" current new
    resume_bump_branch "$repo" || return 0
    current=$(submodule_pointer "$repo")
    if ! git -C "$repo" submodule update --remote "$SUBMODULE_PATH" >/dev/null 2>&1; then
        fail_child "$repo" "git submodule update --remote failed"
        return 0
    fi
    new=$(submodule_worktree_head "$repo")
    if [ "$new" = "$current" ]; then
        latest_child "$repo"
        return 0
    fi
    if [ "$LOCAL_ONLY" -eq 1 ]; then
        commit_local "$repo"
    else
        commit_and_publish "$repo"
    fi
}

process_child() {
    local repo="$1"
    if skip_if_ineligible "$repo"; then
        return 0
    fi
    if [ "$DRY_RUN" -eq 1 ]; then
        plan_child "$repo" "$(plan_action)"
        return 0
    fi
    if ! has_submodule_remote "$repo"; then
        fail_child "$repo" ".standards submodule has no remote"
        return 0
    fi
    ready_to_publish "$repo" || return 0
    advance_child "$repo"
}

print_summary() {
    local entry
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "Summary: ${PLANNED} planned, ${SKIPPED} skipped."
    else
        echo "Summary: ${SUCCESS} succeeded, ${FAILED} failed, ${SKIPPED} skipped."
    fi
    if [ "${#FAILED_CHILDREN[@]}" -gt 0 ]; then
        echo "Failed children:"
        for entry in "${FAILED_CHILDREN[@]}"; do
            echo "  - $entry"
        done
    fi
}

main() {
    local candidate
    local -a candidates
    parse_args "$@"
    mapfile -t candidates < <(resolve_candidates)
    if [ "${#candidates[@]}" -eq 0 ]; then
        echo "No children were processed."
        exit 0
    fi
    for candidate in "${candidates[@]}"; do
        process_child "$candidate"
    done
    print_summary
    if [ "$FAILED" -gt 0 ]; then
        exit 1
    fi
    exit 0
}

main "$@"
