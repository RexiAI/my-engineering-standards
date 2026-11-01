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
# Structure: each check pairs a *candidate stream* (a grep over a citing file)
# with one *report* function that reads candidate names on stdin and calls
# `broken` for the ones that do not resolve. A report function therefore never
# runs in a pipeline — it runs in this shell, because it increments BROKEN.
#
# Checks:
#   1. Agent references (AC-006-01) — every agent name cited in commands/*.md
#      and agents/*.md (YAML `agent:` frontmatter, backtick-quoted `spec-*`
#      tokens, backtick-quoted name before the word `subagent`, and literal
#      `agent_type='...'` / `agent_type="..."` assignments) resolves to
#      `agents/<name>.md`.
#   2. Skill references (AC-006-02) — every skill cited in agents/*.md
#      (backtick-quoted name on a line mentioning skill, or a `name: <name>`
#      assignment) resolves to `skills/<name>/SKILL.md`.
#   3. scripts/ paths (AC-006-03) — every `scripts/<file>.sh`/`.ps1` path cited
#      in agents/, commands/, and AGENTS.md resolves to an existing file (a
#      `.sh`/`.ps1` twin counts as resolving). `.standards/scripts/…` child-repo
#      paths are NOT repo scripts/ references and are not matched.
#   4. docs/ and language-specific/ refs (AC-006-04, extended by spec 037) —
#      every `docs/[A-Z_]+.md`, `docs/spec-pipeline/<stage>.md`, and
#      `language-specific/[a-z]+/SKILL.md` cross-reference in agents/,
#      commands/, and AGENTS.md resolves. The `<lang>` template placeholder is
#      never matched.
#   6. §heading references (AC-004-03, spec 037) — every
#      `docs/SPEC_PIPELINE.md §<Section>` or `docs/spec-pipeline/<file>.md
#      §<Section>` reference in agents/, commands/, and AGENTS.md names a real
#      heading of that file.
#   Tasks 5-6 (AC-006-05, AC-006-06) remove the dangling spec-architect token
#   and wire the check into self-ci; enforced by check-orchestration.sh passing
#   on a clean tree with the self-ci step present.
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
#       `[BROKEN] <citing-file> -> <broken-ref>` (check 6 prints
#       `[BROKEN] <citing-file>:<line> -> <doc> §<section> (no such heading)`).
#
# Standards reference:
#   docs/SPEC_PIPELINE.md (spec 006)
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

# relative_to_root — absolute paths on stdin, printed relative to ROOT, so a
# [BROKEN] line names the citing file the way the repo does.
relative_to_root() {
  local src
  while IFS= read -r src; do
    [ -n "$src" ] || continue
    printf '%s\n' "${src#"$ROOT"/}"
  done
}

# citing_files — the files that cite the orchestration layer: agents/*.md,
# commands/*.md, and AGENTS.md, relative to ROOT, deduped.
citing_files() {
  { find "$ROOT/agents" "$ROOT/commands" -maxdepth 1 -name '*.md' -type f 2>/dev/null
    [ -f "$ROOT/AGENTS.md" ] && echo "$ROOT/AGENTS.md"
  } | sort -u | relative_to_root
}

# ── Candidate readers (names on stdin, one per line) ─────────────────────────

# dangling_agent_names <citing-file> — every name on stdin must have
# agents/<name>.md.
dangling_agent_names() {
  local relsrc="$1" name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    [ -f "$ROOT/agents/$name.md" ] || broken "$relsrc" "$name"
  done
}

# dangling_skill_names <citing-file> [word...] — every name on stdin must have
# skills/<name>/SKILL.md. Each [word] is an English word the source filter can
# yield, not a skill citation, so it is skipped.
dangling_skill_names() {
  local relsrc="$1" name skipped
  shift
  skipped=" $* "
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    case "$skipped" in *" $name "*) continue ;; esac
    [ -f "$ROOT/skills/$name/SKILL.md" ] || broken "$relsrc" "$name"
  done
}

# dangling_paths <citing-file> — every repo-relative path on stdin must exist.
dangling_paths() {
  local relsrc="$1" ref
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    [ -f "$ROOT/$ref" ] || broken "$relsrc" "$ref"
  done
}

# dangling_scripts <citing-file> — every scripts/ path on stdin must resolve,
# allowing a .sh/.ps1 twin.
dangling_scripts() {
  local relsrc="$1" ref base ext
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    base="${ref%.*}"
    ext="${ref##*.}"
    resolve_with_twin "$ref" "$base" "$ext" || broken "$relsrc" "$ref"
  done
}

# ── 1. Agent references ──────────────────────────────────────────────────────
# check_agent_refs — every agent-name token in commands/ and agents/ resolves.
check_agent_refs() {
  local relsrc pattern
  echo "Checking agent references (commands/, agents/)..."
  while IFS= read -r relsrc; do
    for pattern in '^agent:\s+\K[a-z0-9_-]+' \
                   '`\Kspec-[a-z][a-z0-9-]*' \
                   '`\K[a-z][a-z0-9-]*(?=`\s+subagent)' \
                   "agent_type=['\"]\K[a-z0-9_-]+"; do
      dangling_agent_names "$relsrc" \
        < <(grep -oP "$pattern" "$ROOT/$relsrc" 2>/dev/null || true)
    done
  done < <(find "$ROOT/commands" "$ROOT/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null | relative_to_root)
}

# ── 2. Skill references ──────────────────────────────────────────────────────
# check_skill_refs — every skill cited in agents/ resolves to its SKILL.md.
check_skill_refs() {
  local relsrc
  echo "Checking skill references (agents/)..."
  while IFS= read -r relsrc; do
    # 2a. backtick-quoted name on a line mentioning `skill`
    dangling_skill_names "$relsrc" skill skills \
      < <(grep -P 'skill' "$ROOT/$relsrc" 2>/dev/null \
          | grep -oP '`[a-z][a-z0-9-]*`' | tr -d '`' | sort -u || true)
    # 2b. `name: <name>` assignment form (e.g. `name: design-taste-frontend`)
    dangling_skill_names "$relsrc" \
      < <(grep -oP 'name:\s+\K[a-z][a-z0-9-]*' "$ROOT/$relsrc" 2>/dev/null || true)
  done < <(find "$ROOT/agents" -maxdepth 1 -name '*.md' -type f 2>/dev/null | relative_to_root)
}

# ── 3. scripts/ paths ────────────────────────────────────────────────────────
# check_script_refs — every `scripts/<file>.sh|.ps1` citation resolves.
check_script_refs() {
  local relsrc
  echo "Checking scripts/ references (agents/, commands/, AGENTS.md)..."
  while IFS= read -r relsrc; do
    dangling_scripts "$relsrc" \
      < <(grep -oP '(?<!standards/)scripts/[A-Za-z0-9._-]+\.(sh|ps1)' "$ROOT/$relsrc" 2>/dev/null | sort -u || true)
  done < <(citing_files)
}

# ── 4. docs/ and language-specific/ refs in agents/, commands/, AGENTS.md ────
# check_doc_refs — every doc path cited by the orchestration layer exists.
check_doc_refs() {
  local relsrc pattern
  echo "Checking docs/ and language-specific/ references (agents/, commands/, AGENTS.md)..."
  while IFS= read -r relsrc; do
    # 4a. docs/[A-Z_]+.md — the Makefile validate-refs pattern
    # 4b. language-specific/<lang>/SKILL.md — `[a-z]+` only, so the <lang>
    #     template placeholder never matches
    # 4c. docs/spec-pipeline/<stage>.md — spec 037 split, lowercase path, so 4a
    #     never matched it
    for pattern in 'docs/[A-Z_]+\.md' \
                   'language-specific/[a-z]+/SKILL\.md' \
                   'docs/spec-pipeline/[a-z-]+\.md'; do
      dangling_paths "$relsrc" \
        < <(grep -oP "$pattern" "$ROOT/$relsrc" 2>/dev/null | sort -u || true)
    done
  done < <(citing_files)
}

# ── 5. Agent/doc single source (spec 036) ────────────────────────────────────
# Skipped when ROOT has no docs/SPEC_PIPELINE.md (isolated commands/+agents/
# fixtures used by older acceptance tests).
check_single_source() {
  local dup_out line dup_script
  [ -f "$ROOT/docs/SPEC_PIPELINE.md" ] || return 0
  [ -d "$ROOT/agents" ] || return 0
  echo "Checking agents/ for rules duplicated from docs/SPEC_PIPELINE.md..."
  dup_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/check-agent-doc-duplication.sh"
  if ! dup_out="$(bash "$dup_script" "$ROOT" 2>&1)"; then
    while IFS= read -r line; do
      [ -n "$line" ] && broken "${line%%: *}" "${line#*: }"
    done <<< "$dup_out"
  fi
}

# ── 6. §heading references into the pipeline docs (spec 037) ─────────────────
# Every `<doc> §<Section>` reference to docs/SPEC_PIPELINE.md or
# docs/spec-pipeline/<file>.md must name a real heading in that file. Moving a
# section keeps the path valid, so checks 4a-4c cannot see the reference go
# stale. Skipped for older isolated fixtures with no pipeline docs at all.

# headings_of <doc> — every heading text of the doc, longest first
headings_of() {
  grep -oP '^#{1,6} \K.*' "$ROOT/$1" 2>/dev/null \
    | awk '{ print length($0) "\t" $0 }' | sort -rn | cut -f2- || true
}

# anchor_resolves <doc> <text-after-§> — longest-prefix match against the
# doc's headings, requiring a word boundary after the match so `§Loop` does
# not resolve against a `## Loop (phase 2)` heading alone.
anchor_resolves() {
  local doc="$1" rest="$2" h
  [ -f "$ROOT/$doc" ] || return 1
  while IFS= read -r h; do
    [ -n "$h" ] || continue
    [ "${rest:0:${#h}}" = "$h" ] || continue
    [[ "${rest:${#h}:1}" =~ [A-Za-z0-9_-] ]] && continue
    return 0
  done < <(headings_of "$doc")
  return 1
}

# report_bad_anchor <citing-file> <grep -n hit> — one report for a §anchor that
# names no heading of its doc.
report_bad_anchor() {
  local relsrc="$1" lineno ref doc rest shown
  lineno="${2%%:*}"
  ref="${2#*:}"
  doc="${ref%% §*}"
  rest="${ref#* §}"
  anchor_resolves "$doc" "$rest" && return 0
  shown="$(printf '%s' "$rest" | sed -E 's/[`").,;:].*$//')"
  printf '[BROKEN] %s:%s -> %s §%s (no such heading)\n' \
    "$relsrc" "$lineno" "$doc" "$shown"
  BROKEN=$((BROKEN + 1))
}

# report_bad_anchors <citing-file> — every `<line>:<doc> §<section>` hit on
# stdin is checked.
report_bad_anchors() {
  local relsrc="$1" hit
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    report_bad_anchor "$relsrc" "$hit"
  done
}

# check_anchor_refs — every §anchor citation in the orchestration layer names a
# real heading of the doc it points into.
check_anchor_refs() {
  local relsrc
  [ -f "$ROOT/docs/SPEC_PIPELINE.md" ] || [ -d "$ROOT/docs/spec-pipeline" ] || return 0
  echo "Checking §heading references into the pipeline docs (agents/, commands/, AGENTS.md)..."
  while IFS= read -r relsrc; do
    report_bad_anchors "$relsrc" \
      < <(grep -noP 'docs/(?:SPEC_PIPELINE\.md|spec-pipeline/[a-z-]+\.md) §(?:(?!docs/).)*' "$ROOT/$relsrc" 2>/dev/null || true)
  done < <(citing_files)
}

check_agent_refs
check_skill_refs
check_script_refs
check_doc_refs
check_single_source
check_anchor_refs

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
if [ "$BROKEN" -eq 0 ]; then
  echo "All orchestration references valid."
  exit 0
else
  echo "$BROKEN broken reference(s)!"
  exit 1
fi
