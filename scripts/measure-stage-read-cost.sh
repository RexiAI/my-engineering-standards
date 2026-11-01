#!/bin/bash
# measure-stage-read-cost.sh — Per-stage read cost of the split spec-pipeline docs.
#
# Spec 037 split docs/SPEC_PIPELINE.md into an index plus docs/spec-pipeline/*.md
# so each stage reads only its own slice. This script proves the split actually
# reduced what a stage must read.
#
# Cost model (specs/037-split-spec-pipeline-doc/10-tasks.md Task 5, Q1): a
# stage's cost is the index plus its own stage file, plus every shared file its
# stage file marks "Must read". Bytes are `wc -c` — the accepted token proxy. A
# shared file counts only when the stage file's own "Must read" line names it;
# nothing is added implicitly.
#
# The baseline is the byte size of the *unsplit* docs/SPEC_PIPELINE.md at the
# 036-merged base commit (50836 bytes, 893 lines). It is a constant on purpose:
# measuring against the current index would always compare the split to itself.
#
# Usage:
#   scripts/measure-stage-read-cost.sh [ROOT]
#   ROOT defaults to the repo root (parent of scripts/). Pass a scratch tree to
#   measure a fixture (used by the spec 037 acceptance tests).
#
# Exit codes:
#   0 — every stage's ratio is <= 0.50
#   1 — at least one stage is over budget (each prints `OVER <stage> ...`)
#   2 — the tree cannot be measured (index, a stage file, or a stage's
#       "Must read" file is missing)
#
# Standards reference:
#   docs/SPEC_PIPELINE.md §Stage files
#   docs/spec-pipeline/verifier.md
set -euo pipefail

if [ "$#" -gt 1 ]; then
  echo "usage: $0 [ROOT]" >&2
  exit 2
fi

# Byte size of docs/SPEC_PIPELINE.md at the 036-merged base commit.
BASELINE_BYTES=50836
LIMIT_PERCENT=50

STAGES=(specifier ux coder refactorer verifier mutation-runner pr-opener deployer)

ROOT=""
over=0

die() { echo "measure-stage-read-cost: $*" >&2; exit 2; }

# set_root <arg> — ROOT is the absolute tree to measure; empty means this repo.
set_root() {
  ROOT="$1"
  if [ -z "$ROOT" ]; then
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    ROOT="$(dirname "$script_dir")"
  fi
  [ -d "$ROOT" ] || die "ROOT is not a directory: $ROOT"
  ROOT="$(cd "$ROOT" && pwd)"
}

# require_tree — die unless the index and the stage-file directory exist.
require_tree() {
  [ -f "$INDEX" ] || die "missing $INDEX"
  [ -d "$DIR" ] || die "missing $DIR"
}

size_of() { # size_of <file> — byte count, or die
  [ -f "$1" ] || die "missing $1"
  wc -c < "$1" | tr -d ' '
}

# must_read_files <stage> — the shared docs/spec-pipeline/*.md paths named in the
# stage file's "Must read:" block (which ends at the first blank line), deduped.
must_read_files() { # must_read_files <stage-file>
  awk '
    /^Must read:/ { f = 1; print; next }
    f && /^[[:space:]]*$/ { exit }
    f { print }
  ' "$1" | grep -oE 'docs/spec-pipeline/[a-z-]+\.md' | sort -u || true
}

# stage_bytes <stage-file> — index + the stage file + every shared file its
# "Must read:" block names.
stage_bytes() {
  local stage_file="$1" shared bytes
  bytes=$((index_bytes + $(size_of "$stage_file")))
  while IFS= read -r shared; do
    [ -n "$shared" ] || continue
    bytes=$((bytes + $(size_of "$ROOT/$shared")))
  done < <(must_read_files "$stage_file")
  printf '%s\n' "$bytes"
}

# ratio_of <bytes> — bytes / BASELINE_BYTES to three decimals, without bc/python.
ratio_of() {
  local milli=$(( $1 * 1000 / BASELINE_BYTES ))
  printf '%d.%03d' $((milli / 1000)) $((milli % 1000))
}

# report_stage <stage> <bytes> — one result row; returns 1 when over budget.
report_stage() {
  local stage="$1" bytes="$2" ratio
  ratio="$(ratio_of "$bytes")"
  if [ $((bytes * 100)) -le $((BASELINE_BYTES * LIMIT_PERCENT)) ]; then
    printf '%-16s %8s %7s  ok\n' "$stage" "$bytes" "$ratio"
    return 0
  fi
  printf '%-16s %8s %7s  OVER\n' "$stage" "$bytes" "$ratio"
  echo "OVER $stage: $bytes bytes is ${ratio} of the ${BASELINE_BYTES}-byte baseline (limit 0.500)"
  return 1
}

# measure_all — one row per stage, counting the over-budget ones in `over`.
measure_all() {
  local stage bytes
  for stage in "${STAGES[@]}"; do
    bytes="$(stage_bytes "$DIR/$stage.md")" || return 2
    report_stage "$stage" "$bytes" || over=$((over + 1))
  done
}

set_root "${1:-}"
INDEX="$ROOT/docs/SPEC_PIPELINE.md"
DIR="$ROOT/docs/spec-pipeline"
require_tree

printf 'Stage read cost — baseline %s bytes, budget %s%% (= %s bytes)\n' \
  "$BASELINE_BYTES" "$LIMIT_PERCENT" "$((BASELINE_BYTES * LIMIT_PERCENT / 100))"
printf '%-16s %8s %7s  %s\n' 'stage' 'bytes' 'ratio' 'verdict'

index_bytes="$(size_of "$INDEX")"
measure_all

echo ""
if [ "$over" -eq 0 ]; then
  echo "Every stage reads at most ${LIMIT_PERCENT}% of the unsplit document."
  exit 0
fi
echo "$over stage(s) over the ${LIMIT_PERCENT}% read-cost budget."
exit 1
