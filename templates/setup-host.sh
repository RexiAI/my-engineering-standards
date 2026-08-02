#!/usr/bin/env bash
# setup-host.sh — One-time VPS bootstrap for the deploy backends.
#
# Usage (run on the target host, not in CI):
#   scp templates/setup-host.sh root@HOST:/tmp/setup-host.sh
#   ssh root@HOST "bash /tmp/setup-host.sh --backend kamal|dokku|ssh [--domain example.com]"
#
#   --backend   Deploy backend to prepare the host for:
#                 kamal   → install Docker (Kamal manages Traefik itself)
#                 dokku   → install Dokku PaaS + letsencrypt plugin
#                 ssh     → install Docker + nginx + certbot, set renewal cron
#   --domain    Required for --backend ssh (used in nginx server_name).
#   --app-name  Dokku app name (--backend dokku, optional, default from --domain).
#
# Idempotent: safe to re-run. Skips already-installed components.
set -euo pipefail

BACKEND=""
DOMAIN=""
APP_NAME=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --backend)
      BACKEND="$2"
      shift 2
      ;;
    --domain)
      DOMAIN="$2"
      shift 2
      ;;
    --app-name)
      APP_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown flag: $1"
      echo "Usage: $0 --backend kamal|dokku|ssh [--domain example.com] [--app-name app]"
      exit 1
      ;;
  esac
done

if [ -z "$BACKEND" ]; then
  echo "ERROR: --backend required (kamal|dokku|ssh)"
  exit 1
fi

case "$BACKEND" in
  kamal|dokku|ssh) ;;
  *) echo "ERROR: invalid backend '$BACKEND' (expected kamal|dokku|ssh)"; exit 1 ;;
esac

if [ "$BACKEND" = "ssh" ] && [ -z "$DOMAIN" ]; then
  echo "ERROR: --domain is required for --backend ssh"
  exit 1
fi

echo "=== Setting up host for backend: $BACKEND ==="

# ── Detect OS ────────────────────────────────────────────────────────────────
if [ -f /etc/os-release ]; then
  . /etc/os-release
else
  ID="unknown"
fi

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "  [SKIP] docker already installed"
    return
  fi
  echo "  Installing Docker..."
  if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$ID/gpg \
      | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
       https://download.docker.com/linux/$ID $VERSION_CODENAME stable" \
      > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl enable --now docker
  else
    echo "  Unsupported OS for Docker auto-install. Install Docker manually."
    exit 1
  fi
  echo "  [OK] docker installed"
}

# ── Backend: kamal ───────────────────────────────────────────────────────────
if [ "$BACKEND" = "kamal" ]; then
  echo "Preparing host for Kamal deploys..."
  install_docker
  echo ""
  echo "=== Done. Host ready for Kamal. ==="
  echo "Next: from your repo run ./.standards/scripts/init-deploy.sh --deploy-tool kamal"
  exit 0
fi

# ── Backend: dokku ───────────────────────────────────────────────────────────
if [ "$BACKEND" = "dokku" ]; then
  echo "Installing Dokku..."
  if command -v dokku >/dev/null 2>&1; then
    echo "  [SKIP] dokku already installed"
  else
    wget https://raw.githubusercontent.com/dokku/dokku/v0.34.7/bootstrap.sh -O /tmp/dokku-bootstrap.sh
    bash /tmp/dokku-bootstrap.sh
  fi

  echo "  Installing letsencrypt plugin..."
  dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
  dokku config:set --global DOKKU_LETSENCRYPT_EMAIL="${DOKKU_LETSENCRYPT_EMAIL:-admin@${DOMAIN:-example.com}}"

  if [ -n "$DOMAIN" ]; then
    echo "  Setting domain to $DOMAIN..."
    dokku domains:set-global "$DOMAIN"
  fi

  echo ""
  echo "=== Done. Host ready for Dokku. ==="
  echo "Next steps:"
  echo "  1. Add your SSH key:  ssh-copy-id root@<HOST>  (dokku uses root keys)"
  echo "  2. From your repo:    ./.standards/scripts/init-deploy.sh --deploy-tool dokku"
  echo "  3. Create app once:   dokku apps:create ${APP_NAME:-<service-name>}"
  echo "  4. Enable TLS:        dokku letsencrypt:enable ${APP_NAME:-<service-name>}"
  exit 0
fi

# ── Backend: ssh (raw docker compose + nginx + certbot) ──────────────────────
if [ "$BACKEND" = "ssh" ]; then
  echo "Preparing host for raw SSH + Docker Compose deploys..."
  install_docker

  echo "  Installing nginx + certbot..."
  if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
    apt-get update -y
    apt-get install -y nginx certbot python3-certbot-nginx
  else
    echo "  Unsupported OS for nginx/certbot auto-install. Install manually."
    exit 1
  fi

  echo "  Creating certbot webroot..."
  mkdir -p /var/www/certbot

  echo "  Setting up TLS renewal cron..."
  cat > /etc/cron.d/certbot-renew << 'CRON'
SHELL=/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
0 3 * * * root certbot renew --webroot -w /var/www/certbot --quiet --deploy-hook "systemctl reload nginx"
CRON

  echo ""
  echo "=== Done. Host ready for SSH + Compose deploys. ==="
  echo "Next steps:"
  echo "  1. Copy templates to repo:  cp templates/nginx.conf nginx.conf"
  echo "                              cp templates/docker-compose.prod.yml ."
  echo "  2. Edit nginx.conf:         replace example.com with $DOMAIN"
  echo "  3. Install nginx site + cert:"
  echo "       scp nginx.conf root@<HOST>:/etc/nginx/sites-available/$DOMAIN.conf"
  echo "       ssh root@<HOST> 'ln -sf /etc/nginx/sites-available/$DOMAIN.conf /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx'"
  echo "       ssh root@<HOST> 'certbot --nginx -d $DOMAIN'"
  echo "  4. Deploy dir:              /opt/<service-name> (created by CI on first deploy)"
  exit 0
fi
