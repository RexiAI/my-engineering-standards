#!/bin/bash
# classify-spec-size.sh — Deterministic size/surface classifier for lite mode.
#
# Spec 039 Task 2 (docs/SPEC_PIPELINE.md §Lite mode). A spec is `lite` only when
# both mechanical conditions hold:
#
#   1. Surface — every file path named in the spec's `10-tasks.md` is under
#      `docs/`, under `specs/`, is a `*.md` file anywhere, or is exactly one
#      file under `scripts/`. Any other named path (a `commands/` file, a CI
#      template, two scripts) makes the spec `full`.
#   2. Scenarios — `20-acceptance/*.md` holds at most 5 `## AC-NNN-NN` headings.
#
# Everything the classifier reads lives inside the spec folder (`10-tasks.md`,
# `20-acceptance/`): no network, no model call, no clock, no repo scan. The same
# input files always produce byte-identical output.
#
# A missing or unparsable rule input is never guessed at — it resolves to
# `full`.
#
# Usage:
#   scripts/classify-spec-size.sh specs/NNN-slug
#
# Output (stdout):
#   line 1  — `lite` or `full`
#   line 2  — `Reason: <the deciding inputs and counts>`
#
# Exit codes:
#   0 — a classification was produced (`lite` or `full`)
#   2 — usage error, or the spec folder does not exist (stderr names the path)
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Lite mode
#   docs/spec-pipeline/lite-mode.md
set -euo pipefail

MAX_SCENARIOS=5

# require_spec_dir <dir> — the argument contract: a missing argument is a usage
# error, a missing folder names the path it looked for, both exit 2.
require_spec_dir() {
  if [ -z "$1" ]; then
    echo "usage: scripts/classify-spec-size.sh specs/NNN-slug" >&2
    exit 2
  fi
  if [ ! -d "$1" ]; then
    echo "classify-spec-size: spec folder not found: $1" >&2
    exit 2
  fi
}

# emit <mode> <reason> — the classifier's whole output contract.
emit() {
  printf '%s\n' "$1"
  printf 'Reason: %s\n' "$2"
  exit 0
}

# is_path_candidate <token> — a backticked token that looks like a file path.
# Slashed tokens are paths (directories included); a bare token needs a
# recognised file extension, so prose tokens like `lite` and fragments like
# `.sh` never count as a named path. A leading slash with a single segment
# (`/build`, `/spec`) is a slash command, not a path; `/docs/x.md` is a path.
is_path_candidate() {
  case "$1" in
    /*/*|/*.*) return 0 ;;
    /*) return 1 ;;
    */*) return 0 ;;
    .*) return 1 ;;
    *.md|*.sh|*.ps1|*.bats|*.yml|*.yaml|*.json|*.txt|*.toml) return 0 ;;
  esac
  return 1
}

# is_nameable_token <token> — a token that could name a path at all: non-empty,
# no whitespace, and nothing outside the path alphabet. Prose and prose
# fragments (`lite`, `--flag`, `a,`) fail here before the path test runs.
is_nameable_token() {
  case "$1" in
    ''|*[[:space:]]*|*[!A-Za-z0-9._/*-]*) return 1 ;;
  esac
  return 0
}

# named_paths <tasks-file> — every file path named in the tasks file, one per
# line, sorted and deduped so the output is stable.
named_paths() {
  local token
  # shellcheck disable=SC2016  # the pattern matches literal backticks, not substitution
  grep -oE '`[^`]+`' "$1" 2>/dev/null | tr -d '`' | while IFS= read -r token; do
    token="${token#./}"
    is_nameable_token "$token" || continue
    is_path_candidate "$token" || continue
    printf '%s\n' "$token"
  done | sort -u
}

# count_scenarios <acceptance-dir> — `## AC-NNN-NN` headings across every file.
count_scenarios() {
  local file total=0 n
  for file in "$1"/*.md; do
    [ -f "$file" ] || continue
    n="$(grep -cE '^##[[:space:]]+AC-[0-9]{3}-[0-9]' "$file" || true)"
    total=$((total + n))
  done
  printf '%s' "$total"
}

# count_lines <text> — non-empty lines in <text>.
count_lines() {
  grep -c . <<< "$1" || true
}

# path_kind <spec_dir> <path> — how one named path bears on the surface rule:
#   surface  under docs/, under specs/, or a *.md file anywhere
#   script   under scripts/ (lite allows at most one such file)
#   own      resolves inside the spec folder, which lives under specs/
#   other    anything else — forces full
path_kind() {
  case "$2" in
    docs/*|specs/*|*.md) printf 'surface' ;;
    scripts/*) printf 'script' ;;
    *) if [ -e "$1/$2" ]; then printf 'own'; else printf 'other'; fi ;;
  esac
}

# path_kinds <spec_dir> <tasks-file> — `<kind> <path>` for every named path.
path_kinds() {
  local path
  while IFS= read -r path; do
    [ -z "$path" ] || printf '%s %s\n' "$(path_kind "$1" "$path")" "$path"
  done <<< "$(named_paths "$2")"
}

# surface_reason <kinds> — the failing surface rule's reason, or nothing when
# every named path sits on the allowed surface.
surface_reason() {
  local path_count script_count other_path
  path_count="$(count_lines "$1")"
  script_count="$(grep -c '^script ' <<< "$1" || true)"
  other_path="$(sed -n 's/^other //p' <<< "$1" | head -1)"
  if [ "$path_count" -eq 0 ]; then
    printf 'no file paths named in 10-tasks.md — surface unparsable\n'
    return 0
  fi
  if [ -n "$other_path" ]; then
    printf "%s named path(s) include '%s', outside docs/, specs/, *.md and scripts/\n" \
      "$path_count" "$other_path"
    return 0
  fi
  if [ "$script_count" -gt 1 ]; then
    printf '%s files named under scripts/ — lite allows at most one\n' "$script_count"
  fi
}

# scenario_reason <acceptance-dir> — the failing scenario rule's reason, or
# nothing when the scenario count is inside the lite range.
scenario_reason() {
  local n
  n="$(count_scenarios "$1")"
  if [ "$n" -eq 0 ]; then
    printf 'no acceptance scenarios found in %s\n' "$1"
    return 0
  fi
  if [ "$n" -gt "$MAX_SCENARIOS" ]; then
    printf '%s acceptance scenarios exceed the lite maximum of %s\n' "$n" "$MAX_SCENARIOS"
  fi
}

spec_dir="${1:-}"
require_spec_dir "$spec_dir"

tasks_file="$spec_dir/10-tasks.md"
acceptance_dir="$spec_dir/20-acceptance"

[ -f "$tasks_file" ] || emit full "missing 10-tasks.md inside $spec_dir"
[ -d "$acceptance_dir" ] || emit full "missing 20-acceptance/ inside $spec_dir"

kinds="$(path_kinds "$spec_dir" "$tasks_file")"
reason="$(surface_reason "$kinds")"
[ -n "$reason" ] || reason="$(scenario_reason "$acceptance_dir")"
if [ -n "$reason" ]; then
  emit full "$reason"
fi

emit lite "$(count_lines "$kinds") named path(s) within docs/, specs/, *.md or one scripts/ file; $(count_scenarios "$acceptance_dir") acceptance scenario(s) <= $MAX_SCENARIOS"
