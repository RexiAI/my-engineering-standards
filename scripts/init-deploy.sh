#!/usr/bin/env bash
# init-deploy.sh — Setup production deployment infrastructure
# Usage: Run from project root to configure Kamal for VPS deployment

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    *)
      err "Unknown flag: $1"
      echo "Usage: $0 [--platform github|gitlab|both] [--host IP] [--port 22] [--user root] [--app-domain domain] [--service-name name] [--backend java|go|node] [--frontend nextjs|react|angular|static] [--registry ghcr.io]"
      exit 1
      ;;
  esac
done

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
    read -rp "  SSH User [root]: " USER
    USER=${USER:-"root"}
  fi
fi

if [ -z "$APP_DOMAIN" ]; then
  read -rp "  App domain (used for Traefik/HTTPS): " APP_DOMAIN
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
info "Add SSH private key to .kamal/secrets directory"
echo "Generate one with: ssh-keygen -t ed25519 -C deploy@$HOST -f ~/.ssh/deploy@$HOST"
if [ ! -d ".kamal/secrets" ]; then
  mkdir -p ".kamal/secrets"
fi
SSH_KEY="$HOME/.ssh/deploy@$HOST"
if [ ! -f "$SSH_KEY" ]; then
  echo "    No SSH key found at $SSH_KEY"
  warn "You must add the SSH private key to .kamal/secrets/id_rsa before first deploy"
else
  cp "$SSH_KEY" ".kamal/secrets/id_rsa"
  chmod 600 ".kamal/secrets/id_rsa"
  ok "SSH key copied to .kamal/secrets/id_rsa"
fi

# ── Generate Kamal config ─────────────────────────────────────────────────────
if [ ! -d ".kamal" ]; then
  mkdir -p ".kamal"
fi

if [ ! -f ".kamal/config.rb" ]; then
  cp "$STANDARDS_DIR/templates/Kamalfile" ".kamal/config.rb"
  ok "Generated: .kamal/config.rb (edit to customize)"
fi

if [ ! -f ".kamal/.env.example" ]; then
  cat > ".kamal/.env.example" << 'EOF'
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

# Database, cache, etc.
# export DATABASE_URL=postgresql://user:pass@host:5432/db
# export REDIS_URL=redis://host:6379/0
EOF
  ok "Generated: .kamal/.env.example"
fi

# ── Generate CI deploy workflow ───────────────────────────────────────────────
if [ -n "$PLATFORM" ] || [ ! -t 0 ]; then
  info "Generating CI deploy workflow reference..."
  mkdir -p ".github/workflows"
  if [ ! -f ".github/workflows/ci.yml" ]; then
    cat > ".github/workflows/ci.yml" << 'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

jobs:
  backend-ci:
    uses: RexiAI/my-engineering-standards/.github/workflows/backend/ci-${BACKEND:-go}.yml@main
    with:
      docker-registry: $REGISTRY
    secrets:
      GHCR_TOKEN: ${ secrets.GHCR_TOKEN }

  deploy:
    needs: [backend-ci]
    if: ${ github.event_name == 'push' && github.ref_name == github.ref }
    uses: RexiAI/my-engineering-standards/.github/workflows/shared/ci-deploy.yml@main
    with:
      service-name: $SERVICE_NAME
      docker-registry: $REGISTRY
    secrets:
      SSH_HOST: ${ secrets.SSH_HOST }
      SSH_USER: ${ secrets.SSH_USER }
      SSH_PRIVATE_KEY: ${ secrets.SSH_PRIVATE_KEY }
      SSH_PORT: ${ secrets.SSH_PORT }
      GHCR_TOKEN: ${ secrets.GHCR_TOKEN }
EOF
    ok "Generated: .github/workflows/ci.yml (customize jobs as needed)"
  fi
fi

# ── Generate GitLab CI include ─────────────────────────────────────────────────
if [ -n "$PLATFORM" ] || [ ! -t 0 ]; then
  info "Generating GitLab CI include..."
  if [ ! -f ".gitlab-ci.yml" ]; then
    cat > ".gitlab-ci.yml" << 'EOF'
include:
  - local: .standards/ci/gitlab/gitlab-ci.yml
  - local: .standards/ci/gitlab/backend/ci-${BACKEND:-go}.yml

variables:
  CI_REGISTRY: $REGISTRY

# ── Deploy stage ───────────────────────────────────
deploy:
  extends: .ci-docker
  stage: deploy
  script:
    - echo "Kamal deploy: [Service: $SERVICE_NAME on $HOST]"
    - echo "⚠️  Set required secrets before running:"
    - echo "   SSH_HOST, SSH_USER, SSH_PRIVATE_KEY, SSH_PORT"
    - echo "   Then uncomment this line and run kamal deploy:"
    - echo "   # kamal deploy --verbose"
  rules:
    - if: \$CI_COMMIT_BRANCH == \$CI_DEFAULT_BRANCH
  allow_failure: false
EOF
    ok "Generated: .gitlab-ci.yml"
  fi
fi

# ── Print summary ─────────────────────────────────────────────────────────────────
echo ""
print_summary() {
  echo "╔════════════════════════════════════╗"
  echo "║  🚀  Deployment Setup Complete     ║"
  echo "╚════════════════════════════════════╝"
  echo ""
  echo "Kamal configuration: .kamal/"
  echo "  • config.rb    — edit this file for custom settings"
  echo "  • .env.example — environment template (copy to .env)"
  echo "  • secrets/id_rsa — SSH private key"
  echo ""
  echo "SSH host: $HOST"
  echo "Service name: $SERVICE_NAME"
  echo "App domain: $APP_DOMAIN"
  echo "Registry: $REGISTRY"
  echo ""
  echo "Required CI secrets (GitHub/GitLab Settings → Secrets):"
  echo "  SSH_HOST=$HOST"
  echo "  SSH_USER=$USER"
  echo "  SSH_PRIVATE_KEY=<contents of .kamal/secrets/id_rsa>"
  echo "  SSH_PORT=${PORT:-22}"
  echo ""
  echo "Deploy step in CI:"
  echo "  • Uses .github/workflows/shared/ci-deploy.yml or .gitlab-ci.yml:deploy"
  echo "  • Will deploy using Kamal if secrets are present"
  echo ""
  echo "Next steps:"
  echo "  1. Copy .kamal/.env.example → .kamal/.env and update values"
  echo "  2. Ensure .kamal/secrets/id_rsa is populated"
  echo "  3. Add secrets to CI (SSH_HOST, SSH_USER, SSH_PRIVATE_KEY, SSH_PORT)"
  echo "  4. Push and verify CI pipeline deploys successfully"
}

print_summary

# ── Environment check ─────────────────────────────────────────────────────────
echo ""
info "Environment check:"
if command -v kamal >/dev/null 2>&1; then
  ok "kamal CLI available"
else
  warn "Kamal CLI not found — install with: curl -fsSL https://get.kamal.dev | bash"
fi

if [ -n "$HOST" ]; then
  if ping -c1 "$HOST" >/dev/null 2>&1; then
    ok "Host reachable"
  else
    warn "Host $HOST not reachable — verify server is online"
  fi
fi

echo ""
echo "=== Deploy setup finished ==="
echo "See docs/DEPLOYMENT.md for full deployment guide."

