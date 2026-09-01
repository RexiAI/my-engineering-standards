#!/usr/bin/env bash
# init-deploy.sh — Setup production deployment infrastructure
# Usage: Run from project root to configure deployment for a VPS.
#
#   --deploy-tool kamal|dokku|ssh   Deploy backend (default: kamal)
#   --platform github|gitlab|both   CI platform to wire up
#   --host IP                        VPS IP/hostname
#   --port 22                        SSH port
#   --user root                      SSH user
#   --app-domain domain              Domain for TLS/HTTPS
#   --service-name name              Service/app name
#   --backend java|go|node           Language (for healthcheck defaults)
#   --frontend nextjs|react|angular|static
#   --registry ghcr.io               Container registry

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Commit SHA this repo's own reusable workflows are pinned to when generated
# into a child repo (spec 026, AC-026-13; docs/SECURITY.md §CI/CD Supply
# Chain). Never `@main` — see scripts/init-ci.sh's STANDARDS_PIN, the same
# constant duplicated here because this script generates its own ci.yml
# independently. Bump both together.
STANDARDS_PIN="21046d96796467f8238d6d613ce3a552bf3fced0"

info() { echo -e "${CYAN}ℹ${NC} $1"; }
ok() { echo -e "${GREEN}✔${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }
err() { echo -e "${RED}✘${NC} $1"; }

# ── Parse CLI flags ──────────────────────────────────────────────────────────
PLATFORM=""
HOST=""
PORT=""
USER=""
APP_DOMAIN=""
SERVICE_NAME=""
BACKEND=""
FRONTEND=""
REGISTRY=""
DEPLOY_TOOL="kamal"

while [[ $# -gt 0 ]]; do
  case $1 in
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --user)
      USER="$2"
      shift 2
      ;;
    --app-domain)
      APP_DOMAIN="$2"
      shift 2
      ;;
    --service-name)
      SERVICE_NAME="$2"
      shift 2
      ;;
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    --frontend)
      FRONTEND="$2"
      shift 2
      ;;
    --registry)
      REGISTRY="$2"
      shift 2
      ;;
    --deploy-tool)
      DEPLOY_TOOL="$2"
      shift 2
      ;;
    *)
      err "Unknown flag: $1"
      echo "Usage: $0 [--deploy-tool kamal|dokku|ssh] [--platform github|gitlab|both] [--host IP] [--port 22] [--user root] [--app-domain domain] [--service-name name] [--backend java|go|node] [--frontend nextjs|react|angular|static] [--registry ghcr.io]"
      exit 1
      ;;
  esac
done

case "$DEPLOY_TOOL" in
  kamal|dokku|ssh) ;;
  *) err "Invalid --deploy-tool '$DEPLOY_TOOL' (expected kamal|dokku|ssh)"; exit 1 ;;
esac

# ── Detect project root ───────────────────────────────────────────────────────
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
ok "Deploy tool: $DEPLOY_TOOL"

# ── Collect VPS details ─────────────────────────────────────────────────────────
if [ -z "$HOST" ]; then
  echo ""
  info "Enter production server details (VPS/IP)."
  read -rp "  Host IP: " HOST
  if [ -z "$PORT" ]; then
    read -rp "  SSH Port [22]: " PORT
    PORT=${PORT:-"22"}
  fi
  if [ -z "$USER" ]; then
    read -rp "  SSH User [${DEPLOY_TOOL}]: " USER
    if [ -z "$USER" ]; then
      if [ "$DEPLOY_TOOL" = "dokku" ]; then USER="dokku"; else USER="root"; fi
    fi
  fi
fi

if [ -z "$APP_DOMAIN" ]; then
  read -rp "  App domain (used for HTTPS): " APP_DOMAIN
  if [ -z "$APP_DOMAIN" ]; then
    APP_DOMAIN="${SERVICE_NAME:-my-service}.example.com"
    echo "    Using default: $APP_DOMAIN"
  fi
fi

if [ -z "$SERVICE_NAME" ]; then
  read -rp "  Service name [my-service]: " SERVICE_NAME
  if [ -z "$SERVICE_NAME" ]; then
    SERVICE_NAME="my-service"
  fi
fi

if [ -z "$REGISTRY" ]; then
  REGISTRY="ghcr.io"
  echo "    Using default registry: $REGISTRY"
fi

# ── Detect language for defaults ─────────────────────────────────────────────
if [ -z "$BACKEND" ] && [ -z "$FRONTEND" ]; then
  if [ -f "pom.xml" ]; then
    BACKEND="java"
    info "Backend: Java (Maven)"
  elif [ -f "go.mod" ]; then
    BACKEND="go"
    info "Backend: Go"
  elif [ -f "package.json" ]; then
    FRONTEND="detect"
    info "Node.js detected, determining frontend type..."
  fi
fi

if [ "$FRONTEND" = "detect" ]; then
  if grep -q '"next"' package.json 2>/dev/null; then
    FRONTEND="nextjs"
  elif grep -q '"react"' package.json 2>/dev/null; then
    FRONTEND="react"
  elif grep -q '"@angular"' package.json 2>/dev/null; then
    FRONTEND="angular"
  elif grep -q '"vite"' package.json 2>/dev/null; then
    FRONTEND="react"
  else
    FRONTEND="none"
  fi
  info "Frontend: $FRONTEND"
fi

# ── Ask for SSH private key ───────────────────────────────────────────────────
echo ""
info "SSH private key for ${DEPLOY_TOOL} deploys"
echo "Generate one with: ssh-keygen -t ed25519 -C deploy@$HOST -f ~/.ssh/deploy@$HOST"
if [ ! -d ".deploy/secrets" ]; then
  mkdir -p ".deploy/secrets"
fi
SSH_KEY="$HOME/.ssh/deploy@$HOST"
if [ ! -f "$SSH_KEY" ]; then
  echo "    No SSH key found at $SSH_KEY"
  warn "You must add the SSH private key to .deploy/secrets/id_rsa before first deploy"
else
  cp "$SSH_KEY" ".deploy/secrets/id_rsa"
  chmod 600 ".deploy/secrets/id_rsa"
  ok "SSH key copied to .deploy/secrets/id_rsa"
fi

# ── Per-tool setup ─────────────────────────────────────────────────────────────

# Kamal: generate .kamal/config.rb + .kamal/.env.example
setup_kamal() {
  info "Setting up Kamal deploy config..."
  if [ ! -d ".kamal" ]; then
    mkdir -p ".kamal"
  fi

  if [ ! -f ".kamal/config.rb" ]; then
    cp "$STANDARDS_DIR/templates/Kamalfile" ".kamal/config.rb"
    ok "Generated: .kamal/config.rb (edit to customize)"
  fi

  if [ ! -f ".kamal/.env.example" ]; then
    cat > ".kamal/.env.example" << EOF
# Kamal deployment environment variables
# Copy this file to .kamal/.env and update values before first deploy

# Required secrets (set in CI:
#   SSH_HOST, SSH_USER, SSH_PORT, SSH_PRIVATE_KEY)
export KAMAL_HOST=$HOST
export KAMAL_USER=$USER
export KAMAL_PORT=${PORT:-22}
export KAMAL_SSH_KEY=\${HOME}/.ssh/id_rsa  # Override with your actual path

# Optional: Service-specific config
export SERVICE_NAME=$SERVICE_NAME
export APP_DOMAIN=$APP_DOMAIN
export LOG_LEVEL=info
EOF
    ok "Generated: .kamal/.env.example"
  fi
}

# Dokku: verify SSH, create app, record config
setup_dokku() {
  info "Setting up Dokku deploy config..."
  if [ ! -d ".deploy" ]; then
    mkdir -p ".deploy"
  fi

  if [ ! -f ".deploy/dokku.env.example" ]; then
    cat > ".deploy/dokku.env.example" << EOF
# Dokku deployment environment variables
# Copy this file to .deploy/dokku.env and update values before first deploy

# Required secrets (set in CI:
#   SSH_HOST, SSH_PRIVATE_KEY, [SSH_USER=dokku])
export SSH_HOST=$HOST
export SSH_USER=$USER
export SSH_PORT=${PORT:-22}
export DOKKU_APP_NAME=$SERVICE_NAME
export DOKKU_IMAGE=$REGISTRY/${SERVICE_NAME}:latest
export APP_DOMAIN=$APP_DOMAIN
EOF
    ok "Generated: .deploy/dokku.env.example"
  fi

  echo ""
  info "One-time Dokku app setup (run on your machine, once):"
  echo "  ssh -p ${PORT:-22} $USER@$HOST 'dokku apps:create $SERVICE_NAME'"
  echo "  ssh -p ${PORT:-22} $USER@$HOST 'dokku letsencrypt:enable $SERVICE_NAME'"
}

# Raw SSH: copy docker-compose.prod.yml + nginx.conf + setup-host.sh
setup_ssh() {
  info "Setting up SSH + Docker Compose deploy config..."

  if [ ! -f "docker-compose.prod.yml" ]; then
    cp "$STANDARDS_DIR/templates/docker-compose.prod.yml" "docker-compose.prod.yml"
    ok "Generated: docker-compose.prod.yml (edit to customize)"
  fi

  if [ ! -f "nginx.conf" ]; then
    cp "$STANDARDS_DIR/templates/nginx.conf" "nginx.conf"
    ok "Generated: nginx.conf (replace example.com with $APP_DOMAIN)"
  fi

  if [ ! -f "setup-host.sh" ]; then
    cp "$STANDARDS_DIR/templates/setup-host.sh" "setup-host.sh"
    chmod +x "setup-host.sh"
    ok "Generated: setup-host.sh (run on the VPS once)"
  fi

  if [ ! -f ".deploy/env.example" ]; then
    mkdir -p ".deploy"
    cat > ".deploy/env.example" << EOF
# SSH + Compose deployment environment variables
# Copy this file to .deploy/env and update values before first deploy

# Required secrets (set in CI:
#   SSH_HOST, SSH_PRIVATE_KEY, [SSH_USER=root])
export SSH_HOST=$HOST
export SSH_USER=$USER
export SSH_PORT=${PORT:-22}
export APP_DIR=/opt/$SERVICE_NAME
export APP_DOMAIN=$APP_DOMAIN
export DEPLOY_IMAGE=$REGISTRY/${SERVICE_NAME}:latest
EOF
    ok "Generated: .deploy/env.example"
  fi

  echo ""
  info "One-time host setup (SSH into the VPS and run):"
  echo "  scp setup-host.sh root@$HOST:/tmp/"
  echo "  ssh root@$HOST 'bash /tmp/setup-host.sh --backend ssh --domain $APP_DOMAIN'"
}

case "$DEPLOY_TOOL" in
  kamal) setup_kamal ;;
  dokku) setup_dokku ;;
  ssh)   setup_ssh ;;
esac

# ── Generate CI deploy workflow ───────────────────────────────────────────────
if [ -n "$PLATFORM" ] || [ ! -t 0 ]; then
  info "Generating CI deploy workflow reference (tool: $DEPLOY_TOOL)..."
  mkdir -p ".github/workflows"
  if [ ! -f ".github/workflows/ci.yml" ]; then
    cat > ".github/workflows/ci.yml" << EOF
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  backend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/ci-${BACKEND:-go}.yml@${STANDARDS_PIN} # pinned; bump deliberately, never track a branch
    with:
      docker-registry: $REGISTRY
    secrets:
      GHCR_TOKEN: \${ secrets.GHCR_TOKEN }

  deploy:
    needs: [backend-ci]
    if: \${ github.event_name == 'push' && github.ref_name == github.ref }
    uses: RexiAI/my-engineering-standards/.github/workflows/ci-deploy-${DEPLOY_TOOL}.yml@${STANDARDS_PIN} # pinned; bump deliberately, never track a branch
    with:
      service-name: $SERVICE_NAME
      docker-registry: $REGISTRY
    secrets:
      SSH_HOST: \${ secrets.SSH_HOST }
      SSH_USER: \${ secrets.SSH_USER }
      SSH_PRIVATE_KEY: \${ secrets.SSH_PRIVATE_KEY }
      SSH_PORT: \${ secrets.SSH_PORT }
      GHCR_TOKEN: \${ secrets.GHCR_TOKEN }
EOF
    ok "Generated: .github/workflows/ci.yml (customize jobs as needed)"
  else
    warn "ci.yml already exists — add the deploy job manually:"
    echo "  uses: RexiAI/my-engineering-standards/.github/workflows/ci-deploy-${DEPLOY_TOOL}.yml@${STANDARDS_PIN} # pinned; bump deliberately, never track a branch"
  fi
fi

# ── Generate GitLab CI include ─────────────────────────────────────────────────
if [ -n "$PLATFORM" ] || [ ! -t 0 ]; then
  info "Generating GitLab CI include (tool: $DEPLOY_TOOL)..."
  if [ ! -f ".gitlab-ci.yml" ]; then
    cat > ".gitlab-ci.yml" << EOF
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-${BACKEND:-go}.yml
  - local: .standards/ci/templates/child-ci-deploy-${DEPLOY_TOOL}.yml

variables:
  CI_REGISTRY: $REGISTRY

# ── Deploy stage ───────────────────────────────────
deploy:
  extends: .${DEPLOY_TOOL}-deploy
  stage: deploy
  variables:
    SERVICE_NAME: "$SERVICE_NAME"
EOF
    ok "Generated: .gitlab-ci.yml"
  else
    warn ".gitlab-ci.yml already exists — add the include manually:"
    echo "  - local: .standards/ci/templates/child-ci-deploy-${DEPLOY_TOOL}.yml"
  fi
fi

# ── Print summary ─────────────────────────────────────────────────────────────────
echo ""
print_summary() {
  echo "╔════════════════════════════════════╗"
  echo "║  🚀  Deployment Setup Complete     ║"
  echo "╚════════════════════════════════════╝"
  echo ""
  echo "Deploy tool: $DEPLOY_TOOL"
  echo "SSH host: $HOST"
  echo "Service name: $SERVICE_NAME"
  echo "App domain: $APP_DOMAIN"
  echo "Registry: $REGISTRY"
  echo ""
  case "$DEPLOY_TOOL" in
    kamal)
      echo "Kamal configuration: .kamal/"
      echo "  • config.rb    — edit this file for custom settings"
      echo "  • .env.example — environment template (copy to .env)"
      echo "  • secrets/id_rsa — SSH private key"
      ;;
    dokku)
      echo "Dokku configuration: .deploy/"
      echo "  • dokku.env.example — environment template"
      echo "  • secrets/id_rsa — SSH private key"
      ;;
    ssh)
      echo "SSH + Compose configuration:"
      echo "  • docker-compose.prod.yml — production compose"
      echo "  • nginx.conf — reverse proxy + TLS"
      echo "  • setup-host.sh — one-time VPS bootstrap"
      echo "  • .deploy/env.example — environment template"
      ;;
  esac
  echo ""
  echo "Required CI secrets (GitHub/GitLab Settings → Secrets):"
  echo "  SSH_HOST=$HOST"
  echo "  SSH_USER=$USER"
  echo "  SSH_PRIVATE_KEY=<contents of .deploy/secrets/id_rsa>"
  echo "  SSH_PORT=${PORT:-22}"
  [ "$DEPLOY_TOOL" = "dokku" ] && echo "  DOKKU_APP_NAME=$SERVICE_NAME"
  [ "$DEPLOY_TOOL" = "ssh" ] && echo "  APP_DIR=/opt/$SERVICE_NAME"
  echo ""
  echo "Deploy step in CI:"
  echo "  • Uses ci-deploy-${DEPLOY_TOOL}.yml (GitHub) or child-ci-deploy-${DEPLOY_TOOL}.yml (GitLab)"
  echo "  • Skips gracefully if secrets are missing (guard clause)"
  echo ""
  echo "Next steps:"
  echo "  1. Run the one-time host setup (see output above)"
  echo "  2. Add secrets to CI (SSH_HOST, SSH_USER, SSH_PRIVATE_KEY, SSH_PORT)"
  echo "  3. Push and verify CI pipeline deploys successfully"
}

print_summary

echo ""
echo "=== Deploy setup finished ==="
echo "See docs/DEPLOYMENT.md §Production Deployment for the full guide."
