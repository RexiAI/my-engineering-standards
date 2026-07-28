#!/bin/bash
set -euo pipefail

# ──────────────────────────────────────────────
# init-ci.sh — CI/CD Generator for Child Projects
# ──────────────────────────────────────────────
# Auto-detects languages, prompts for CI platform,
# generates CI files that inherit from parent templates.
#
# Usage:
#   Interactive:    ./.standards/scripts/init-ci.sh
#   Pre-filled:     ./.standards/scripts/init-ci.sh \
#                     --platform github \
#                     --languages java,go \
#                     --registry ghcr.io
# ──────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}ℹ${NC} $1"; }
ok()    { echo -e "${GREEN}✔${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; }
err()   { echo -e "${RED}✘${NC} $1"; }

# ── Parse CLI flags ───────────────────────────
CI_FLAG=""
BACKEND_FLAG=""
FRONTEND_FLAG=""
REGISTRY_FLAG=""
WITH_SAGA_FLAG=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --platform)
      CI_FLAG="$2"
      shift 2
      ;;
    --backend)
      BACKEND_FLAG="$2"
      shift 2
      ;;
    --frontend)
      FRONTEND_FLAG="$2"
      shift 2
      ;;
    --registry)
      REGISTRY_FLAG="$2"
      shift 2
      ;;
    --with-saga)
      WITH_SAGA_FLAG="true"
      shift
      ;;
    *)
      err "Unknown flag: $1"
      echo "Usage: $0 [--platform github|gitlab|both] [--backend java,go,node] [--frontend nextjs,react,angular,static] [--registry ghcr.io] [--with-saga]"
      exit 1
      ;;
  esac
done

# ── Detect project root ───────────────────────
PROJECT_ROOT=""
if [ -d ".standards" ]; then
  PROJECT_ROOT=$(pwd)
elif [ -f ".standards" ]; then
  PROJECT_ROOT=$(pwd)
else
  PARENT=$(dirname "$(pwd)")
  if [ -d "$PARENT/.standards" ]; then
    PROJECT_ROOT=$PARENT
  else
    err "Can't find .standards/ directory. Run from project root."
    exit 1
  fi
fi

STANDARDS_DIR="$PROJECT_ROOT/.standards"
cd "$PROJECT_ROOT"

ok "Project root: $PROJECT_ROOT"
ok "Standards found: $STANDARDS_DIR"

# ── Step 1: Detect / use backend languages ────
detect_backend() {
  BACKEND=()
  [ -f pom.xml ]         && BACKEND+=("java")
  [ -f go.mod ]          && BACKEND+=("go")

  if [ ${#BACKEND[@]} -eq 0 ]; then
    warn "No backend files detected (pom.xml / go.mod)"
    if [ ! -t 0 ]; then
      warn "Non-interactive stdin — defaulting to no backend. Pass --backend to set one."
    else
      echo ""
      echo "Select backend language (or None):"
      select L in "Java" "Go" "None" "Cancel"; do
        case $L in
          Java)   BACKEND=("java"); break;;
          Go)     BACKEND=("go"); break;;
          None)   break;;
          Cancel) exit 1;;
        esac
      done
    fi
  fi
  [ ${#BACKEND[@]} -gt 0 ] && info "Backend: ${BACKEND[*]}"
  true
}

# ── Step 1b: Detect / use frontend type ───────
detect_frontend() {
  FRONTEND=""
  if [ -f package.json ]; then
    if grep -q '"next"' package.json 2>/dev/null; then
      FRONTEND="nextjs"
    elif grep -q '"react"' package.json 2>/dev/null; then
      FRONTEND="react"
    elif grep -q '"@angular"' package.json 2>/dev/null; then
      FRONTEND="angular"
    fi
  fi

  if [ -z "$FRONTEND" ]; then
    if [ ! -t 0 ]; then
      warn "No frontend detected, non-interactive stdin — defaulting to none. Pass --frontend to set one."
    else
      echo ""
      echo "Select frontend type (or None):"
      select F in "Next.js" "React (Vite)" "Angular" "Static HTML" "None" "Cancel"; do
        case $F in
          "Next.js")       FRONTEND="nextjs"; break;;
          "React (Vite)")  FRONTEND="react"; break;;
          "Angular")       FRONTEND="angular"; break;;
          "Static HTML")   FRONTEND="static"; break;;
          "None")          break;;
          "Cancel")        exit 1;;
        esac
      done
    fi
  fi
  [ -n "$FRONTEND" ] && info "Frontend: $FRONTEND"
  true
}

if [ -n "$BACKEND_FLAG" ]; then
  IFS=',' read -ra BACKEND <<< "$BACKEND_FLAG"
  info "Backend from flag: ${BACKEND[*]}"
else
  detect_backend
fi

if [ -n "$FRONTEND_FLAG" ]; then
  FRONTEND="$FRONTEND_FLAG"
  info "Frontend from flag: $FRONTEND"
else
  detect_frontend
fi

# ── Step 2: Select CI platform ────────────────
if [ -n "$CI_FLAG" ]; then
  CI="$CI_FLAG"
  ok "CI platform from flag: $CI"
else
  echo ""
  info "Select CI platform:"
  select CI_PLATFORM in "GitHub Actions" "GitLab CI" "Both" "Cancel"; do
    case $CI_PLATFORM in
      "GitHub Actions") CI="github"; break;;
      "GitLab CI")      CI="gitlab"; break;;
      "Both")           CI="both"; break;;
      "Cancel")         exit 1;;
    esac
  done
  ok "CI platform: $CI_PLATFORM"
fi

# ── Step 3: Ask for secrets ───────────────────
collect_secrets() {
  GHCR_TOKEN=""; MAVEN_USERNAME=""; MAVEN_PASSWORD=""; NPM_TOKEN=""; SONAR_TOKEN=""; PACT_BROKER_URL=""

  if [ ! -t 0 ]; then
    info "Non-interactive stdin — skipping secrets prompt (add secrets manually later)."
    return
  fi

  echo ""
  info "Optional: Add CI secrets now? These go into the generated files as placeholders."
  echo "1) Yes, add secrets placeholders"
  echo "2) Skip (add secrets manually later)"
  read -r SECRETS_CHOICE

  if [ "$SECRETS_CHOICE" = "1" ]; then
    read -rp "  GHCR_TOKEN: " GHCR_TOKEN
    if [[ " ${BACKEND[*]} " =~ "java" ]]; then
      read -rp "  MAVEN_USERNAME: " MAVEN_USERNAME
      read -rp "  MAVEN_PASSWORD: " MAVEN_PASSWORD
    fi
    if [[ " ${BACKEND[*]} " =~ "node" ]] || [ -n "$FRONTEND" ]; then
      read -rp "  NPM_TOKEN: " NPM_TOKEN
    fi
    read -rp "  SONAR_TOKEN (optional): " SONAR_TOKEN
    read -rp "  PACT_BROKER_URL (optional): " PACT_BROKER_URL
  fi
}

collect_secrets

# ── Step 4: Generate files ────────────────────
generate_github_ci() {
  local target="$PROJECT_ROOT/.github/workflows/ci.yml"
  local registry="${REGISTRY_FLAG:-ghcr.io}"
  local saga_enabled="${WITH_SAGA_FLAG:-false}"

  mkdir -p "$PROJECT_ROOT/.github/workflows"

  cat > "$target" << EOF
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
EOF

  if [ "$saga_enabled" = "true" ]; then
    echo "  NOTE: saga/outbox CI gates are GitLab-only right now; GitHub Actions workflow has no gate job." >&2
  fi

  for lang in "${BACKEND[@]}"; do
    cat >> "$target" << EOF
  backend-ci-${lang}:
    uses: pucelano-95/my-engineering-standards/.github/workflows/backend/ci-${lang}.yml@main
    with:
      docker-registry: $registry
    secrets:
      GHCR_TOKEN: \${{ secrets.GHCR_TOKEN }}
      PACT_BROKER_URL: \${{ secrets.PACT_BROKER_URL }}
EOF
  done

  if [ -n "$FRONTEND" ]; then
    cat >> "$target" << EOF
  frontend-ci:
    uses: pucelano-95/my-engineering-standards/.github/workflows/frontend/ci-${FRONTEND}.yml@main
    with:
      docker-registry: $registry
    secrets:
      GHCR_TOKEN: \${{ secrets.GHCR_TOKEN }}
EOF
  fi

  ok "Generated: .github/workflows/ci.yml"

  # Copy saga templates if --with-saga
  if [ "$saga_enabled" = "true" ]; then
    _copy_saga_templates
  fi

  # Dependabot
  if [ ! -f "$PROJECT_ROOT/.github/dependabot.yml" ]; then
    local eco="npm"
    for lang in "${BACKEND[@]}"; do
      case $lang in
        java) eco="maven";;
        go)   eco="gomod";;
        node) eco="npm";;
      esac
    done
    mkdir -p "$PROJECT_ROOT/.github"
    sed "s/LANG_ECOSYSTEM/$eco/g" "$STANDARDS_DIR/ci/templates/dependabot.yml" \
      > "$PROJECT_ROOT/.github/dependabot.yml"
    ok "Generated: .github/dependabot.yml"
  fi

  # Semantic Release config (Node backend or frontend)
  if [ ! -f "$PROJECT_ROOT/.releaserc.json" ]; then
    local has_node=false
    for lang in "${BACKEND[@]}"; do [ "$lang" = "node" ] && has_node=true; done
    if [ "$has_node" = true ] || [ -n "$FRONTEND" ]; then
      cp "$STANDARDS_DIR/ci/templates/releaserc.json" "$PROJECT_ROOT/.releaserc.json"
      ok "Generated: .releaserc.json"
    fi
  fi

  # Copy Makefile if Go and no existing Makefile
  for lang in "${BACKEND[@]}"; do
    if [ "$lang" = "go" ] && [ ! -f "$PROJECT_ROOT/Makefile" ]; then
      cp "$STANDARDS_DIR/ci/templates/Makefile.go" "$PROJECT_ROOT/Makefile"
      ok "Generated: Makefile (Go template)"
    fi
  done
}

generate_gitlab() {
  local target="$PROJECT_ROOT/.gitlab-ci.yml"
  local registry="${REGISTRY_FLAG:-ghcr.io}"
  local saga_enabled="${WITH_SAGA_FLAG:-false}"

  cat > "$target" << EOF
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
EOF

  for lang in "${BACKEND[@]}"; do
    echo "  - local: .standards/ci/gitlab/backend/ci-${lang}.yml" >> "$target"
  done
  if [ -n "$FRONTEND" ]; then
    echo "  - local: .standards/ci/gitlab/frontend/ci-${FRONTEND}.yml" >> "$target"
  fi

  # Add saga-gates stage when --with-saga
  local stages_block="stages:
  - test
  - lint
  - contract
  - integration
  - deploy
  - docker"
  if [ "$saga_enabled" = "true" ]; then
    stages_block="stages:
  - test
  - lint
  - saga-gates
  - contract
  - integration
  - deploy
  - docker"
  fi

  cat >> "$target" << EOF

${stages_block}

variables:
  CI_REGISTRY: $registry
EOF

  for lang in "${BACKEND[@]}"; do
    cat >> "$target" << EOF

${lang}-unit:
  extends: .${lang}-unit
  stage: test

${lang}-lint:
  extends: .${lang}-lint
  stage: lint
EOF

    # Inject saga-gates job when --with-saga
    if [ "$saga_enabled" = "true" ]; then
      cat >> "$target" << EOF

${lang}-saga-gates:
  extends: .${lang}-saga-gates
  stage: saga-gates
EOF
    fi

    cat >> "$target" << EOF

${lang}-contract:
  extends: .${lang}-contract
  stage: contract

${lang}-integration:
  extends: .${lang}-integration
  stage: integration

${lang}-deploy:
  extends: .${lang}-deploy
  stage: deploy

${lang}-docker:
  extends: .${lang}-docker
  stage: docker
EOF
  done

  if [ -n "$FRONTEND" ]; then
    if [ "$FRONTEND" = "static" ]; then
      cat >> "$target" << EOF

frontend-lint:
  extends: .static-lint
  stage: lint

frontend-docker:
  extends: .static-docker
  stage: docker
EOF
    else
      cat >> "$target" << EOF

frontend-unit:
  extends: .${FRONTEND}-unit
  stage: test

frontend-lint:
  extends: .${FRONTEND}-lint
  stage: lint

frontend-build:
  extends: .${FRONTEND}-build
  stage: deploy

frontend-docker:
  extends: .${FRONTEND}-docker
  stage: docker
EOF
    fi
  fi

  ok "Generated: .gitlab-ci.yml"

  # Copy saga templates if --with-saga
  if [ "$saga_enabled" = "true" ]; then
    _copy_saga_templates
  fi

  # Copy Makefile if Go and no existing Makefile
  for lang in "${BACKEND[@]}"; do
    if [ "$lang" = "go" ] && [ ! -f "$PROJECT_ROOT/Makefile" ]; then
      cp "$STANDARDS_DIR/ci/templates/Makefile.go" "$PROJECT_ROOT/Makefile"
      ok "Generated: Makefile (Go template)"
    fi
  done
}

# ── Step 4b: Copy saga templates ─────────────────────────────────────────────
_copy_saga_templates() {
  info "Copying saga/outbox quality gate templates..."

  # Detect primary backend language for template selection
  local primary_lang="${BACKEND[0]:-}"

  case "$primary_lang" in
    java)
      # Copy ArchUnit pom fragment
      local archunit_dir="$PROJECT_ROOT/src/test/resources/archunit"
      mkdir -p "$archunit_dir"
      cp "$STANDARDS_DIR/ci/templates/archunit/pom-fragment.xml" \
         "$archunit_dir/pom-fragment.xml"
      ok "Copied: src/test/resources/archunit/pom-fragment.xml"
      warn "Add the dependency in pom-fragment.xml to your pom.xml <dependencies> block."

      # Copy Java test templates
      local test_dir="$PROJECT_ROOT/src/test/java"
      mkdir -p "$test_dir"
      cp "$STANDARDS_DIR/ci/templates/tests/SagaIntegrationTestTemplate.java" \
         "$test_dir/SagaIntegrationTestTemplate.java"
      cp "$STANDARDS_DIR/ci/templates/tests/OutboxIntegrationTestTemplate.java" \
         "$test_dir/OutboxIntegrationTestTemplate.java"
      ok "Copied: Java saga/outbox integration test templates to src/test/java/"
      ;;

    go)
      # Copy Go AST linter
      local lint_dir="$PROJECT_ROOT/tools"
      mkdir -p "$lint_dir"
      cp "$STANDARDS_DIR/ci/templates/go-saga-lint.go" \
         "$lint_dir/go-saga-lint.go"
      ok "Copied: tools/go-saga-lint.go"

      # Copy Go test templates
      local test_dir="$PROJECT_ROOT/internal"
      mkdir -p "$test_dir"
      cp "$STANDARDS_DIR/ci/templates/tests/saga_integration_test.go" \
         "$test_dir/saga_integration_test.go"
      cp "$STANDARDS_DIR/ci/templates/tests/outbox_integration_test.go" \
         "$test_dir/outbox_integration_test.go"
      ok "Copied: Go saga/outbox integration test templates to internal/"
      ;;

    node)
      # Copy ESLint saga rules plugin
      local lint_dir="$PROJECT_ROOT/src/lint"
      mkdir -p "$lint_dir"
      cp -r "$STANDARDS_DIR/ci/templates/eslint-saga-rules/" \
            "$lint_dir/eslint-saga-rules/"
      ok "Copied: src/lint/eslint-saga-rules/"
      warn "Wire eslint-saga-rules in your eslint.config.js. See src/lint/eslint-saga-rules/saga-compensation.js."

      # Copy Node test templates
      local test_dir="$PROJECT_ROOT/src/__tests__/integration"
      mkdir -p "$test_dir"
      cp "$STANDARDS_DIR/ci/templates/tests/saga.integration.test.ts" \
         "$test_dir/saga.integration.test.ts"
      cp "$STANDARDS_DIR/ci/templates/tests/outbox.integration.test.ts" \
         "$test_dir/outbox.integration.test.ts"
      ok "Copied: Node saga/outbox integration test templates to src/__tests__/integration/"
      ;;
  esac

  ok "Saga/outbox templates copied. Fill in TODO markers before running CI."
  info "Reference: docs/SAGA_PATTERN.md §CI Quality Gates, docs/OUTBOX_PATTERN.md §CI Quality Gates"
}

# ── Step 5: Print summary ─────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║     CI/CD Generation Complete        ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "Generated files:"
  [ -f .github/workflows/ci.yml ] && echo "  • .github/workflows/ci.yml (backend: ${BACKEND[*]}, frontend: ${FRONTEND:-none})"
  [ -f .github/dependabot.yml ]   && echo "  • .github/dependabot.yml"
  [ -f .gitlab-ci.yml ]           && echo "  • .gitlab-ci.yml"
  [ -f .releaserc.json ]          && echo "  • .releaserc.json"
  [ -f Makefile ]                 && echo "  • Makefile"
  echo ""
  echo "Next steps:"
  if [ "$CI" = "github" ] || [ "$CI" = "both" ]; then
    echo "  1. Add repo secrets in GitHub → Settings → Secrets and variables → Actions:"
    [ -n "$GHCR_TOKEN" ]     && echo "     - GHCR_TOKEN (GitHub Container Registry token)"
    [ -n "$MAVEN_USERNAME" ] && echo "     - MAVEN_USERNAME"
    [ -n "$MAVEN_PASSWORD" ] && echo "     - MAVEN_PASSWORD"
    [ -n "$NPM_TOKEN" ]      && echo "     - NPM_TOKEN"
    [ -n "$SONAR_TOKEN" ]    && echo "     - SONAR_TOKEN (optional)"
    [ -n "$PACT_BROKER_URL" ] && echo "     - PACT_BROKER_URL (optional)"
    echo "  2. Push and check Actions tab"
  fi
  if [ "$CI" = "gitlab" ] || [ "$CI" = "both" ]; then
    echo "  1. Add CI/CD variables in GitLab → Settings → CI/CD → Variables"
    echo "  2. Push and check Pipelines tab"
  fi
  echo "  3. Review generated files and customize as needed"
  if [ "${WITH_SAGA_FLAG:-}" = "true" ]; then
    echo ""
    echo "Saga/Outbox gate templates copied:"
    echo "  • Fill in TODO markers in the integration test templates"
    echo "  • Java: add pom-fragment.xml dependency to pom.xml"
    echo "  • Node: wire eslint-saga-rules plugin in eslint.config.js"
    echo "  • Reference: docs/SAGA_PATTERN.md §CI Quality Gates"
    echo "               docs/OUTBOX_PATTERN.md §CI Quality Gates"
  fi
  echo ""
}

# ── Main ──────────────────────────────────────
echo ""
echo "╔═══════════════════════════════════╗"
echo "║    🚀  CI/CD Generator           ║"
echo "║    my-engineering-standards      ║"
echo "╚═══════════════════════════════════╝"
echo ""

case $CI in
  github|both) generate_github_ci;;
esac
case $CI in
  gitlab|both) generate_gitlab;;
esac

print_summary
