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
#
# Acceptance scenario coverage (spec 022, docs/SPEC_PIPELINE.md §Scenario format):
#   AC-022-01  docs/CI_CD.md §Release Process rationale — why the bootstrap does
#              not auto-wire release (credentials repo-owned, release as an
#              authority, opt-in cadence, parent-vs-child asymmetry)
#   AC-022-02  docs/CI_CD.md §Release Process opt-in steps + no-op child boundary
#   AC-022-03  this script: --with-release flag (GitHub + GitLab generation,
#              GH_TOKEN prompt + summary, .releaserc.json coupling)
#   AC-022-04  self-CI gates green (make lint / validate-all, orchestration,
#              skills, bash -n, no CRLF, scoped git status)
#   AC-024-01  docs/CI_CD.md §PR Review Agent + init-ci.sh --with-pr-review
#              flag wiring (AC-024-04-01/02/03: flag parse, pr-review job
#              emission, byte-compatible default; AC-024-04-04/05: secret
#              prompt gated on the flag; AC-024-04-06: summary lists
#              OPENCODE_API_KEY; AC-024-04-07/08: GitLab warning no-op)
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
WITH_DEPLOY_FLAG=""
WITH_RELEASE_FLAG=""
WITH_PR_REVIEW_FLAG=""
DEPLOY_TOOL="kamal"

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
    --with-deploy)
      WITH_DEPLOY_FLAG="true"
      shift
      ;;
    --with-release)
      # Opt-in Semantic Release wiring (AC-022-03-01): emits the release job
      # via the reusable include on both platforms, prompts for GH_TOKEN, and
      # couples .releaserc.json for Java/Go-only children (AC-022-03-04/08).
      WITH_RELEASE_FLAG="true"
      shift
      ;;
    --with-pr-review)
      # Opt-in PR review agent wiring (AC-024-04-01): emits the pr-review job
      # calling the shared reusable workflow, prompts for OPENCODE_API_KEY, and
      # lists the secret in the GitHub next steps. GitHub Actions-only — on
      # GitLab the flag prints a warning and emits nothing (AC-024-04-07).
      WITH_PR_REVIEW_FLAG="true"
      shift
      ;;
    --deploy-tool)
      DEPLOY_TOOL="$2"
      WITH_DEPLOY_FLAG="true"
      shift 2
      ;;
    *)
      err "Unknown flag: $1"
      echo "Usage: $0 [--platform github|gitlab|both] [--backend java,go,node] [--frontend nextjs,react,angular,react-native,static] [--registry ghcr.io] [--with-saga] [--with-deploy] [--deploy-tool kamal|dokku|ssh] [--with-release] [--with-pr-review]"
      exit 1
      ;;
  esac
done

case "$DEPLOY_TOOL" in
  kamal|dokku|ssh) ;;
  *) err "Invalid --deploy-tool '$DEPLOY_TOOL' (expected kamal|dokku|ssh)"; exit 1 ;;
esac

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
  [ -f pom.xml ] && BACKEND+=("java")
  [ -f go.mod ]  && BACKEND+=("go")

  if [ ${#BACKEND[@]} -eq 0 ]; then
    warn "No backend files detected (pom.xml / go.mod)"
    _prompt_backend
  fi
  [ ${#BACKEND[@]} -gt 0 ] && info "Backend: ${BACKEND[*]}"
  true
}

# Interactive fallback when no backend files are found. Sets the BACKEND global.
_prompt_backend() {
  if [ ! -t 0 ]; then
    warn "Non-interactive stdin — defaulting to no backend. Pass --backend to set one."
    return 0
  fi

  echo ""
  echo "Select backend language (or None):"
  local -A values=(
    [Java]=java
    [Go]=go
  )
  select L in "Java" "Go" "None" "Cancel"; do
    local v="${values[$L]:-}"
    if [ -n "$v" ]; then
      BACKEND=("$v")
      return 0
    fi
    [ "$L" = "None" ]   && return 0
    [ "$L" = "Cancel" ] && exit 1
  done
  true
}

# ── Step 1b: Detect / use frontend type ───────
detect_frontend() {
  FRONTEND=""
  if [ -f package.json ]; then
    FRONTEND="$(_detect_frontend_pkg)"
  fi
  if [ -z "$FRONTEND" ]; then
    _prompt_frontend
  fi
  [ -n "$FRONTEND" ] && info "Frontend: $FRONTEND"
  true
}

# Marker precedence matters: an Expo app also lists "react" and
# "react-native", so the more specific markers must win before "react".
_detect_frontend_pkg() {
  if grep -qE '"(expo|react-native)"' package.json 2>/dev/null; then
    echo "react-native"; return 0
  fi
  if grep -q '"next"' package.json 2>/dev/null; then
    echo "nextjs"; return 0
  fi
  if grep -q '"react"' package.json 2>/dev/null; then
    echo "react"; return 0
  fi
  if grep -q '"@angular"' package.json 2>/dev/null; then
    echo "angular"; return 0
  fi
  echo ""
}

# Interactive fallback when no frontend marker is found. Sets the FRONTEND global.
_prompt_frontend() {
  if [ ! -t 0 ]; then
    warn "No frontend detected, non-interactive stdin — defaulting to none. Pass --frontend to set one."
    return 0
  fi

  echo ""
  echo "Select frontend type (or None):"
  local -A values=(
    [Next.js]=nextjs
    ["React (Vite)"]=react
    [Angular]=angular
    ["React Native (Expo)"]=react-native
    ["Static HTML"]=static
  )
  select F in "Next.js" "React (Vite)" "Angular" "React Native (Expo)" "Static HTML" "None" "Cancel"; do
    local v="${values[$F]:-}"
    if [ -n "$v" ]; then
      FRONTEND="$v"
      return 0
    fi
    [ "$F" = "None" ]   && return 0
    [ "$F" = "Cancel" ] && exit 1
  done
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
  GHCR_TOKEN=""; MAVEN_USERNAME=""; MAVEN_PASSWORD=""; NPM_TOKEN=""; EXPO_TOKEN=""; SONAR_TOKEN=""; PACT_BROKER_URL=""; GH_TOKEN=""; OPENCODE_API_KEY=""

  if [ ! -t 0 ]; then
    info "Non-interactive stdin — skipping secrets prompt (add secrets manually later)."
    return
  fi

  echo ""
  info "Optional: Add CI secrets now? These go into the generated files as placeholders."
  echo "1) Yes, add secrets placeholders"
  echo "2) Skip (add secrets manually later)"
  read -r SECRETS_CHOICE

  if [ "$SECRETS_CHOICE" != "1" ]; then
    return
  fi

  _prompt_secrets
}

# One read per secret, gated on the language/frontend flags that use it.
_prompt_secrets() {
  read -rp "  GHCR_TOKEN: " GHCR_TOKEN
  if [[ " ${BACKEND[*]} " =~ "java" ]]; then
    read -rp "  MAVEN_USERNAME: " MAVEN_USERNAME
    read -rp "  MAVEN_PASSWORD: " MAVEN_PASSWORD
  fi
  if _wants_npm_token; then
    read -rp "  NPM_TOKEN: " NPM_TOKEN
  fi
  if [ "$FRONTEND" = "react-native" ]; then
    read -rp "  EXPO_TOKEN: " EXPO_TOKEN
  fi
  read -rp "  SONAR_TOKEN (optional): " SONAR_TOKEN
  read -rp "  PACT_BROKER_URL (optional): " PACT_BROKER_URL
  if [ "$WITH_RELEASE_FLAG" = "true" ]; then
    # Release is opt-in (AC-022-03-05): GH_TOKEN is only prompted when the
    # flag is set — a child that never opts in has no required secret.
    read -rp "  GH_TOKEN (Semantic Release, opt-in): " GH_TOKEN
  fi
  if [ "$WITH_PR_REVIEW_FLAG" = "true" ]; then
    # PR review is opt-in (AC-024-04-04/05): OPENCODE_API_KEY is only prompted
    # when the flag is set — a child that never opts in has no required secret.
    read -rp "  OPENCODE_API_KEY (PR review agent, opt-in): " OPENCODE_API_KEY
  fi
}

# NPM_TOKEN is prompted when there is a node backend or any frontend.
_wants_npm_token() {
  _has_node_backend && return 0
  [ -n "$FRONTEND" ] && return 0
  return 1
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
    uses: RexiAI/my-engineering-standards/.github/workflows/backend/ci-${lang}.yml@main
    with:
      docker-registry: $registry
    secrets:
      GHCR_TOKEN: \${{ secrets.GHCR_TOKEN }}
      PACT_BROKER_URL: \${{ secrets.PACT_BROKER_URL }}
EOF
  done

  _gh_frontend_job "$target" "$registry"

  _gh_deploy_job "$target"

  _gh_release_job "$target"

  _gh_pr_review_job "$target"

  ok "Generated: .github/workflows/ci.yml"

  # Copy saga templates when --with-saga
  if [ "$saga_enabled" = "true" ]; then
    _copy_saga_templates
  fi

  _gh_dependabot
  _gh_releaserc
  _copy_go_makefile
}

# Deploy job for production, appended only when --with-deploy is set.
_gh_deploy_job() {
  local target="$1"
  [ "$WITH_DEPLOY_FLAG" != "true" ] && return 0

  cat >> "$target" << EOF

  deploy:
    needs: [$(_gh_deploy_needs)]
    if: \${{ github.event_name == 'push' && github.ref_name == github.event.repository.default_branch }}
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-deploy-${DEPLOY_TOOL}.yml@main
    with:
      service-name: ""
      docker-registry: \$registry
    secrets:
      SSH_HOST: \${{ secrets.SSH_HOST }}
      SSH_USER: \${{ secrets.SSH_USER }}
      SSH_PRIVATE_KEY: \${{ secrets.SSH_PRIVATE_KEY }}
      SSH_PORT: \${{ secrets.SSH_PORT }}
      GHCR_TOKEN: \${{ secrets.GHCR_TOKEN }}
EOF
  ok "Added deploy job to ci.yml (configure SSH_HOST, SSH_USER, SSH_PRIVATE_KEY secrets)"
  info "Deploy tool: ${DEPLOY_TOOL}. Run ./.standards/scripts/init-deploy.sh --deploy-tool ${DEPLOY_TOOL} to set up deploy config"
}

# Release job for Semantic Release, appended only when --with-release is set.
# The reusable ci-release.yml declares a required GH_TOKEN secret but has no
# internal default-branch gate — the condition lives on this job, mirroring
# _gh_deploy_job. No separate release.yml workflow is emitted (AC-022-03-02).
_gh_release_job() {
  local target="$1"
  # Regression guard (AC-022-03-03): without --with-release the default output
  # is byte-compatible with today — no release job, no GH_TOKEN line.
  [ "$WITH_RELEASE_FLAG" != "true" ] && return 0

  cat >> "$target" << EOF

  release:
    if: \${{ github.event_name == 'push' && github.ref_name == github.event.repository.default_branch }}
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-release.yml@main
    secrets:
      GH_TOKEN: \${{ secrets.GH_TOKEN }}
EOF
  ok "Added release job to ci.yml (Semantic Release, default-branch push)"
  info "Set the GH_TOKEN secret (contents: write) in GitHub → Settings → Secrets and variables → Actions"
}

# PR review job for the pr-review agent, appended only when --with-pr-review is
# set. The job calls the shared reusable workflow; reviews are per-PR, so there
# is no default-branch gate — but the job must not run on push events (where
# github.event.pull_request is empty), hence the event_name guard. The job is
# secret-guarded: a child without OPENCODE_API_KEY gets a skipped job, never a
# failure. GitHub Actions-only (AC-024-04-07): on GitLab the flag prints a
# warning and emits nothing.
_gh_pr_review_job() {
  local target="$1"
  # Regression guard (AC-024-04-03): without --with-pr-review the default
  # output is byte-compatible with today — no pr-review job, no
  # OPENCODE_API_KEY line.
  [ "$WITH_PR_REVIEW_FLAG" != "true" ] && return 0

  cat >> "$target" << EOF

  pr-review:
    if: \${{ github.event_name == 'pull_request' && secrets.OPENCODE_API_KEY != '' }}
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/pr-review.yml@main
    with:
      pr-number: \${{ github.event.pull_request.number }}
      head-sha: \${{ github.event.pull_request.head.sha }}
    secrets:
      OPENCODE_API_KEY: \${{ secrets.OPENCODE_API_KEY }}
EOF
  ok "Added pr-review job to ci.yml (PR review agent, per-PR)"
  info "Set the OPENCODE_API_KEY secret (OpenCode Zen) in GitHub → Settings → Secrets and variables → Actions"
}

# Frontend job block: react-native swaps the docker-registry/GHCR pair for a
# node-version/EXPO_TOKEN pair (EAS builds remotely, no registry push).
_gh_frontend_job() {
  local target="$1"
  local registry="$2"
  [ -z "$FRONTEND" ] && return 0

  local workflow="frontend/ci-${FRONTEND}.yml"
  local with_block="      docker-registry: $registry"
  local secrets_block="       GHCR_TOKEN: \${{ secrets.GHCR_TOKEN }}"
  if [ "$FRONTEND" = "react-native" ]; then
    workflow="frontend/ci-react-native.yml"
    with_block="      node-version: \"22\""
    secrets_block="      EXPO_TOKEN: \${{ secrets.EXPO_TOKEN }}"
  fi

  cat >> "$target" << EOF
  frontend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/${workflow}@main
    with:
${with_block}
    secrets:
${secrets_block}
EOF
}

# Comma-separated needs list for the GitHub deploy job (backend + optional frontend).
_gh_deploy_needs() {
  local needs_list=""
  local lang
  for lang in "${BACKEND[@]}"; do
    if [ -n "$needs_list" ]; then
      needs_list="${needs_list}, backend-ci-${lang}"
    else
      needs_list="backend-ci-${lang}"
    fi
  done
  if [ -n "$FRONTEND" ]; then
    if [ -n "$needs_list" ]; then
      needs_list="${needs_list}, frontend-ci"
    else
      needs_list="frontend-ci"
    fi
  fi
  echo "$needs_list"
}

_gh_dependabot() {
  [ -f "$PROJECT_ROOT/.github/dependabot.yml" ] && return 0
  mkdir -p "$PROJECT_ROOT/.github"
  sed "s/LANG_ECOSYSTEM/$(_dependabot_ecosystem)/g" "$STANDARDS_DIR/ci/templates/dependabot.yml" \
    > "$PROJECT_ROOT/.github/dependabot.yml"
  ok "Generated: .github/dependabot.yml"
}

# Last backend language wins (the original loop semantics).
_dependabot_ecosystem() {
  local eco="npm"
  local lang
  for lang in "${BACKEND[@]}"; do
    case $lang in
      java) eco="maven";;
      go)   eco="gomod";;
      node) eco="npm";;
    esac
  done
  echo "$eco"
}

_gh_releaserc() {
  # Never overwrite an existing .releaserc.json (AC-022-03-04/08).
  [ -f "$PROJECT_ROOT/.releaserc.json" ] && return 0
  # Node backend / any frontend: generated on every GitHub run. Java-only or
  # Go-only children: only generated when --with-release is set — a release job
  # without config is broken, so the flag couples the copy (decision D3).
  if _has_node_backend || [ -n "$FRONTEND" ] || [ "$WITH_RELEASE_FLAG" = "true" ]; then
    cp "$STANDARDS_DIR/ci/templates/releaserc.json" "$PROJECT_ROOT/.releaserc.json"
    ok "Generated: .releaserc.json"
  fi
}

_has_node_backend() {
  local lang
  for lang in "${BACKEND[@]}"; do
    [ "$lang" = "node" ] && return 0
  done
  return 1
}

generate_gitlab() {
  local target="$PROJECT_ROOT/.gitlab-ci.yml"
  local registry="${REGISTRY_FLAG:-ghcr.io}"
  local saga_enabled="${WITH_SAGA_FLAG:-false}"

  if [ "$WITH_PR_REVIEW_FLAG" = "true" ]; then
    # GitHub-only feature (AC-024-04-07): warn on GitLab and emit nothing —
    # the shared pr-review workflow has no GitLab template.
    warn "PR review (--with-pr-review) is a GitHub Actions feature — nothing emitted into .gitlab-ci.yml"
  fi

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
  if [ "$WITH_RELEASE_FLAG" = "true" ]; then
    # GitLab symmetric (AC-022-03-06): include the shared release template;
    # no own ci-release.yml copy is emitted (decision D2).
    echo "  - local: .standards/ci/gitlab/shared/ci-release.yml" >> "$target"
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

  _gl_backend_jobs "$target" "$saga_enabled"
  _gl_frontend_job "$target"
  _gl_release_job "$target"
  _gl_deploy_job "$target"

  ok "Generated: .gitlab-ci.yml"
  _copy_go_makefile
}

# Release job (--with-release, AC-022-03-06): extends the .semantic-release
# hidden job from the shared include; the template's own default-branch rule
# applies, so no extra rule is emitted here.
_gl_release_job() {
  local target="$1"
  [ "$WITH_RELEASE_FLAG" != "true" ] && return 0

  cat >> "$target" << EOF

release:
  extends: .semantic-release
EOF
  ok "Added release job to .gitlab-ci.yml (Semantic Release, default-branch rule)"
  info "GitLab: add a project access token with write_repository scope (Settings → CI/CD → Variables)"
}

# Production deploy job (--with-deploy): extends the per-tool deploy template.
_gl_deploy_job() {
  local target="$1"
  [ "$WITH_DEPLOY_FLAG" != "true" ] && return 0

  cat >> "$target" << EOF

include:
  - local: .standards/ci/templates/child-ci-deploy-${DEPLOY_TOOL}.yml

deploy-prod:
  extends: .${DEPLOY_TOOL}-deploy
  stage: deploy
  variables:
    SERVICE_NAME: ""
EOF
  ok "Added deploy-prod job to .gitlab-ci.yml (configure SSH_HOST, SSH_USER, SSH_PRIVATE_KEY CI/CD variables)"
  info "Deploy tool: ${DEPLOY_TOOL}. Run ./.standards/scripts/init-deploy.sh --deploy-tool ${DEPLOY_TOOL} to set up deploy config"
}

_gl_backend_jobs() {
  local target="$1"
  local saga_enabled="$2"
  local lang
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
}

# Frontend jobs for GitLab. React Native shares the unit/lint/build jobs with
# the web frontends (the extends names interpolate through FRONTEND) and only
# swaps the tail job: typecheck+eas instead of docker. Emitted in the original
# job order (unit, lint, typecheck, build, eas) to keep generated output stable.
_gl_frontend_job() {
  local target="$1"
  [ -z "$FRONTEND" ] && return 0

  if [ "$FRONTEND" = "static" ]; then
    cat >> "$target" << EOF

frontend-lint:
  extends: .static-lint
  stage: lint

frontend-docker:
  extends: .static-docker
  stage: docker
EOF
    return 0
  fi

  cat >> "$target" << EOF

frontend-unit:
  extends: .${FRONTEND}-unit
  stage: test

frontend-lint:
  extends: .${FRONTEND}-lint
  stage: lint
EOF

  if [ "$FRONTEND" = "react-native" ]; then
    cat >> "$target" << EOF

frontend-typecheck:
  extends: .react-native-typecheck
  stage: test
EOF
  fi

  cat >> "$target" << EOF

frontend-build:
  extends: .${FRONTEND}-build
  stage: deploy
EOF

  if [ "$FRONTEND" = "react-native" ]; then
    cat >> "$target" << EOF

frontend-eas:
  extends: .react-native-eas
  stage: docker
EOF
  else
    cat >> "$target" << EOF

frontend-docker:
  extends: .${FRONTEND}-docker
  stage: docker
EOF
  fi
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

# Copy Makefile if Go and no existing Makefile — shared by both generators.
_copy_go_makefile() {
  local lang
  for lang in "${BACKEND[@]}"; do
    if [ "$lang" = "go" ] && [ ! -f "$PROJECT_ROOT/Makefile" ]; then
      cp "$STANDARDS_DIR/ci/templates/Makefile.go" "$PROJECT_ROOT/Makefile"
      ok "Generated: Makefile (Go template)"
    fi
  done
}

# ── Step 5: Print summary ─────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo "╔══════════════════════════════════════╗"
  echo "║     CI/CD Generation Complete        ║"
  echo "╚══════════════════════════════════════╝"
  echo ""
  echo "Generated files:"
  _print_generated_files
  echo ""
  echo "Next steps:"
  _print_gh_next_steps
  _print_gl_next_steps
  echo "  3. Review generated files and customize as needed"
  _print_saga_note
  _print_deploy_note
  _print_release_note
  _print_pr_review_note
  echo ""
}

_print_saga_note() {
  [ "${WITH_SAGA_FLAG:-}" != "true" ] && return 0
  echo ""
  echo "Saga/Outbox gate templates copied:"
  echo "  • Fill in TODO markers in the integration test templates"
  echo "  • Java: add pom-fragment.xml dependency to pom.xml"
  echo "  • Node: wire eslint-saga-rules plugin in eslint.config.js"
  echo "  • Reference: docs/SAGA_PATTERN.md §CI Quality Gates"
  echo "               docs/OUTBOX_PATTERN.md §CI Quality Gates"
}

_print_deploy_note() {
  [ "${WITH_DEPLOY_FLAG:-}" != "true" ] && return 0
  echo ""
  echo "Deployment configuration:"
  echo "  • Deploy job added to CI pipeline (tool: ${DEPLOY_TOOL})"
  echo "  • Run ./.standards/scripts/init-deploy.sh --deploy-tool ${DEPLOY_TOOL} to set up deploy config"
  echo "  • Set secrets: SSH_HOST, SSH_USER, SSH_PRIVATE_KEY, SSH_PORT"
  echo "  • Reference: docs/DEPLOYMENT.md §Production Deployment"
}

_print_release_note() {
  # Release note (AC-022-03-05): lists GH_TOKEN / the GitLab token requirement
  # without inventing a variable name the GitLab template does not use.
  [ "${WITH_RELEASE_FLAG:-}" != "true" ] && return 0
  echo ""
  echo "Release (opt-in):"
  echo "  • Release job added to CI pipeline (Semantic Release on default-branch push)"
  case $CI in
    github) echo "  • Set secret: GH_TOKEN (GitHub Actions, contents: write)" ;;
    gitlab) echo "  • Set a project access token with write_repository scope (GitLab)" ;;
    both)   echo "  • GitHub: GH_TOKEN secret; GitLab: project access token with write_repository scope" ;;
  esac
  echo "  • Reference: docs/CI_CD.md §Release Process"
}

_print_pr_review_note() {
  # PR review note (AC-024-04-06): lists OPENCODE_API_KEY with a pointer to
  # the PR review docs when the flag is set.
  [ "${WITH_PR_REVIEW_FLAG:-}" != "true" ] && return 0
  echo ""
  echo "PR review agent (opt-in):"
  echo "  • pr-review job added to ci.yml (per-PR, review + suggested fixes only)"
  echo "  • Set secret: OPENCODE_API_KEY (OpenCode Zen — never commit the value)"
  echo "  • Reference: docs/CI_CD.md §PR Review Agent"
}

_print_generated_files() {
  [ -f .github/workflows/ci.yml ] && echo "  • .github/workflows/ci.yml (backend: ${BACKEND[*]}, frontend: ${FRONTEND:-none})"
  [ -f .github/dependabot.yml ]   && echo "  • .github/dependabot.yml"
  [ -f .gitlab-ci.yml ]           && echo "  • .gitlab-ci.yml"
  [ -f .releaserc.json ]          && echo "  • .releaserc.json"
  [ -f Makefile ]                 && echo "  • Makefile"
  true
}

# Print "     - SECRET (description)" for every secret captured above.
_print_gh_secrets() {
  while read -r name label; do
    [ -n "${!name}" ] && echo "     - $label"
  done <<'EOF'
GHCR_TOKEN GHCR_TOKEN (GitHub Container Registry token)
MAVEN_USERNAME MAVEN_USERNAME
MAVEN_PASSWORD MAVEN_PASSWORD
NPM_TOKEN NPM_TOKEN
EXPO_TOKEN EXPO_TOKEN (Expo/EAS build, merge-to-main only)
SONAR_TOKEN SONAR_TOKEN (optional)
PACT_BROKER_URL PACT_BROKER_URL (optional)
GH_TOKEN GH_TOKEN (Semantic Release, opt-in only)
OPENCODE_API_KEY OPENCODE_API_KEY (PR review agent, opt-in only)
EOF
  true
}

_print_gh_next_steps() {
  case $CI in
    github|both)
      echo "  1. Add repo secrets in GitHub → Settings → Secrets and variables → Actions:"
      _print_gh_secrets
      echo "  2. Push and check Actions tab"
      ;;
  esac
}

_print_gl_next_steps() {
  case $CI in
    gitlab|both)
      echo "  1. Add CI/CD variables in GitLab → Settings → CI/CD → Variables"
      echo "  2. Push and check Pipelines tab"
      ;;
  esac
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
