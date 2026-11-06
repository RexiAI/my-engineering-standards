#!/bin/bash
# test-run-reuse.sh — Fingerprint the worktree so a recorded test run can be
# reused when nothing changed since (spec 041).
#
# The pipeline runs the full suite several times per /build. The Verifier's run
# is the gate and always happens; the Mutation Runner's final run is only useful
# when its mutation-killing tests changed the tree. This helper makes that
# decision mechanical: the Verifier records a hash, and the Mutation Runner asks
# whether the hash still matches.
#
# Hash definition (sha256, lowercase hex, 64 chars, one line) over the
# newline-joined, in this order:
#   1. `git rev-parse HEAD`, or the literal `NO-HEAD` when the repo has no commit;
#   2. the `git status --porcelain=v1 -z -uall` records (staged, unstaged, and
#      untracked, including untracked files inside new directories), one record
#      per line, AFTER dropping excluded evidence paths (see below);
#   3. for each remaining path, `git hash-object -- <path>`, or the literal
#      `DELETED` for a path that no longer exists.
#
# Excluded evidence paths (never hashed): any `25-verification.md` and any
# `runs.jsonl`. The Verifier records the hash INSIDE 25-verification.md and the
# pipeline appends gate telemetry to runs.jsonl; hashing those files would change
# the hash the moment the record is written, so `REUSE` could never be reached
# (the record would invalidate itself). The exclusion is path-based so
# `--print-hash` and `--check` always agree. A real code/test change still
# changes the hash: only the evidence files are ignored.
#
# Why not `git diff` alone: it misses untracked files, and the Mutation Runner's
# new tests are exactly untracked files. Why include HEAD: a commit with an
# identical worktree still changes what "the tree" means. Why the fail-safe
# direction matters: reuse is granted only on an exact match, so a mismatch can
# only ever cost a redundant run — never skip one.
#
# Usage:
#   scripts/test-run-reuse.sh --print-hash
#   scripts/test-run-reuse.sh --check <path/to/25-verification.md>
#   scripts/test-run-reuse.sh -h|--help
#
# --check reads the `## Evidence: full test suite` block (heading to the next
# `## Evidence:` heading or EOF) and prints exactly one line:
#   RERUN no-evidence-block   block absent                       (exit 1)
#   RERUN exit-nonzero        `exit:` absent or not 0            (exit 1)
#   RERUN hash-missing        no `Test-run hash:` line           (exit 1)
#   RERUN hash-mismatch       recorded hash ≠ current hash       (exit 1)
#   REUSE <hash>              exact match                        (exit 0)
# It never writes and never runs a test. It does NOT judge the overall verdict:
# the Mutation Runner's precondition (Verifier PASS before it runs) stays
# authoritative, which keeps this decision mechanical and the gate unchanged.
#
# Exit codes:
#   0 — hash printed, or REUSE
#   1 — a RERUN verdict (--check only)
#   2 — usage error, unreadable verification file, or not a git work tree
#       (no hash is printed in that case)
#
# Standards reference:
#   docs/spec-pipeline/verifier.md §Report format
#   docs/spec-pipeline/mutation-runner.md §Full suite, one final time
set -euo pipefail

usage() {
  cat <<'EOF' >&2
usage: scripts/test-run-reuse.sh --print-hash
       scripts/test-run-reuse.sh --check <path/to/25-verification.md>

  --print-hash  print the worktree fingerprint (sha256, one line)
  --check       decide whether the recorded full-test-suite run is reusable
  -h, --help    print this block
EOF
}

# require_repo — no hash and no decision without a git work tree.
require_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "test-run-reuse: not a git work tree" >&2
    exit 2
  fi
}

# record_path <entry> — the path a `git status -z` record names. A record is
# `XY <path>`; the trailing paths of rename/copy records carry no status prefix.
record_path() {
  local entry="$1" re='^[ MADRCU?!]{2}$'
  if [ "${entry:2:1}" = " " ] && [[ "${entry:0:2}" =~ $re ]]; then
    printf '%s\n' "${entry:3}"
    return 0
  fi
  printf '%s\n' "$entry"
}

# status_paths <status-file> — one path per line from `git status -z` output.
status_paths() {
  local file="$1" entry path
  while IFS= read -r -d '' entry; do
    path="$(record_path "$entry")"
    [ -n "$path" ] && printf '%s\n' "$path"
  done < "$file"
}

# is_evidence_path <path> — 0 when the path is an evidence/telemetry file the
# pipeline writes AFTER the hash is recorded. Excluding them is what makes
# `REUSE` reachable: the record cannot invalidate itself.
is_evidence_path() {
  case "$1" in
    */25-verification.md|25-verification.md) return 0 ;;
    runs.jsonl|*/runs.jsonl) return 0 ;;
  esac
  return 1
}

# filter_status <status-file> — the NUL-separated status records minus the
# excluded evidence paths. Written back as NUL records so `status_paths` reads
# the same shape.
filter_status() {
  local entry path
  while IFS= read -r -d '' entry; do
    path="$(record_path "$entry")"
    if is_evidence_path "$path"; then continue; fi
    printf '%s\0' "$entry"
  done < "$1"
}

# compute_hash — the documented fingerprint, one 64-hex line on stdout.
compute_hash() {
  local root head status filtered
  root="$(git rev-parse --show-toplevel)"
  head="$(git -C "$root" rev-parse HEAD 2>/dev/null || printf 'NO-HEAD')"
  status="$(mktemp "${TMPDIR:-/tmp}/test-run-reuse.XXXXXX")"
  filtered="$(mktemp "${TMPDIR:-/tmp}/test-run-reuse.XXXXXX")"
  git -C "$root" status --porcelain=v1 -z -uall > "$status"
  filter_status "$status" > "$filtered"
  {
    printf '%s\n' "$head"
    tr '\0' '\n' < "$filtered"
    printf '\n'
    status_paths "$filtered" | while IFS= read -r path; do
      if [ -e "$root/$path" ]; then
        git -C "$root" hash-object -- "$path"
      else
        printf 'DELETED\n'
      fi
    done
  } | sha256sum | awk '{ print $1 }'
  rm -f "$status" "$filtered"
}

# evidence_block <file> — the `## Evidence: full test suite` body, or nothing.
evidence_block() {
  awk '
    /^## Evidence:/ {
      if (inblock) exit
      name = $0
      sub(/^## Evidence:[[:space:]]*/, "", name)
      sub(/[[:space:]]+$/, "", name)
      if (tolower(name) == "full test suite") inblock = 1
      next
    }
    inblock { print }
  ' "$1"
}

# recorded_exit <block> — the block's `exit:` value, digits only.
recorded_exit() {
  awk -F: '/^exit:/ { gsub(/[^0-9]/, "", $2); print $2; exit }' <<< "$1"
}

# recorded_hash <block> — the block's `Test-run hash:` value.
recorded_hash() {
  awk '
    /^Test-run hash:/ {
      sub(/^Test-run hash:[[:space:]]*/, "")
      sub(/[[:space:]].*$/, "")
      print
      exit
    }
  ' <<< "$1"
}

# rerun <reason> — print the RERUN verdict and exit 1.
rerun() {
  printf 'RERUN %s\n' "$1"
  exit 1
}

# usage_error — a usage problem is exit 2, with the usage block on stderr.
usage_error() {
  usage
  exit 2
}

# require_verification_file <file> — exit 2 when it cannot be read.
require_verification_file() {
  if [ -f "$1" ] && [ -r "$1" ]; then return 0; fi
  echo "test-run-reuse: cannot read verification file: $1" >&2
  exit 2
}

# check_reuse <verification-file> — print one verdict line and exit 0/1.
check_reuse() {
  local file="$1" block recorded current
  require_verification_file "$file"
  block="$(evidence_block "$file")"
  [ -n "$block" ] || rerun no-evidence-block
  [ "$(recorded_exit "$block")" = "0" ] || rerun exit-nonzero
  recorded="$(recorded_hash "$block")"
  [[ "$recorded" =~ ^[0-9a-f]{64}$ ]] || rerun hash-missing
  current="$(compute_hash)"
  [ "$recorded" = "$current" ] || rerun hash-mismatch
  printf 'REUSE %s\n' "$current"
  exit 0
}

# hash_invocation — `--print-hash` takes no further arguments.
hash_invocation() {
  [ "$#" -eq 1 ] || usage_error
  require_repo
  compute_hash
}

# check_invocation <verification-file> — `--check` takes exactly one path.
check_invocation() {
  [ "$#" -eq 2 ] || usage_error
  require_repo
  check_reuse "$2"
}

main() {
  case "${1:-}" in
    -h|--help) usage; exit 0 ;;
    --print-hash) hash_invocation "$@" ;;
    --check) check_invocation "$@" ;;
    *) usage_error ;;
  esac
}

main "$@"
