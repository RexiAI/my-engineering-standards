#!/bin/bash
# run-mutation.sh — Bounded, scoped mutation runs (ADR 0028).
#
# Mutation testing is a quality gate, not a background job. A whole-tree Stryker
# run is minutes of CPU that a spec stage does not need, and a retry loop with no
# stopping rule is unbounded. This wrapper makes the cost explicit:
#
#   * scope  — by default it mutates only the files changed since a base ref
#              (`stryker run --since <ref>`), so a spec run tests its own surface.
#   * cache  — `--incremental` keeps a cache file, so a re-run only tests mutants
#              whose source or tests changed.
#   * budget — a wall-clock timeout (default 900 s). On expiry the partial report
#              is kept and the exit code says "budget exceeded"; it never hangs.
#   * passes — the caller may target the survivor files with `--only`; two runs
#              (scope pass + survivor pass) are the whole budget for one spec.
#
# Whole-tree mutation is a release activity: `scripts/run-mutation.sh --all`.
#
# Usage:
#   scripts/run-mutation.sh [--base REF] [--budget SECONDS] [--threshold PCT]
#                           [--report PATH] [--incremental-file PATH]
#                           [--only FILE[,FILE...]] [--all]
#
#   --base REF        git ref to diff against (default: merge-base with origin/main,
#                     then origin/main, then main)
#   --budget SECONDS  wall-clock cap for the whole run (default $MUTATION_BUDGET_SECONDS,
#                     else 900)
#   --threshold PCT   mutation score threshold on covered code (default
#                     $MUTATION_THRESHOLD, else 80)
#   --report PATH     Stryker JSON report to read (default reports/mutation/mutation.json;
#                     the project's stryker config must write there)
#   --incremental-file PATH
#                     cache file (default reports/mutation/stryker-incremental.json)
#   --only FILES      mutate exactly these files (the survivor pass)
#   --all             mutate the whole tree (release only)
#
# Environment:
#   MUTATION_BASE, MUTATION_BUDGET_SECONDS, MUTATION_THRESHOLD,
#   MUTATION_REPORT, MUTATION_INCREMENTAL_FILE
#
# Exit codes:
#   0   score >= threshold
#   1   score < threshold
#   2   nothing to mutate (no changed files, or no survivor files given) — a skip,
#       not a failure
#   3   tooling failure (not a Stryker project, no base ref, node/npx missing)
#   124 wall-clock budget exceeded
#
# The score is always printed for the surface actually mutated, with both
# denominators: covered code (killed+survived+timeout) and the same set including
# NoCoverage. The threshold is applied to covered code, Stryker's own reading.
#
# Standards reference: docs/adr/0028-bounded-mutation-runs.md,
# docs/spec-pipeline/mutation-runner.md.
set -euo pipefail

BASE="${MUTATION_BASE:-}"
BUDGET="${MUTATION_BUDGET_SECONDS:-900}"
THRESHOLD="${MUTATION_THRESHOLD:-80}"
REPORT="${MUTATION_REPORT:-reports/mutation/mutation.json}"
INCREMENTAL="${MUTATION_INCREMENTAL_FILE:-reports/mutation/stryker-incremental.json}"
MODE="diff"
ONLY_FILES=()

usage() {
  sed -n '2,60p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

die() { echo "run-mutation: $*" >&2; exit 3; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --base=*) BASE="${1#*=}"; shift ;;
    --budget) BUDGET="${2:-}"; shift 2 ;;
    --budget=*) BUDGET="${1#*=}"; shift ;;
    --threshold) THRESHOLD="${2:-}"; shift 2 ;;
    --threshold=*) THRESHOLD="${1#*=}"; shift ;;
    --report) REPORT="${2:-}"; shift 2 ;;
    --report=*) REPORT="${1#*=}"; shift ;;
    --incremental-file) INCREMENTAL="${2:-}"; shift 2 ;;
    --incremental-file=*) INCREMENTAL="${1#*=}"; shift ;;
    --only) ONLY_FILES+=("${2:-}"); shift 2 ;;
    --only=*) ONLY_FILES+=("${1#*=}"); shift ;;
    --all) MODE="all"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument '$1' (try --help)" ;;
  esac
done

[ -n "$BUDGET" ] && [[ "$BUDGET" =~ ^[0-9]+$ ]] || die "--budget must be an integer number of seconds"
[ -n "$THRESHOLD" ] && [[ "$THRESHOLD" =~ ^[0-9]+$ ]] || die "--threshold must be an integer percentage"
[ "$BUDGET" -gt 0 ] || die "--budget must be greater than zero"

command -v npx >/dev/null 2>&1 || die "npx not found"
command -v node >/dev/null 2>&1 || die "node not found"

CONFIG=""
for candidate in stryker.config.mjs stryker.config.cjs stryker.config.js stryker.config.json; do
  if [ -f "$candidate" ]; then CONFIG="$candidate"; break; fi
done
[ -n "$CONFIG" ] || die "no stryker config in $(pwd) — not a Stryker project"

STRYKER_ARGS=()
if [ "$MODE" = "all" ]; then
  # Whole tree: let the project's own mutate globs decide the surface. Passing an
  # explicit --mutate here would override the config and mutate tests too.
  STRYKER_ARGS=()
elif [ "${#ONLY_FILES[@]}" -gt 0 ]; then
  joined=""
  for chunk in "${ONLY_FILES[@]}"; do
    joined="${joined:+$joined,}$chunk"
  done
  [ -n "$joined" ] || die "--only needs at least one file"
  STRYKER_ARGS=(--mutate "$joined")
else
  if [ -z "$BASE" ]; then
    if git rev-parse --verify -q origin/main >/dev/null 2>&1; then
      BASE="$(git merge-base HEAD origin/main 2>/dev/null || echo origin/main)"
    elif git rev-parse --verify -q main >/dev/null 2>&1; then
      BASE="main"
    else
      die "no --base given and no origin/main or main to diff against"
    fi
  fi
  git rev-parse --verify -q "$BASE^{commit}" >/dev/null 2>&1 || die "base ref '$BASE' does not resolve"
  CHANGED="$(git diff --name-only --diff-filter=ACMR "$BASE" -- 2>/dev/null || true)"
  if [ -z "$CHANGED" ]; then
    echo "run-mutation: no changed files against '$BASE' — nothing to mutate (skip)"
    exit 2
  fi
  STRYKER_ARGS=(--since "$BASE")
fi

mkdir -p "$(dirname "$REPORT")" "$(dirname "$INCREMENTAL")"

echo "run-mutation: mode=$MODE budget=${BUDGET}s threshold=${THRESHOLD}% report=$REPORT"
[ "$MODE" = "diff" ] && echo "run-mutation: base=${BASE}"

TIMEOUT_CMD=()
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(timeout --signal=TERM "$BUDGET")
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD=(gtimeout --signal=TERM "$BUDGET")
else
  echo "run-mutation: warning — no timeout(1)/gtimeout; the wall-clock budget is not enforced" >&2
fi

set +e
${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"} npx stryker run ${STRYKER_ARGS[@]+"${STRYKER_ARGS[@]}"} \
  --incremental --incrementalFile "$INCREMENTAL"
STATUS=$?
set -e

print_score() {
  node - "$REPORT" "$THRESHOLD" <<'NODE'
const fs = require('node:fs');
const [reportPath, thresholdArg] = process.argv.slice(2);
const report = JSON.parse(fs.readFileSync(reportPath, 'utf8'));
const counts = { Killed: 0, Survived: 0, Timeout: 0, NoCoverage: 0 };
const survivorFiles = new Map();
for (const [file, info] of Object.entries(report.files ?? {})) {
  let survivors = 0;
  for (const mutant of info.mutants ?? []) {
    if (mutant.status in counts) counts[mutant.status] += 1;
    if (mutant.status === 'Survived') survivors += 1;
  }
  if (survivors > 0) survivorFiles.set(file, survivors);
}
const covered = counts.Killed + counts.Survived + counts.Timeout;
const withUncovered = covered + counts.NoCoverage;
const pct = (numerator, denominator) =>
  denominator === 0 ? null : Math.round((1000 * numerator) / denominator) / 10;
const score = pct(counts.Killed + counts.Timeout, covered);
const scoreWithUncovered = pct(counts.Killed + counts.Timeout, withUncovered);
console.log(`mutation score (covered code): ${score === null ? 'n/a' : score + '%'} ` +
  `(killed ${counts.Killed}, survived ${counts.Survived}, timeout ${counts.Timeout}, no-coverage ${counts.NoCoverage})`);
console.log(`mutation score (incl. no-coverage): ${scoreWithUncovered === null ? 'n/a' : scoreWithUncovered + '%'}`);
if (survivorFiles.size > 0) {
  console.log('survivors by file:');
  for (const [file, survivors] of [...survivorFiles.entries()].sort((a, b) => b[1] - a[1])) {
    console.log(`  ${survivors}\t${file}`);
  }
  console.log('run-mutation: kill these with one targeted pass: scripts/run-mutation.sh --only <files>');
}
const threshold = Number(thresholdArg);
process.exit(score !== null && score >= threshold ? 0 : 1);
NODE
}

if [ "$STATUS" -eq 124 ]; then
  echo "run-mutation: budget of ${BUDGET}s exceeded — partial report kept at $REPORT" >&2
  if [ -f "$REPORT" ]; then print_score || true; fi
  exit 124
fi

if [ "$STATUS" -ne 0 ]; then
  echo "run-mutation: stryker exited $STATUS (tooling failure, not a score)" >&2
  if [ -f "$REPORT" ]; then print_score || true; fi
  exit 3
fi

[ -f "$REPORT" ] || die "stryker exited 0 but wrote no report at $REPORT (check jsonReporter.fileName)"
print_score
