#!/bin/bash
set -euo pipefail

# update-submodules.sh - Bulk update the .standards submodule pointer across multiple repos
#
# Usage:
#   ./update-submodules.sh                # Reads from ./repo-list.txt
#   ./update-submodules.sh repo1 repo2    # Updates listed repos
#   ./update-submodules.sh --auto         # Auto-discovers git repos in the current directory
#
# Each line in repo-list.txt should be the path to a git repo directory.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_REPO_LIST="$SCRIPT_DIR/../repo-list.txt"

get_repos() {
    if [ "$#" -gt 0 ] && [ "$1" != "--auto" ]; then
        echo "$@"
        return
    fi

    if [ "$#" -eq 1 ] && [ "$1" = "--auto" ]; then
        find . -maxdepth 2 -name ".git" -type d | sed 's|/.git$||'
        return
    fi

    if [ -f "$DEFAULT_REPO_LIST" ]; then
        grep -v '^#' "$DEFAULT_REPO_LIST" | grep -v '^[[:space:]]*$' || true
        return
    fi

    echo "ERROR: No repos specified and no repo-list.txt found." >&2
    echo "Create repo-list.txt with one repo path per line, or pass repo paths as arguments." >&2
    return 2
}

if ! REPOS=($(get_repos "$@")); then
    exit 1
fi

if [ ${#REPOS[@]} -eq 0 ]; then
    echo "No repos found."
    exit 0
fi

echo "Updating .standards submodule in ${#REPOS[@]} repos..."
echo ""

for repo in "${REPOS[@]}"; do
    if [ ! -d "$repo/.git" ] && [ ! -f "$repo/.git" ]; then
        echo "[SKIP] $repo is not a git repository"
        continue
    fi

    echo "--- $repo ---"
    (
        cd "$repo"

        if [ ! -f ".gitmodules" ] || ! grep -q "standards" ".gitmodules" 2>/dev/null; then
            echo "  No .standards submodule configured, skipping."
            exit 0
        fi

        if git submodule status .standards | grep -q "^-"; then
            echo "  Submodule not initialized. Run: git submodule update --init .standards"
            exit 0
        fi

        CURRENT=$(git submodule status .standards | cut -c2- | cut -d' ' -f1 | cut -c1-8)
        echo "  Current: $CURRENT"

        git submodule update --remote .standards
        NEW=$(git submodule status .standards | cut -c2- | cut -d' ' -f1 | cut -c1-8)
        echo "  New:     $NEW"

        if [ "$CURRENT" != "$NEW" ]; then
            git add .standards
            git commit -m "chore: bump engineering standards submodule"
            echo "  Updated and committed."
        else
            echo "  Already at latest."
        fi
    )
    echo ""
done

echo "Done. ${#REPOS[@]} repos processed."
