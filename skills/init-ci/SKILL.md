---
name: init-ci
description: Generate CI/CD files for a child repo. Auto-detects languages, prompts for CI platform (GitHub or GitLab), and emits the platform-specific workflow files that inherit from the parent templates in this standards repo. Use when a user says "set up CI" or after bootstrap when a new child repo does not yet have CI.
license: See repo root
allowed-tools: Bash(.standards/scripts/init-ci.sh:*) Bash(./.standards/scripts/init-ci.sh:*) Bash(git:*)
---

# When to use

When a child project needs CI/CD generated that conforms to this standards repo's `.github/workflows/` or `.gitlab/` templates. Detects what language(s) the project uses and which CI platform is in use; produces the right files.

# Invocation

Run from the repo root:

```bash
# Interactive
./.standards/scripts/init-ci.sh

# Pre-filled (preferred for agents)
./.standards/scripts/init-ci.sh \
  --platform github \
  --languages java,go \
  --registry ghcr.io
```

## Flags

- `--platform github|gitlab|both` — required if non-interactive
- `--languages java,go,node,react,react-native` — comma-separated, required if non-interactive
- `--registry ghcr.io` (or your registry) — used for image names in deploy jobs

# What the script does

1. Detects the languages used in the child repo (manifest files: `pom.xml`, `go.mod`, `package.json`, `app.json`, etc.).
2. Copies the matching template files from this standards repo:
   - `ci/github/workflows/*` or `ci/gitlab/*`
   - `ci/templates/archunit/*`, `ci/templates/eslint-saga-rules/*`, etc.
3. Adjusts image references to the chosen registry.
4. Commits the result on a `feat/ci-initial` branch (does not push).

# Permissions note

The script commits locally but does not push. The child repo's pipeline agent or the human runs `git push -u origin feat/ci-initial` and opens the PR.
