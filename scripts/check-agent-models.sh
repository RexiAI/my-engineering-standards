#!/usr/bin/env bash
# Gate (ADR 0004): agent definitions must ship without a `model:` frontmatter key.
#
# Model resolution belongs to the CONSUMER: `opencode.json`'s per-agent
# `{env:SPEC_*_MODEL}` roster, or harness inheritance when nothing is configured.
# A `model:` pin in an agent `.md` silently wins over the consumer's config
# (`.opencode/agents/` loads after `opencode.json`), hard-coupling every run to
# one vendor — see ADR 0003 for the shipped-agents side and ADR 0004 for this
# gate, which also covers consumer-side catalogs copied from ECC-style installs
# (2026-10-15 incident: 27 pinned agents, `github-copilot/*` and `ollama/*`,
# broke every run on a provider that does not serve those ids).
#
# Usage:
#   check-agent-models.sh [root]     scan <root>/agents and <root>/.opencode/agents
#   check-agent-models.sh --self-test  hermetic fixture proof (exit 0 iff gate bites)
#
# Exit: 0 = no pins found; 1 = at least one `model:` key in agent frontmatter;
#       2 = usage/tooling error.
set -euo pipefail

say() { printf '%s\n' "$*"; }

# Extract frontmatter body: file must start with '---'; stop at the next '---'.
frontmatter() {
  awk 'NR == 1 { if ($0 != "---") exit; next } $0 == "---" { exit } { print }' "$1"
}

scan_root() {
  root="$1"
  violations=0
  scanned=0
  # Dedupe by realpath: child repos symlink .opencode/agents -> ../agents or a
  # submodule; scanning both would report one pin twice.
  seen_dirs=""
  seen_files=""
  for dir in "$root/agents" "$root/.opencode/agents"; do
    [ -d "$dir" ] || continue
    real="$(realpath "$dir" 2>/dev/null || echo "$dir")"
    case " $seen_dirs " in *" $real "*) continue ;; esac
    seen_dirs="$seen_dirs $real"
    for file in "$real"/*.md; do
      [ -e "$file" ] || continue
      # Dedupe by file realpath too: a symlinked twin inside the other
      # directory is the same agent definition, not a second one.
      freal="$(realpath "$file" 2>/dev/null || echo "$file")"
      case " $seen_files " in *" $freal "*) continue ;; esac
      seen_files="$seen_files $freal"
      scanned=$((scanned + 1))
      pin="$(frontmatter "$file" | grep -E '^model:[[:space:]]*' || true)"
      if [ -n "$pin" ]; then
        say "FAIL: ${file#$root/} pins ${pin} (ADR 0004: agent definitions carry no model key)"
        violations=$((violations + 1))
      else
        say "PASS: ${file#$root/} (no model key)"
      fi
    done
  done
  if [ "$scanned" -eq 0 ]; then
    say "NOTE: no agent definitions under $root/agents or $root/.opencode/agents — nothing to check."
  fi
  return "$violations"
}

self_test() {
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' RETURN
  mkdir -p "$work/pinned/agents" "$work/clean/agents" "$work/clean/.opencode/agents"
  cat > "$work/pinned/agents/reviewer.md" <<'MD'
---
description: pinned fixture
mode: subagent
model: example-vendor/example-model-1
---
Body.
MD
  cat > "$work/clean/agents/reviewer.md" <<'MD'
---
description: clean fixture
mode: subagent
---
Body.
MD
  # symlinked twin must not double-report
  ln -s ../../agents/reviewer.md "$work/clean/.opencode/agents/reviewer.md" 2>/dev/null || true

  if scan_root "$work/pinned" > "$work/pinned.log" 2>&1; then
    say "SELF-TEST FAIL: pinned fixture was not rejected"
    return 1
  fi
  grep -q "FAIL: agents/reviewer.md pins model: example-vendor/example-model-1" "$work/pinned.log" || {
    say "SELF-TEST FAIL: violation line missing or misformatted"
    return 1
  }
  if ! scan_root "$work/clean" > "$work/clean.log" 2>&1; then
    say "SELF-TEST FAIL: clean fixture was rejected"
    return 1
  fi
  # clean fixture reports exactly one PASS (symlink deduped)
  [ "$(grep -c '^PASS:' "$work/clean.log")" -eq 1 ] || {
    say "SELF-TEST FAIL: symlinked agent double-counted"
    return 1
  }
  say "SELF-TEST PASS: gate rejects pins, accepts clean agents, dedupes symlinks"
  return 0
}

case "${1:-.}" in
  --self-test) self_test ;;
  -h | --help) grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//' ;;
  *)
    # bare call scans the repo root — ${1:-.} mirrors the case dispatch above
    # (a bare ${1%/} dies under set -u with "unbound variable")
    root="${1:-.}"
    root="${root%/}"
    [ -d "$root" ] || { say "ERROR: no such root: $root"; exit 2; }
    if scan_root "$root"; then
      say "Agent model-agnosticism check: no model pins found."
      exit 0
    else
      say "Agent model-agnosticism check: model pins found — remove them (ADR 0004)."
      exit 1
    fi
    ;;
esac
