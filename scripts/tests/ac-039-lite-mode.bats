#!/usr/bin/env bats
# ac-039-lite-mode.bats — acceptance tests for spec 039 Tasks 1-4
# (specs/039-pipeline-lite-mode/20-acceptance/AC-039-01..04).
# Contract: the three lite-mode scripts are the only place the trigger match,
# the size classifier, and the tier guard live.

load test_helper
bats_require_minimum_version 1.5.0

TRIGGER="$REPO_ROOT/scripts/lite-trigger.sh"
CLASSIFY="$REPO_ROOT/scripts/classify-spec-size.sh"
RESOLVE="$REPO_ROOT/scripts/resolve-pipeline-mode.sh"
DECISIONS="$REPO_ROOT/scripts/autopilot-decisions.sh"

setup() { setup_tmpdir; }
teardown() { teardown_tmpdir; }

# declare_tier <repo> <tier> — the repo's conformance-tier declaration, per
# docs/CONFORMANCE_TIERS.md §How to declare a tier.
declare_tier() {
  printf '# Fixture project\n\n## Conformance tier: %s\n' "$2" > "$1/AGENTS_FIXTURE.md"
}

# new_spec <repo> <slug> <tasks-body> <scenario-count> — a spec folder whose
# 10-tasks.md carries <tasks-body> and whose 20-acceptance/ holds N scenarios.
# Scenario headings are built at runtime so no fixture ID is inlined as a test
# reference (scripts/tests/README.md §Scenario IDs).
new_spec() {
  local repo="$1" slug="$2" body="$3" n="$4" d i
  d="$repo/specs/$slug"
  mkdir -p "$d/20-acceptance"
  printf '# fixture tasks\n\n%s\n' "$body" > "$d/10-tasks.md"
  : > "$d/20-acceptance/acceptance.md"
  for ((i = 1; i <= n; i++)); do
    printf '## AC-900-%02d — fixture scenario %d\n\nGiven a fixture input\n' "$i" "$i" \
      >> "$d/20-acceptance/acceptance.md"
  done
  printf '%s\n' "$d"
}

# fixture_repo <tier> <slug> <tasks-body> <scenario-count> — a repo root with
# one spec; prints the repo root. Pass an empty <tier> to leave it undeclared.
fixture_repo() {
  local repo="$TMPDIR_HELPER/repo" slug="$2"
  mkdir -p "$repo"
  [ -z "$1" ] || declare_tier "$repo" "$1"
  new_spec "$repo" "$slug" "$3" "$4" > /dev/null
  printf '%s\n' "$repo"
}

# classify_fixture <slug> <tasks-body> <scenario-count> — a spec folder built in
# the temp root, then classified. Leaves the usual bats run globals set.
classify_fixture() {
  run bash "$CLASSIFY" "$(new_spec "$TMPDIR_HELPER" "$1" "$2" "$3")"
}

# resolve_fixture <tier> <slug> <scenario-count> [mode-token ...] — a fixture
# repo holding exactly one `See docs/FOO.md.` spec, then resolved. Sets $repo
# and $spec for the calling test's assertions and leaves the bats run globals
# set (stderr separate, so a refusal never leaks into $output).
resolve_fixture() {
  local tier="$1" slug="$2" scenarios="$3"
  shift 3
  repo="$(fixture_repo "$tier" "$slug" 'See `docs/FOO.md`.' "$scenarios")"
  spec="$repo/specs/$slug"
  run --separate-stderr bash "$RESOLVE" "$spec" "$@"
}

# ── AC-039-01 — lite trigger detection ───────────────────────────────────────

@test "AC-039-01-01: an explicit LITE argv token prints lite" {
  run bash "$TRIGGER" 039-pipeline-lite-mode LITE
  [ "$status" -eq 0 ]
  [ "$output" = "lite" ]
}

@test "AC-039-01-02: an explicit full argv token prints full" {
  run bash "$TRIGGER" 039-pipeline-lite-mode full
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
}

@test "AC-039-01-03: no mode token prints auto" {
  run bash "$TRIGGER" 039-pipeline-lite-mode autopilot
  [ "$status" -eq 0 ]
  [ "$output" = "auto" ]
}

@test "AC-039-01-04: partial tokens do not match" {
  run bash "$TRIGGER" --lite lite-mode mylite
  [ "$status" -eq 0 ]
  [ "$output" = "auto" ]
}

@test "AC-039-01-05: conflicting tokens exit non-zero with an empty stdout" {
  run --separate-stderr bash "$TRIGGER" lite full
  [ "$status" -ne 0 ]
  [ -z "$output" ]
  [[ "$stderr" == *conflict* ]]
  [[ "$stderr" == *lite* ]]
  [[ "$stderr" == *full* ]]
}

# ── AC-039-02 — deterministic size/surface classifier ────────────────────────

@test "AC-039-02-01: a docs-only spec with 3 scenarios is lite" {
  classify_fixture 039-docs-only 'See `docs/FOO.md` for the change.' 3
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "lite" ]
  [[ "$output" == *"Reason:"* ]]
}

@test "AC-039-02-02: exactly one scripts/ file with 5 scenarios is lite" {
  classify_fixture 039-one-script 'Add `scripts/x.sh`.' 5
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "lite" ]
}

@test "AC-039-02-03: a docs-only spec with 6 scenarios is full" {
  classify_fixture 039-six-scenarios 'See `docs/FOO.md`.' 6
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "full" ]
  [[ "$output" == *"Reason:"* ]]
}

@test "AC-039-02-04: two scripts/ files with 2 scenarios is full" {
  classify_fixture 039-two-scripts 'Add `scripts/a.sh` and `scripts/b.sh`.' 2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "full" ]
}

@test "AC-039-02-05: a spec without 20-acceptance/ falls back to full" {
  local d="$TMPDIR_HELPER/repo/specs/039-no-acceptance"
  mkdir -p "$d"
  printf '# fixture tasks\n\nSee `docs/FOO.md`.\n' > "$d/10-tasks.md"
  run bash "$CLASSIFY" "$d"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "full" ]
}

@test "AC-039-02-06: a missing spec folder exits non-zero naming the path" {
  run --separate-stderr bash "$CLASSIFY" "$TMPDIR_HELPER/does-not-exist"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"does-not-exist"* ]]
}

@test "AC-039-02-07: the classifier is byte-identical across runs" {
  local d first second
  d="$(new_spec "$TMPDIR_HELPER" 039-deterministic 'See `docs/FOO.md`.' 3)"
  first="$(bash "$CLASSIFY" "$d")"
  sleep 1
  second="$(bash "$CLASSIFY" "$d")"
  [ "$first" = "$second" ]
}

# ── AC-039-03 — tier guard ──────────────────────────────────────────────────

@test "AC-039-03-01: the production tier refuses an explicit lite token" {
  resolve_fixture production 039-tier-prod 2 lite
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
  [[ "$stderr" == *lite* ]]
  [[ "$stderr" == *production* ]]
}

@test "AC-039-03-02: the production tier refuses a classifier lite" {
  resolve_fixture production 039-tier-prod-classifier 2
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
}

@test "AC-039-03-03: the multi-service tier refuses an explicit lite token" {
  resolve_fixture multi-service 039-tier-multi 2 lite
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
}

@test "AC-039-03-04: an undetectable tier refuses an explicit lite token" {
  resolve_fixture "" 039-tier-unknown 2 lite
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
  [[ "$stderr" == *tier* ]]
}

@test "unit: a relative spec path with an undetectable tier resolves full and terminates" {
  # The documented invocation form is relative (`specs/NNN-slug`). A relative
  # walk bottoms out at `.`, where `dirname .` is `.` — guard the resolver
  # against looping forever by failing the test on a timeout, not hanging.
  local repo
  repo="$(fixture_repo "" 039-tier-relative 'See `docs/FOO.md`.' 2)"
  cd "$repo"
  run --separate-stderr timeout 10 bash "$RESOLVE" "specs/039-tier-relative" lite
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
  [[ "$stderr" == *tier* ]]
  grep -q '^Chosen: full$' "$repo/specs/039-tier-relative/45-decisions.md"
}

@test "AC-039-03-05: the mvp tier permits an explicit lite token" {
  resolve_fixture mvp 039-tier-mvp 2 lite
  [ "$status" -eq 0 ]
  [ "$output" = "lite" ]
}

# ── AC-039-04 — mode resolution and decision logging ────────────────────────

@test "AC-039-04-01: the classifier decides when there is no token" {
  resolve_fixture mvp 039-classifier-decides 3
  [ "$status" -eq 0 ]
  [ "$output" = "lite" ]
  grep -q '^Chosen: lite$' "$spec/45-decisions.md"
  grep -qE '^Why: .*classifier' "$spec/45-decisions.md"
}

@test "AC-039-04-02: an explicit full token overrides a classifier lite" {
  resolve_fixture mvp 039-arg-full 3 full
  [ "$status" -eq 0 ]
  [ "$output" = "full" ]
  grep -qE '^Why: .*argument' "$spec/45-decisions.md"
}

@test "AC-039-04-03: an explicit lite token overrides a classifier full" {
  resolve_fixture mvp 039-arg-lite 9 lite
  [ "$status" -eq 0 ]
  [ "$output" = "lite" ]
  grep -qE '^Why: .*argument' "$spec/45-decisions.md"
}

@test "AC-039-04-04: a tier refusal is logged with why tier" {
  resolve_fixture production 039-tier-logged 2 lite
  [ "$status" -eq 0 ]
  grep -q '^Chosen: full$' "$spec/45-decisions.md"
  grep -qE '^Why: .*tier' "$spec/45-decisions.md"
}

@test "AC-039-04-05: the decision entry is appended in the six-line format" {
  local repo d first_entry
  repo="$(fixture_repo mvp 039-append 'See `docs/FOO.md`.' 3)"
  d="$repo/specs/039-append"
  bash "$DECISIONS" add "$d/45-decisions.md" \
    --condition 'pre-existing condition' --options 'lite, full' \
    --chosen 'full' --why 'pre-existing entry' \
    --reversibility 'none' --at '2026-01-01T00:00:00Z'
  first_entry="$(cat "$d/45-decisions.md")"

  run bash "$RESOLVE" "$d" lite
  [ "$status" -eq 0 ]

  [ "$(grep -c '^Condition:' "$d/45-decisions.md")" -eq 2 ]
  [ "$(printf '%s\n' "$first_entry" | grep -c '^Condition:')" -eq 1 ]
  # the first entry survives byte-identically
  diff -u <(printf '%s\n' "$first_entry") <(head -n "$(printf '%s\n' "$first_entry" | wc -l)" "$d/45-decisions.md")

  for label in Condition Options Chosen Why Reversibility At; do
    grep -qE "^${label}:" "$d/45-decisions.md" || {
      echo "missing labelled line: $label" >&2
      return 1
    }
  done
  grep -qE '^At: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$d/45-decisions.md"
}

@test "AC-039-04-06: a resolution writes only inside the spec folder" {
  local repo d dirty
  repo="$TMPDIR_HELPER/git-repo"
  mkdir -p "$repo"
  git -C "$repo" init -q
  git -C "$repo" config user.email "test@example.com"
  git -C "$repo" config user.name "Test"
  declare_tier "$repo" mvp
  d="$(new_spec "$repo" 039-writes 'See `docs/FOO.md`.' 3)"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "fixture"

  run bash "$RESOLVE" "$d" lite
  [ "$status" -eq 0 ]

  dirty="$(git -C "$repo" status --porcelain)"
  [ -n "$dirty" ]
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    case "${line:3}" in
      specs/039-writes/*) : ;;
      *) echo "unexpected dirty path: $line" >&2; return 1 ;;
    esac
  done <<< "$dirty"
}

# ── unit — behavior the scenarios do not spell out ──────────────────────────

@test "unit: the trigger match lives only in lite-trigger.sh" {
  # a second case-insensitive argv match would need the same lowercasing step;
  # no other script that lowercases an argument also knows the mode tokens
  local offenders
  offenders="$(grep -rlF "tr '[:upper:]' '[:lower:]'" "$REPO_ROOT/scripts" --include='*.sh' \
    | xargs grep -lE '(^|[^a-z])(lite|full)([^a-z]|$)' 2>/dev/null \
    | grep -v 'lite-trigger' || true)"
  [ -z "$offenders" ]
  # and the two orchestration entry points delegate to the index section that
  # names the single implementation instead of matching tokens themselves
  grep -qF 'docs/SPEC_PIPELINE.md §Lite mode' "$REPO_ROOT/commands/build.md"
  grep -qF 'docs/SPEC_PIPELINE.md §Lite mode' "$REPO_ROOT/agents/spec-pipeline.md"
}

@test "unit: the spec folder's own artifacts count as docs surface" {
  classify_fixture 039-own-artifacts 'Write `20-acceptance/` and `45-decisions.md`.' 3
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "lite" ]
}

@test "unit: a slash command token is not a named path" {
  classify_fixture 039-slash-command 'Run `/build` for `docs/FOO.md`.' 3
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "lite" ]
  [[ "$output" != *"/build"* ]]
}

@test "unit: a path outside docs/specs/scripts and not markdown forces full" {
  classify_fixture 039-other-surface 'Touch `commands/build.md` and `ci/templates/x.yml`.' 2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "full" ]
}

@test "unit: a spec naming no path falls back to full" {
  classify_fixture 039-no-paths 'Prose only, no file named as code.' 2
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "full" ]
}

@test "unit: a missing 10-tasks.md falls back to full" {
  local d="$TMPDIR_HELPER/repo/specs/039-no-tasks"
  mkdir -p "$d/20-acceptance"
  printf '## AC-900-01 — fixture\n\nGiven x\n' > "$d/20-acceptance/acceptance.md"
  run bash "$CLASSIFY" "$d"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "full" ]
}

@test "unit: resolution of a missing spec folder exits non-zero" {
  run --separate-stderr bash "$RESOLVE" "$TMPDIR_HELPER/no-such-spec" lite
  [ "$status" -ne 0 ]
  [[ "$stderr" == *"no-such-spec"* ]]
}

@test "unit: the resolved mode prints as exactly one bare token" {
  resolve_fixture mvp 039-one-token 3 full
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  case "$output" in
    lite|full) : ;;
    *) echo "unexpected mode token: $output" >&2; return 1 ;;
  esac
}

@test "unit: the classifier bases its answer only on the spec folder" {
  # no FILE under docs/FOO.md exists anywhere — naming a path is enough
  [ ! -e "$TMPDIR_HELPER/docs/FOO.md" ]
  classify_fixture 039-self-contained 'See `docs/FOO.md`.' 3
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "lite" ]
}
