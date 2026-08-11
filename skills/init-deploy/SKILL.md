---
name: init-deploy
description: Set up production deployment infrastructure for a child repo on a VPS — Kamal, Dokku, or plain SSH. Wires the chosen deploy tool to the CI platform. Use when a user says "I need to deploy this", after CI is wired, or when bootstrapping a new service to a fresh VPS.
license: See repo root
allowed-tools: Bash(.standards/scripts/init-deploy.sh:*) Bash(./.standards/scripts/init-deploy.sh:*) Bash(ssh:*) Bash(kamal:*)
---

# When to use

When a child repo needs deploy infrastructure on a VPS — Kamal (Rails-style Docker push), Dokku (git-push-to-deploy), or plain SSH + Compose. Auto-detects CI platform already configured by `init-ci` and links the deploy tool's release step to it.

# Invocation

Run from the project root. The script reads most inputs from env vars; populate them first.

```bash
export HOST=203.0.113.10
export SERVICE_NAME=my-service
export APP_DOMAIN=my-service.example.com
export REGISTRY=ghcr.io/my-org
./.standards/scripts/init-deploy.sh \
  --deploy-tool kamal \
  --platform github \
  --backend java \
  --frontend none
```

## Flags

- `--deploy-tool kamal|dokku|ssh` — default `kamal`
- `--platform github|gitlab|both` — default `both`
- `--host IP` — VPS IP/hostname
- `--port 22` — SSH port
- `--user root` — SSH user
- `--app-domain domain` — for TLS/HTTPS
- `--service-name name` — service/app name
- `--backend java|go|node` — healthcheck defaults
- `--frontend nextjs|react|angular|static|none`
- `--registry ghcr.io` — container registry

# What the script does

1. Writes `.kamal/secrets` (or Dokku/SSH equivalents) — never commits secrets; uses `getpass` or env.
2. Wires the deploy tool's release step to the CI platform's `push` event.
3. Generates a `Makefile` target (`make deploy`) for manual invocations.
4. Prints the next-step checklist (DNS, TLS, secrets manager).

# Permissions note

The script shells out to `ssh` and the deploy tool. Approve those calls when running through the agent loop, or invoke the script directly from a human-driven shell.
