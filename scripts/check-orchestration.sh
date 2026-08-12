#!/bin/bash
# check-orchestration.sh — Verify every cross-reference in the orchestration
# layer (commands/, agents/, skills/, scripts/, docs/) resolves to a real file.
#
# The spec pipeline orchestration (commands/, agents/, skills/, scripts/) is a
# program too, but nothing verifies its wiring. A subagent referenced in a
# command, a skill named in an agent, or a script invoked by the verifier can
# silently not exist — the failure surfaces mid-run, after the expensive
# stages. This script is a model-free dry-run pointed inward: it asserts every
# such reference resolves before the pipeline is trusted to run.
#
# Checks:
#   1. Agent references — every agent name cited in commands/*.md and agents/*.md
#      (YAML `agent:` frontmatter, backtick-quoted `spec-*` tokens, and literal
#      `agent_type='...'` / `agent_type="..."` assignments) resolves to
#      `agents/<name>.md`.
#   2. Skill references — every skill cited in agents/*.md (backtick-quoted name
#      on a line mentioning skill, or a `name: <name>` assignment) resolves to
#      `skills/<name>/SKILL.md`.
#   3. scripts/ paths — every `scripts/<file>.sh`/`.ps1` path cited in
#      agents/, commands/, and AGENTS.md resolves to an existing file (a
#      `.sh`/`.ps1` twin counts as resolving). `.standards/scripts/…` child-repo
#      paths are NOT repo scripts/ references and are not matched.
#   4. docs/ and language-specific/ refs — every `docs/[A-Z_]+.md` and
#      `language-specific/[a-z]+/SKILL.md` cross-reference in agents/*.md
#      resolves. The `<lang>` template placeholder is never matched.
#
# Usage:
#   scripts/check-orchestration.sh [ROOT]
#   ROOT defaults to the repo root (parent of scripts/). Pass a scratch
#   directory to check an isolated commands/ + agents/ tree (used by the
#   acceptance tests for AC-001 and friends without touching the real repo).
#
# Exit codes:
#   0 — every orchestration reference resolves
#   1 — at least one dangling reference; each prints
#       `[BROKEN] <citing-file> -> <broken-ref>`
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Orchestration self-conformance (spec 006)
set -euo pipefail

ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT="$(dirname "$SCRIPT_DIR")"
fi
ROOT="$(cd "$ROOT" && pwd)"

BROKEN=0

broken() { # broken <citing-file> <broken-ref>
  printf '[BROKEN] %s -> %s\n' "$1" "$2"
  BROKEN=$((BROKEN + 1))
}

# Resolve a referenced path against ROOT, allowing a .sh/.ps1 twin.
resolve_with_twin() { # resolve_with_twin <file> <base> <ext>
  local file="$1" base="$2" ext="$3" twin
  if [ -f "$ROOT/$file" ]; then return 0; fi
  case "$ext" in
    sh)  twin="${base}.ps1" ;;
    ps1) twin="${base}.sh" ;;
    *)   return 1 ;;
  esac
  [ -f "$ROOT/$twin" ]
}

# ── 1. Agent references ──────────────────────────────────────────────────────
echo "Checking agent references (commands/, agents/)..."
while IFS= read -r src; do
  relsrc="${src#"$ROOT"/}"
  # 1a. YAML frontmatter `agent: <name>`
  while IFS= read -r name; do
    [ -n "$name" ] && [ ! -f "$ROOT/agents/$name.md" ] && broken "$relsrc" "$name"
  done < <(grep -oP '^agent:\s+\K[a-z0-9_-]+' "$src" 2>/dev/null || true)
  # 1b. backtick-quoted spec-* prose tokens
  while IFS= read -r name; do
    [ -n "$name" ] && [ ! -f "$ROOT/agents/$name.md" ] && broken "$relsrc" "$name"
  done < <(grep -oP '`\Kspec-[a-z][a-z0-9-]*' "$src" 2>/dev/null || true)
  # 1b'. backtick-quoted name immediately followed by `subagent` (e.g.
  #      "delegate to the `ghost-coder` subagent" — non-spec-prefixed agents)
  while IFS= read -r name; do
    [ -n "$name" ] && [ ! -f "$ROOT/agents/$name.md" ] && broken "$relsrc" "$name"
  done < <(grep -oP '`\K[a-z][a-z0-9-]*(?=`\s+subagent)' "$src" 2>/dev/null || true)
  # 1c. literal agent_type='...' / agent_type="..."
  while IFS= read -r name; do
    [ -n "$name" ] && [ ! -f "$ROOT/agents/$name.md" ] && broken "$relsrc" "$name"
  done < <(grep -oP "agent_type=['\"]\K[a-z0-9_-]+" "$src" 2>/dev/null || true)
done < <(find "$ROOT/commands" "$ROOT/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null || true)

# ── 2. Skill references ──────────────────────────────────────────────────────
echo "Checking skill references (agents/)..."
while IFS= read -r src; do
  relsrc="${src#"$ROOT"/}"
  # 2a. backtick-quoted name on a line mentioning `skill`
  while IFS= read -r name; do
    [ -n "$name" ] && [ "$name" != "skill" ] && [ "$name" != "skills" ] \
      && [ ! -f "$ROOT/skills/$name/SKILL.md" ] && broken "$relsrc" "$name"
  done < <(grep -P 'skill' "$src" 2>/dev/null | grep -oP '`[a-z][a-z0-9-]*`' | tr -d '`' | sort -u || true)
  # 2b. `name: <name>` assignment form (e.g. `name: design-taste-frontend`)
  while IFS= read -r name; do
    [ -n "$name" ] && [ ! -f "$ROOT/skills/$name/SKILL.md" ] && broken "$relsrc" "$name"
  done < <(grep -oP 'name:\s+\K[a-z][a-z0-9-]*' "$src" 2>/dev/null || true)
done < <(find "$ROOT/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null || true)

# ── 3. scripts/ paths ────────────────────────────────────────────────────────
echo "Checking scripts/ references (agents/, commands/, AGENTS.md)..."
while IFS= read -r src; do
  relsrc="${src#"$ROOT"/}"
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    base="${ref%.*}"
    ext="${ref##*.}"
    resolve_with_twin "$ref" "$base" "$ext" || broken "$relsrc" "$ref"
  done < <(grep -oP '(?<!standards/)scripts/[A-Za-z0-9._-]+\.(sh|ps1)' "$src" 2>/dev/null | sort -u || true)
done < <( { find "$ROOT/agents" "$ROOT/commands" -maxdepth 1 -name '*.md' -type f 2>/dev/null; [ -f "$ROOT/AGENTS.md" ] && echo "$ROOT/AGENTS.md"; } | sort -u | sed '/^$/d')

# ── 4. docs/ and language-specific/ refs in agents/ ──────────────────────────
echo "Checking docs/ and language-specific/ references (agents/)..."
while IFS= read -r src; do
  relsrc="${src#"$ROOT"/}"
  # 4a. docs/[A-Z_]+.md (Makefile validate-refs pattern)
  while IFS= read -r ref; do
    [ -n "$ref" ] && [ ! -f "$ROOT/$ref" ] && broken "$relsrc" "$ref"
  done < <(grep -oP 'docs/[A-Z_]+\.md' "$src" 2>/dev/null | sort -u || true)
  # 4b. language-specific/<lang>/SKILL.md ([a-z]+ only — <lang> never matches)
  while IFS= read -r ref; do
    [ -n "$ref" ] && [ ! -f "$ROOT/$ref" ] && broken "$relsrc" "$ref"
  done < <(grep -oP 'language-specific/[a-z]+/SKILL\.md' "$src" 2>/dev/null | sort -u || true)
done < <(find "$ROOT/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null || true)

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$BROKEN" -eq 0 ]; then
  echo "All orchestration references valid."
  exit 0
else
  echo "$BROKEN broken reference(s)!"
  exit 1
fi