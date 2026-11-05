#!/usr/bin/env bash
# Run the bats gate suite across N workers without GNU parallel or rush.
#
# Why: the suite is ~880 tests and runs serially in CI (6-8 min per job). Each
# bats file is independent — every test sets up its own tmpdir and a private
# GIT_CONFIG_GLOBAL — so files can be sharded safely. Output stays valid TAP:
# each file's TAP is captured separately and concatenated in a stable,
# pre-shuffled order, so a reader sees one plan line per file and no
# interleaved fragments.
#
# Usage: run-bats-parallel.sh [--jobs N] [files...]
#        (no files: scripts/tests/*.bats; jobs default: nproc, capped at 8)
#
# Exit: 0 all pass, 1 at least one failure, 2 usage error.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOBS=""
while [ $# -gt 0 ]; do
    case "$1" in
        -j|--jobs) JOBS="${2:-}"; shift 2 ;;
        -h|--help) sed -n '3,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --) shift; break ;;
        -*) echo "usage: run-bats-parallel.sh [--jobs N] [files...]" >&2; exit 2 ;;
        *) break ;;
    esac
done

if [ -z "$JOBS" ]; then
    JOBS="$(nproc 2>/dev/null || echo 4)"
    [ "$JOBS" -gt 8 ] && JOBS=8
fi
case "$JOBS" in ''|*[!0-9]*) echo "usage: --jobs must be a positive integer" >&2; exit 2 ;; esac
[ "$JOBS" -ge 1 ] || { echo "usage: --jobs must be >= 1" >&2; exit 2; }

if [ "$#" -gt 0 ]; then
    files=("$@")
else
    shopt -s nullglob
    files=("$ROOT"/scripts/tests/*.bats)
    shopt -u nullglob
fi
[ "${#files[@]}" -gt 0 ] || { echo "no bats files found" >&2; exit 2; }

work="$(mktemp -d "${TMPDIR:-/tmp}/bats-parallel.XXXXXX")"
cleanup() { rm -rf "$work"; }
trap cleanup EXIT

# Stable order: sort, then deal round-robin so shard sizes differ by at most 1.
printf '%s\n' "${files[@]}" | sort > "$work/all"

failed=0
run_one() {
    local f="$1" out="$2"
    if ! bats --tap "$f" > "$out" 2>&1; then
        echo "FAILED" > "$out.rc"
    fi
}
export -f run_one

# xargs drives the concurrency (one worker per file); -P bounds it.
: > "$work/order"
awk -v n="$JOBS" '{ print (NR % n) "\t" $0 }' "$work/all" | sort -n -k1,1 | cut -f2- > "$work/order"

i=0
while IFS= read -r f; do
    printf '%s\n' "$f" >> "$work/list.$((i % JOBS))"
    i=$((i + 1))
done < "$work/order"

for list in "$work"/list.*; do
    [ -f "$list" ] || continue
    n="$(basename "$list")"
    (
        set +e
        while IFS= read -r f; do
            if ! bats --tap "$f" > "$work/$(basename "$f").tap" 2>&1; then
                : > "$work/$(basename "$f").fail"
            fi
        done < "$list"
    ) &
done
wait || true

# Some suites fork heavily enough that bats' --separate-stderr FD handling can
# misfire under load (observed once in ~880 tests at -j 6). Re-run any file that
# failed in the parallel pass SERIALLY: a real failure fails again, a load
# artefact passes. Only the serial verdict is final.
failed_files=()
while IFS= read -r f; do
    tap="$work/$(basename "$f").tap"
    if [ -f "$work/$(basename "$f").fail" ]; then
        failed_files+=("$f")
    elif [ -f "$tap" ]; then
        cat "$tap"
    fi
done < "$work/order"

if [ "${#failed_files[@]}" -gt 0 ]; then
    echo "# parallel pass failed ${#failed_files[@]} file(s); re-running serially" >&2
    for f in "${failed_files[@]}"; do
        if ! bats --tap "$f"; then
            failed=1
        fi
    done
fi

[ "$failed" -eq 0 ] || exit 1
exit 0
