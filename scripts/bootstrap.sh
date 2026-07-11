#!/bin/bash
set -euo pipefail

# bootstrap.sh - One-time setup to bridge engineering standards into a child repo
# Usage: Run from the root of the child repo: ./.standards/scripts/bootstrap.sh

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
STANDARDS_DIR="$REPO_ROOT/.standards"

echo "=== Engineering Standards Bootstrap ==="
echo "Repo root: $REPO_ROOT"
echo ""

# Validate .standards/ exists
if [ ! -d "$STANDARDS_DIR" ]; then
    echo "ERROR: .standards/ not found."
    echo "Run this first: git submodule add git@github.com:pucelano-95/my-engineering-standards.git .standards"
    exit 1
fi

# 1. Symlink AGENTS.md
if [ ! -f "$REPO_ROOT/AGENTS.md" ] || [ -L "$REPO_ROOT/AGENTS.md" ]; then
    ln -sf .standards/AGENTS.md "$REPO_ROOT/AGENTS.md"
    echo "[SYMLINK] .standards/AGENTS.md -> AGENTS.md"
else
    echo "[SKIP] AGENTS.md already exists (manual backup required to replace)"
fi

# 2. Copy opencode.json
if [ ! -f "$REPO_ROOT/opencode.json" ]; then
    cp "$STANDARDS_DIR/templates/opencode.json.bridge" "$REPO_ROOT/opencode.json"
    echo "[COPY] opencode.json.bridge -> opencode.json"
else
    echo "[SKIP] opencode.json already exists"
fi

# 3. Symlink OKF (Operational Knowledge Framework)
if [ ! -d "$REPO_ROOT/okf" ]; then
    ln -sf .standards/okf "$REPO_ROOT/okf"
    echo "[SYMLINK] .standards/okf -> okf"
else
    echo "[SKIP] okf/ already exists"
fi

# 4. Copy PR template
mkdir -p "$REPO_ROOT/.github"
if [ ! -f "$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md" ]; then
    cp "$STANDARDS_DIR/templates/PULL_REQUEST_TEMPLATE.md" "$REPO_ROOT/.github/PULL_REQUEST_TEMPLATE.md"
    echo "[COPY] PULL_REQUEST_TEMPLATE.md -> .github/"
else
    echo "[SKIP] PR template already exists"
fi

# 4. Detect project type and copy language-specific configs
LANG_DETECTED=""
if [ -f "$REPO_ROOT/pom.xml" ]; then
    echo ""
    echo "[JAVA] Detected Maven project"
    LANG_DETECTED="java"
    for f in checkstyle.xml spotbugs-include.xml pmd-rules.xml; do
        if [ ! -f "$REPO_ROOT/$f" ]; then
            cp "$STANDARDS_DIR/language-specific/java/$f" "$REPO_ROOT/$f"
            echo "  [COPY] language-specific/java/$f -> $f"
        fi
    done
    touch "$REPO_ROOT/.gitignore"
    if ! grep -q "target/" "$REPO_ROOT/.gitignore" 2>/dev/null; then
        cat "$STANDARDS_DIR/templates/.gitignore.java" >> "$REPO_ROOT/.gitignore"
        echo "  [APPEND] .gitignore.java -> .gitignore"
    fi

elif ls "$REPO_ROOT"/*.go 2>/dev/null | head -1 > /dev/null 2>&1; then
    echo ""
    echo "[GO] Detected Go project"
    LANG_DETECTED="go"
    if [ ! -f "$REPO_ROOT/.golangci.yml" ]; then
        cp "$STANDARDS_DIR/language-specific/go/golangci.yml" "$REPO_ROOT/.golangci.yml"
        echo "  [COPY] language-specific/go/golangci.yml -> .golangci.yml"
    fi
    if [ ! -f "$REPO_ROOT/Makefile" ]; then
        cp "$STANDARDS_DIR/ci/templates/Makefile.go" "$REPO_ROOT/Makefile"
        echo "  [COPY] ci/templates/Makefile.go -> Makefile"
    fi
    if ! grep -q "bin/" "$REPO_ROOT/.gitignore" 2>/dev/null; then
        cat "$STANDARDS_DIR/templates/.gitignore.go" >> "$REPO_ROOT/.gitignore"
        echo "  [APPEND] .gitignore.go -> .gitignore"
    fi

elif [ -f "$REPO_ROOT/package.json" ]; then
    echo ""
    echo "[JS/TS] Detected Node.js project"
    LANG_DETECTED="node"
    # ESLint config
    if [ ! -f "$REPO_ROOT/.eslintrc.js" ] && [ ! -f "$REPO_ROOT/.eslintrc.json" ] && [ ! -f "$REPO_ROOT/eslint.config.js" ]; then
        cp "$STANDARDS_DIR/language-specific/javascript/eslint.config.js" "$REPO_ROOT/eslint.config.js"
        echo "  [COPY] language-specific/javascript/eslint.config.js -> eslint.config.js"
    fi
    # Prettier config
    if [ ! -f "$REPO_ROOT/.prettierrc.js" ] && [ ! -f "$REPO_ROOT/.prettierrc" ] && [ ! -f "$REPO_ROOT/prettier.config.js" ]; then
        cp "$STANDARDS_DIR/language-specific/javascript/prettier.config.js" "$REPO_ROOT/prettier.config.js"
        echo "  [COPY] language-specific/javascript/prettier.config.js -> prettier.config.js"
    fi
    # .gitignore
    if ! grep -q "node_modules/" "$REPO_ROOT/.gitignore" 2>/dev/null; then
        cat "$STANDARDS_DIR/templates/.gitignore.node" >> "$REPO_ROOT/.gitignore"
        echo "  [APPEND] .gitignore.node -> .gitignore"
    fi
fi

# 5. CI/CD initialization
echo ""
echo "--- CI/CD Setup ---"
echo "Initialize CI/CD for this project?"
select CI_CHOICE in "GitHub Actions" "GitLab CI" "Skip"; do
    case $CI_CHOICE in
        "GitHub Actions"|"GitLab CI")
            CI_PLATFORM=$(echo "$CI_CHOICE" | tr '[:upper:]' '[:lower:]' | sed 's/ //')
            echo ""
            echo "Running CI/CD generator..."
            bash "$STANDARDS_DIR/scripts/init-ci.sh" \
                --platform "$CI_PLATFORM" \
                --languages "$LANG_DETECTED" \
                --registry "ghcr.io"
            break
            ;;
        "Skip")
            echo "[SKIP] CI/CD setup skipped."
            echo "  Run later: ./.standards/scripts/init-ci.sh"
            break
            ;;
    esac
done

# 6. Session hygiene scripts
echo ""
echo "--- Session Hygiene ---"
echo ""
for script in session-start-check.sh session-end-check.sh; do
    if [ ! -f "$REPO_ROOT/$script" ]; then
        cp "$STANDARDS_DIR/templates/$script" "$REPO_ROOT/$script"
        chmod +x "$REPO_ROOT/$script"
        echo "  [COPY] templates/$script -> $script"
    else
        echo "  [SKIP] $script already exists"
    fi
done

echo ""
echo "=== Bootstrap complete ==="
echo "Next steps:"
echo "  1. Review and commit the new files:"
echo "     git add .standards AGENTS.md opencode.json okf .github/ Makefile"
echo "  2. OpenCode will auto-discover AGENTS.md and load instructions from .standards/"
echo "  3. Run session hygiene check: ./session-start-check.sh"
echo "  4. Push and verify CI pipeline runs"
echo "  5. Read OKF practices: open okf/index.md (after commit, markdown render)"
