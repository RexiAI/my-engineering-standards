#!/usr/bin/env bats
# bootstrap-capability-catalog.bats — acceptance fixtures for spec 033
# ("bootstrap capability catalog").
#
# One test per scenario in specs/033-bootstrap-capability-catalog/20-acceptance/.
# The ID in each test name is what scripts/check-scenario-traceability.sh greps
# for (docs/SPEC_PIPELINE.md §Scenario format).
#
# Fixture model: make_child_repo builds a hermetic child repo that consumes the
# standards tree the way a real child does — <child>/.standards/ holds symlinks
# to the standards subdirectories, while scripts/bootstrap.sh and
# scripts/capabilities.tsv are real copies so a test can add a probe row
# (AC-033-03) without touching the standards repo itself.
load test_helper

CHILD=""

setup() {
  setup_tmpdir
  CHILD="$TMPDIR_HELPER/child"
  make_child_repo "$CHILD"
  export CHILD
}

teardown() {
  teardown_tmpdir
}

# ── fixtures ─────────────────────────────────────────────────────────────────

make_child_repo() { # make_child_repo DIR
  local child="$1" d f
  mkdir -p "$child/.standards/scripts"
  git -C "$child" init -q
  git -C "$child" config user.email "test@example.com"
  git -C "$child" config user.name "Test"
  git -C "$child" config commit.gpgsign false
  for d in templates language-specific agents commands skills ci okf .github; do
    ln -s "$REPO_ROOT/$d" "$child/.standards/$d"
  done
  for f in "$REPO_ROOT"/scripts/*; do
    ln -s "$f" "$child/.standards/scripts/$(basename "$f")"
  done
  rm -f "$child/.standards/scripts/bootstrap.sh" \
        "$child/.standards/scripts/capabilities.tsv"
  cp "$REPO_ROOT/scripts/bootstrap.sh" "$child/.standards/scripts/bootstrap.sh"
  cp "$REPO_ROOT/scripts/capabilities.tsv" "$child/.standards/scripts/capabilities.tsv"
}

run_bootstrap_at() { # run_bootstrap_at DIR [FLAGS...]
  local root="$1"
  shift
  run bash -c 'cd "$1"; shift; exec bash ./.standards/scripts/bootstrap.sh "$@"' _ "$root" "$@"
}

run_bootstrap() { # run_bootstrap [FLAGS...]
  run_bootstrap_at "$CHILD" "$@"
}

run_init_ci_at() { # run_init_ci_at DIR [FLAGS...]
  local root="$1"
  shift
  run bash -c 'cd "$1"; shift; exec bash ./.standards/scripts/init-ci.sh "$@"' _ "$root" "$@"
}

run_init_ci() {
  run_init_ci_at "$CHILD" "$@"
}

# A pty-backed run: bootstrap only renders its menu when stdin is a TTY, so the
# menu scenarios need `script` (util-linux) to allocate one. TTY_INPUT is fed
# on stdin ("\n" accepts the preselected defaults; "none\n\n" selects core
# wiring only) and TTY_ARGS carries the flag string (empty for "no flags").
run_tty_at() { # run_tty_at DIR INPUT [FLAGS...]
  local root="$1" input="$2"
  shift 2
  export TTY_INPUT="$input" TTY_ARGS="$*"
  run bash -c 'cd "$1" && printf "%b" "$TTY_INPUT" | script -qec "bash ./.standards/scripts/bootstrap.sh $TTY_ARGS" /dev/null' _ "$root"
}

run_tty() { # run_tty INPUT [FLAGS...]
  local input="$1"
  shift
  run_tty_at "$CHILD" "$input" "$@"
}

require_tty_helper() {
  command -v script >/dev/null 2>&1 || skip "util-linux 'script' not available to allocate a pty"
}

menu_output() {
  printf '%s\n' "$output" | tr -d '\r'
}

write_pkg() { # write_pkg DEP [DEP...] — minimal package.json with the given deps
  local deps="" d
  for d in "$@"; do
    [ -n "$deps" ] && deps="$deps,"
    deps="$deps\"$d\":\"^1\""
  done
  printf '{"dependencies":{%s}}\n' "$deps" > "$CHILD/package.json"
}

list_files() { # list_files [DIR] — repo-relative files and symlinks
  local root="${1:-$CHILD}"
  ( cd "$root" && find . \( -path ./.git -o -path ./.standards \) -prune -o \
      \( -type f -o -type l \) -print | sed 's|^\./||' | sort )
}

checksums() { # checksums [DIR] — "cksum NAME" per file, portable across Linux/macOS
  local root="${1:-$CHILD}" f
  ( cd "$root" && find . \( -path ./.git -o -path ./.standards \) -prune -o \
      -type f -print | sed 's|^\./||' | sort | while IFS= read -r f; do
        printf '%s %s\n' "$(cksum < "$f")" "$f"
      done )
}

# ── Task 1: capability catalog ───────────────────────────────────────────────

@test "AC-033-01: --list prints every catalog entry as id<TAB>label<TAB>category" {
  run_bootstrap --list
  assert_exit_code 0 "$status"
  local catalog="$CHILD/.standards/scripts/capabilities.tsv"
  local expected
  expected=$(grep -vc -e '^#' -e '^$' "$catalog")
  [ "$expected" -ge 30 ] || { echo "catalog too small: $expected entries"; return 1; }
  [ "$(printf '%s\n' "$output" | grep -c .)" -eq "$expected" ] || {
    echo "expected $expected lines, got $(printf '%s\n' "$output" | grep -c .)"
    return 1
  }
  printf '%s\n' "$output" | grep -qE '^core-agents-md	[^	]+	Core wiring$'
}

@test "AC-033-02: --list output is generated from the catalog byte-for-byte" {
  run_bootstrap --list
  assert_exit_code 0 "$status"
  local catalog="$CHILD/.standards/scripts/capabilities.tsv"
  local expected
  expected=$(awk -F'|' '/^#/ || /^$/ {next} {printf "%s\t%s\t%s\n", $1, $2, $3}' "$catalog")
  [ "$output" = "$expected" ] || { printf 'list output != catalog render\n'; return 1; }
  local id
  while IFS='	' read -r id _ _; do
    [ -n "$id" ] || continue
    grep -q "^$id|" "$catalog" || { echo "id absent from catalog: $id"; return 1; }
  done <<< "$output"
}

@test "AC-033-03: menu, --list and --all all read the one catalog" {
  local catalog="$CHILD/.standards/scripts/capabilities.tsv"
  printf 'probe-cap|Probe capability|Core wiring|none|--with-probe|no|none|probe.txt||\n' >> "$catalog"

  run_bootstrap --list
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -q '^probe-cap	' || { echo "probe missing from --list"; return 1; }

  run_bootstrap --all --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -q 'probe-cap' || { echo "probe missing from --all plan"; return 1; }

  require_tty_helper
  run_tty ""
  assert_exit_code 0 "$status"
  menu_output | grep -qF 'Probe capability' || { echo "probe missing from menu"; return 1; }

  # No capability id or flag is hardcoded in bootstrap.sh's code — both come
  # from the catalog alone (the probe row is proof: it was never named
  # anywhere). Labels are not grepped: short ones ("Go", "Rust") collide with
  # ordinary prose, so the id/flag columns carry the mechanical assertion.
  local code="$TMPDIR_HELPER/bootstrap-code.txt"
  sed 's/#.*//' "$CHILD/.standards/scripts/bootstrap.sh" > "$code"
  local id flag
  while IFS='|' read -r id _ _ _ flag _ _ _ _ _; do
    case "$id" in ''|'#'*) continue ;; esac
    if grep -qF -e "$id" "$code"; then
      echo "capability id hardcoded in bootstrap.sh: $id"
      return 1
    fi
    if grep -qF -e "$flag" "$code"; then
      echo "capability flag hardcoded in bootstrap.sh: $flag"
      return 1
    fi
  done < "$REPO_ROOT/scripts/capabilities.tsv"
}

@test "AC-033-04: every catalog entry carries complete fields" {
  run awk -F'|' '
    /^#/ || /^$/ { next }
    { if (NF != 10) { printf("row %d (%s): expected 10 fields, got %d\n", NR, $1, NF); rc = 1 }
      if ($1 == "" || $2 == "" || $3 == "" || $8 == "") { printf("row %d: empty id/label/category/files\n", NR); rc = 1 }
      if ($4 != "backend" && $4 != "frontend" && $4 != "ci" && $4 != "none") { printf("row %d: bad required stack %s\n", NR, $4); rc = 1 }
      if ($5 == "") { printf("row %d: empty flag\n", NR); rc = 1 }
      if ($6 != "yes" && $6 != "no") { printf("row %d: bad baseline %s\n", NR, $6); rc = 1 }
      if ($7 == "") { printf("row %d: empty action\n", NR); rc = 1 } }
    END { exit rc }
  ' "$CHILD/.standards/scripts/capabilities.tsv"
  assert_exit_code 0 "$status"
}

# ── Task 2: detection across the full matrix ─────────────────────────────────

@test "AC-033-05: java detected via pom.xml" {
  touch "$CHILD/pom.xml"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[JAVA] detected via pom.xml'
}

@test "AC-033-06: go detected via a .go file" {
  printf 'package main\n' > "$CHILD/main.go"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[GO] detected via main.go'
}

@test "AC-033-07: node backend detected via package.json" {
  printf '{"name":"svc","version":"1.0.0"}\n' > "$CHILD/package.json"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[NODE] detected via package.json'
}

@test "AC-033-08: python detected via pyproject.toml" {
  printf '[project]\nname = "svc"\n' > "$CHILD/pyproject.toml"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[PYTHON] detected via pyproject.toml'
}

@test "AC-033-09: python detected via requirements.txt" {
  printf 'fastapi\n' > "$CHILD/requirements.txt"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[PYTHON] detected via requirements.txt'
}

@test "AC-033-10: rust detected via Cargo.toml" {
  printf '[package]\nname = "svc"\n' > "$CHILD/Cargo.toml"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[RUST] detected via Cargo.toml'
}

@test "AC-033-11: angular detected via @angular/core" {
  write_pkg "@angular/core"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[ANGULAR] detected via package.json'
  printf '%s\n' "$output" | grep -qE 'frontend-angular:'
}

@test "AC-033-12: ionic detected via @ionic/*" {
  write_pkg "@ionic/core"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[IONIC] detected via package.json'
  printf '%s\n' "$output" | grep -qE 'frontend-ionic:'
}

@test "AC-033-13: react-native detected via expo or react-native" {
  write_pkg "react" "expo"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[REACT-NATIVE] detected via package.json'
  write_pkg "react" "react-native"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[REACT-NATIVE] detected via package.json'
}

@test "AC-033-14: nextjs detected via next" {
  write_pkg "react" "next"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[NEXTJS] detected via package.json'
  printf '%s\n' "$output" | grep -qE 'frontend-nextjs:'
}

@test "AC-033-15: react detected via react with no more specific marker" {
  write_pkg "react" "react-dom"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[REACT] detected via package.json'
  ! printf '%s\n' "$output" | grep -qF '[NEXTJS]'
}

@test "AC-033-16: no framework marker yields frontend none" {
  printf '{"name":"svc","version":"1.0.0"}\n' > "$CHILD/package.json"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[NONE] no frontend marker found'
}

@test "AC-033-17: specific frontend markers win over react" {
  write_pkg "react" "expo"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[REACT-NATIVE]'
  ! printf '%s\n' "$output" | grep -qF '[REACT] detected'

  write_pkg "react" "next"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[NEXTJS]'
  ! printf '%s\n' "$output" | grep -qF '[REACT] detected'

  write_pkg "@ionic/core" "react"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[IONIC]'
  ! printf '%s\n' "$output" | grep -qF '[REACT] detected'

  write_pkg "react" "@angular/core"
  run_bootstrap --dry-run
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qF '[REACT] detected via package.json'
  ! printf '%s\n' "$output" | grep -qF '[ANGULAR]'
}

# ── Task 3: interactive menu + non-TTY default ───────────────────────────────

@test "AC-033-18: menu renders the catalog grouped by category" {
  require_tty_helper
  run_tty ""
  assert_exit_code 0 "$status"
  local out group
  out=$(menu_output)
  for group in '[Core wiring]' '[Backend stacks]' '[Frontend/mobile stacks]' \
               '[CI platform]' '[Quality gates]' '[Deploy]' '[Agent pipeline]' \
               '[Loop engineering]'; do
    printf '%s\n' "$out" | grep -qF "$group" || { echo "missing menu group $group"; return 1; }
  done
}

@test "AC-033-19: menu preselects the detected stack and no other" {
  require_tty_helper
  touch "$CHILD/pom.xml"
  run_tty ""
  assert_exit_code 0 "$status"
  local out
  out=$(menu_output)
  printf '%s\n' "$out" | grep -qE '^\[x\] +[0-9]+\) stack-java' || { echo "java not preselected"; return 1; }
  printf '%s\n' "$out" | grep -qE '^\[ \] +[0-9]+\) stack-go' || { echo "go listed as selected"; return 1; }
  printf '%s\n' "$out" | grep -qE '^\[ \] +[0-9]+\) stack-python' || { echo "python listed as selected"; return 1; }
}

@test "AC-033-20: menu selections map to the same flag set" {
  require_tty_helper
  local other="$TMPDIR_HELPER/child-flags"
  make_child_repo "$other"
  touch "$CHILD/pom.xml" "$other/pom.xml"

  run_tty ""
  assert_exit_code 0 "$status"
  local via_menu
  via_menu=$(list_files "$CHILD")

  run_bootstrap_at "$other" --with-core --stack java
  assert_exit_code 0 "$status"
  local via_flags
  via_flags=$(list_files "$other")

  [ "$via_menu" = "$via_flags" ] || { printf 'menu and flags wrote different file sets\n'; return 1; }
}

@test "AC-033-21: non-TTY with no flags writes core wiring and prints the opt-in command" {
  run_bootstrap
  assert_exit_code 0 "$status"
  local f
  for f in AGENTS.md opencode.json .envrc .gitattributes .gitignore config/.gitignore \
           .github/PULL_REQUEST_TEMPLATE.md session-start-check.sh \
           session-end-check.sh .githooks/pre-commit; do
    [ -e "$CHILD/$f" ] || { echo "missing core-wiring file: $f"; return 1; }
  done
  [ ! -e "$CHILD/.github/workflows/ci.yml" ] || { echo "CI must be skipped without flags"; return 1; }
  printf '%s\n' "$output" | grep -qF 'To enable more capabilities: ./.standards/scripts/bootstrap.sh --all'
}

@test "AC-033-22: TTY with no flags shows the full menu with --none as the escape" {
  require_tty_helper
  run_tty ""
  assert_exit_code 0 "$status"
  local out id
  out=$(menu_output)
  printf '%s\n' "$out" | grep -qF '[Core wiring]' || { echo "menu not rendered"; return 1; }
  printf '%s\n' "$out" | grep -qF -- '--none' || { echo "--none escape not offered"; return 1; }
  while IFS='|' read -r id _ _ _ _ _ action _ _ _; do
    case "$id" in ''|'#'*) continue ;; esac
    [ "$action" = "information" ] && continue
    printf '%s\n' "$out" | grep -q ")$(printf ' ') *$id" || { echo "menu omits $id"; return 1; }
  done < "$REPO_ROOT/scripts/capabilities.tsv"
}

# ── Task 4: flags, --all/--none, refusal, outcomes ───────────────────────────

@test "AC-033-23: every capability has a non-interactive flag" {
  run_bootstrap --help
  assert_exit_code 0 "$status"
  local flag
  for flag in --stack --frontend --with-saga --with-contract --with-mutation \
              --with-security --with-e2e --with-sweeper --with-pr-review \
              --with-release --with-deploy --with-spec-pipeline --with-loop \
              --copy-agents --all --none --dry-run --help --list; do
    printf '%s\n' "$output" | grep -qF -e "$flag" || { echo "--help omits $flag"; return 1; }
  done
  run awk -F'|' '/^#/ || /^$/ {next} $5 == "" {printf("capability %s maps to no flag\n", $1); rc = 1} END {exit rc}' \
    "$CHILD/.standards/scripts/capabilities.tsv"
  assert_exit_code 0 "$status"
}

@test "AC-033-24: --none performs core wiring only" {
  touch "$CHILD/pom.xml"
  run_bootstrap --none
  assert_exit_code 0 "$status"
  [ -f "$CHILD/AGENTS.md" ] || { echo "core wiring missing"; return 1; }
  [ ! -e "$CHILD/checkstyle.xml" ] || { echo "--none wrote stack config"; return 1; }
  [ ! -e "$CHILD/.github/workflows/ci.yml" ] || { echo "--none wrote CI"; return 1; }
  [ ! -e "$CHILD/templates/gate.yaml" ] || { echo "--none wrote extra templates"; return 1; }
}

@test "AC-033-25: --all enables only compatible entries and prints skip reasons" {
  touch "$CHILD/pom.xml"
  run_bootstrap --all
  assert_exit_code 0 "$status"
  local f
  for f in checkstyle.xml pitest-profile.xml pact-java.yml .github/workflows/ci.yml \
           .github/workflows/security.yml .github/workflows/e2e.yml \
           .github/workflows/sweeper.yml templates/LOOP.md; do
    [ -e "$CHILD/$f" ] || { echo "java-compatible entry not enabled: $f"; return 1; }
  done
  [ ! -e "$CHILD/stryker.conf.json" ] || { echo "node-only asset enabled for java"; return 1; }
  printf '%s\n' "$output" | grep -qE 'REFUSED \(requires the nextjs stack'
}

@test "AC-033-26: --all excludes deploy without a named tool" {
  touch "$CHILD/pom.xml"
  run_bootstrap --all
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -qE 'REFUSED \(--all excludes deploy' || { echo "deploy skip reason not printed"; return 1; }
  ! grep -q 'ci-deploy-' "$CHILD/.github/workflows/ci.yml"
  [ ! -e "$CHILD/.github/workflows/vercel-production-verify.yml" ] || { echo "vercel lane written"; return 1; }
}

@test "AC-033-27: --all includes deploy when a tool is named" {
  touch "$CHILD/pom.xml"
  run_bootstrap --all --with-deploy kamal
  assert_exit_code 0 "$status"
  grep -q 'ci-deploy-kamal.yml@' "$CHILD/.github/workflows/ci.yml"
  printf '%s\n' "$output" | grep -qE 'CREATED deploy-kamal'
}

@test "AC-033-28: an incompatible combination is refused with a named reason" {
  run_bootstrap --frontend nextjs --frontend angular
  [ "$status" -ne 0 ] || { echo "conflicting selection exited 0"; return 1; }
  printf '%s\n' "$output" | grep -qE 'REFUSED \(conflicts with frontend-nextjs\)'
  [ ! -e "$CHILD/.github/workflows/ci.yml" ] || { echo "refused run still wrote CI"; return 1; }
}

@test "AC-033-29: every capability reports exactly CREATED, SKIPPED (exists) or REFUSED (reason)" {
  touch "$CHILD/pom.xml"
  run_bootstrap --all
  assert_exit_code 0 "$status"
  ! printf '%s\n' "$output" | grep -qE '^\[(WRITE|COPY|SKIP|SYMLINK|APPEND|MERGE|REPLACE|REMOVE|CONFIG|WARN)\]'
  local count
  count=$(printf '%s\n' "$output" | grep -cE '^(CREATED |SKIPPED \(exists\) |REFUSED \()')
  [ "$count" -ge 10 ] || { echo "only $count outcome lines"; return 1; }
  local line
  while IFS= read -r line; do
    printf '%s\n' "$line" | grep -qE '^(CREATED|SKIPPED \(exists\)) [a-z][a-z0-9-]*: .+|^REFUSED \(.+\) [a-z][a-z0-9-]*$' \
      || { echo "outcome line outside the vocabulary: $line"; return 1; }
  done <<< "$(printf '%s\n' "$output" | grep -E '^(CREATED |SKIPPED \(exists\) |REFUSED \()')"
}

@test "AC-033-30: a re-run writes nothing twice and reports SKIPPED (exists)" {
  touch "$CHILD/pom.xml"
  run_bootstrap --all
  assert_exit_code 0 "$status"
  local before after
  before=$(checksums "$CHILD")
  run_bootstrap --all
  assert_exit_code 0 "$status"
  after=$(checksums "$CHILD")
  [ "$before" = "$after" ] || { printf 'a re-run rewrote files\n'; return 1; }
  printf '%s\n' "$output" | grep -qE '^SKIPPED \(exists\) stack-java:' || { echo "stack-java not skipped"; return 1; }
  ! printf '%s\n' "$output" | grep -qE '^CREATED '
}

# ── Task 5: init-ci.sh extension ─────────────────────────────────────────────

@test "AC-033-31: usage and error text are updated together" {
  run_init_ci --bogus-flag
  assert_exit_code 1 "$status"
  printf '%s\n' "$output" | grep -qF -e '--backend java,go,node,python,rust'
  printf '%s\n' "$output" | grep -qF -e '--frontend nextjs,react,angular,ionic,react-native,static'
}

@test "AC-033-32: --backend python is accepted and emits a python CI reference" {
  run_init_ci --platform github --backend python
  assert_exit_code 0 "$status"
  ! printf '%s\n' "$output" | grep -qi 'invalid backend'
  [ -f "$CHILD/.github/workflows/ci-python.yml" ] || { echo "no python workflow emitted"; return 1; }
  grep -qi 'ruff' "$CHILD/.github/workflows/ci-python.yml"
  ! grep -q 'ci-python.yml@' "$CHILD/.github/workflows/ci.yml"
}

@test "AC-033-33: --backend rust is accepted and emits a rust CI reference" {
  run_init_ci --platform github --backend rust
  assert_exit_code 0 "$status"
  ! printf '%s\n' "$output" | grep -qi 'invalid backend'
  [ -f "$CHILD/.github/workflows/ci-rust.yml" ] || { echo "no rust workflow emitted"; return 1; }
  grep -qi 'cargo' "$CHILD/.github/workflows/ci-rust.yml"
  ! grep -q 'ci-rust.yml@' "$CHILD/.github/workflows/ci.yml"
}

@test "AC-033-34: --frontend ionic is accepted and wires the Angular workflow" {
  run_init_ci --platform github --frontend ionic
  assert_exit_code 0 "$status"
  ! printf '%s\n' "$output" | grep -qi 'unknown flag'
  grep -q 'ci-angular.yml@' "$CHILD/.github/workflows/ci.yml"
  ! grep -q 'ci-ionic.yml@' "$CHILD/.github/workflows/ci.yml"
}

# ── Task 6: deploy ───────────────────────────────────────────────────────────

@test "AC-033-35: VPS deploy tools forward to init-ci --deploy-tool" {
  local tool root
  for tool in kamal dokku ssh; do
    root="$TMPDIR_HELPER/deploy-$tool"
    make_child_repo "$root"
    touch "$root/pom.xml"
    run_bootstrap_at "$root" --stack java --with-deploy "$tool"
    assert_exit_code 0 "$status"
    grep -q "ci-deploy-$tool.yml@" "$root/.github/workflows/ci.yml" \
      || { echo "no deploy job emitted for $tool"; return 1; }
  done
}

@test "AC-033-36: --with-deploy vercel wires the production-verify lane" {
  write_pkg "next"
  run_bootstrap --frontend nextjs --with-deploy vercel
  assert_exit_code 0 "$status"
  [ -f "$CHILD/.github/workflows/vercel-production-verify.yml" ] || { echo "vercel lane not written"; return 1; }
  grep -q 'ci-vercel-production-verify.yml@' "$CHILD/.github/workflows/vercel-production-verify.yml"
  grep -q 'VERCEL_TOKEN' "$CHILD/.github/workflows/vercel-production-verify.yml"
}

@test "AC-033-37: a missing or unknown deploy tool is refused" {
  run_bootstrap --with-deploy
  [ "$status" -ne 0 ] || { echo "missing tool exited 0"; return 1; }
  printf '%s\n' "$output" | grep -qE '^REFUSED \(missing value for --with-deploy'

  run_bootstrap --with-deploy kubernetes
  [ "$status" -ne 0 ] || { echo "unknown tool exited 0"; return 1; }
  printf '%s\n' "$output" | grep -qE "^REFUSED \(unknown value 'kubernetes' for --with-deploy"
}

# ── Task 7: agent pipeline ───────────────────────────────────────────────────

@test "AC-033-38: --with-pr-review forwards to init-ci" {
  touch "$CHILD/pom.xml"
  run_bootstrap --stack java --with-pr-review
  assert_exit_code 0 "$status"
  grep -q 'ci-pr-review.yml@' "$CHILD/.github/workflows/ci.yml"
}

@test "AC-033-39: --copy-agents copies agents, commands and skills as real directories" {
  # A real child gets these as real submodule directories; the shared fixture
  # symlinks them, and `cp -r` of a symlink copies the link — so this scenario
  # builds a submodule-shaped tree first.
  local root="$TMPDIR_HELPER/child-copy"
  make_child_repo "$root"
  rm "$root/.standards/agents" "$root/.standards/commands" "$root/.standards/skills"
  cp -r "$REPO_ROOT/agents" "$REPO_ROOT/commands" "$REPO_ROOT/skills" "$root/.standards/"
  run_bootstrap_at "$root" --copy-agents
  assert_exit_code 0 "$status"
  local d
  for d in agents commands skills; do
    [ -d "$root/.opencode/$d" ] || { echo ".opencode/$d not a directory"; return 1; }
    [ ! -L "$root/.opencode/$d" ] || { echo ".opencode/$d is still a symlink"; return 1; }
  done
  [ -f "$root/.opencode/agents/spec-verifier.md" ] || { echo "agents copy is empty"; return 1; }
}

@test "AC-033-40: --with-spec-pipeline wires the spec pipeline agents" {
  run_bootstrap --with-spec-pipeline
  assert_exit_code 0 "$status"
  [ -f "$CHILD/.opencode/agents/spec-verifier.md" ] || { echo "spec agents not wired"; return 1; }
  [ -f "$CHILD/.opencode/commands/spec.md" ] || { echo "spec commands not wired"; return 1; }
  printf '%s\n' "$output" | grep -qE '^SKIPPED \(exists\) agent-spec-pipeline:|^CREATED agent-spec-pipeline:'
}

# ── Task 8: loop engineering ─────────────────────────────────────────────────

@test "AC-033-41: --with-loop writes the loop files the gate validates" {
  run_bootstrap --with-loop
  assert_exit_code 0 "$status"
  local f
  for f in LOOP.md STATE.md loop-run-log.md loop-budget.md loop-constraints.md gate.yaml; do
    [ -s "$CHILD/templates/$f" ] || { echo "missing templates/$f"; return 1; }
    cmp -s "$CHILD/templates/$f" "$REPO_ROOT/templates/$f" || { echo "templates/$f differs from the template"; return 1; }
  done
  # Child scope is the mode a child repo can pass: it validates the six loop
  # files the bootstrap owns and skips the standards-repo-only artifacts
  # (docs/LOOP_ENGINEERING.md, AGENTS.md loop refs, self-ci wiring, the gate
  # script itself), which --with-loop does not write.
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" --scope child "$CHILD"
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -q 'Loop files check (child scope): every check passed'
  # ... and the same child must still fail the default standards scope. Child
  # scope narrows the gate; it does not turn it into a blanket pass.
  run bash "$REPO_ROOT/scripts/check-loop-files.sh" "$CHILD"
  assert_exit_code 1 "$status"
  printf '%s\n' "$output" | grep -q 'docs/LOOP_ENGINEERING.md is missing or empty'
}

@test "AC-033-42: --with-loop re-run is a no-op" {
  run_bootstrap --with-loop
  assert_exit_code 0 "$status"
  local before after
  before=$(checksums "$CHILD")
  run_bootstrap --with-loop
  assert_exit_code 0 "$status"
  after=$(checksums "$CHILD")
  [ "$before" = "$after" ] || { printf 'a --with-loop re-run rewrote files\n'; return 1; }
  printf '%s\n' "$output" | grep -qE '^SKIPPED \(exists\) loop-foundation:'
}

# ── Task 9: --dry-run and --help ─────────────────────────────────────────────

@test "AC-033-43: --dry-run writes nothing" {
  touch "$CHILD/pom.xml"
  local before
  before=$(list_files "$CHILD")
  run_bootstrap --dry-run --all
  assert_exit_code 0 "$status"
  [ "$before" = "$(list_files "$CHILD")" ] || { printf '--dry-run wrote files\n'; return 1; }
}

@test "AC-033-44: --dry-run prints the ids, files and init-ci flags" {
  touch "$CHILD/pom.xml"
  run_bootstrap --dry-run --stack java --with-saga
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -q 'stack-java' || { echo "plan omits stack-java"; return 1; }
  printf '%s\n' "$output" | grep -q 'checkstyle.xml' || { echo "plan omits the files"; return 1; }
  printf '%s\n' "$output" | grep -qF -e '--backend java' || { echo "plan omits init-ci flags"; return 1; }
  printf '%s\n' "$output" | grep -qF -e '--with-saga' || { echo "plan omits --with-saga"; return 1; }
  printf '%s\n' "$output" | grep -qF 'init-ci.sh flags:' || { echo "plan omits the init-ci summary"; return 1; }
}

@test "AC-033-45: --help lists every flag and exits 0" {
  run_bootstrap --help
  assert_exit_code 0 "$status"
  local flag
  for flag in --stack --frontend --platform --with-saga --with-contract \
              --with-mutation --with-security --with-e2e --with-sweeper \
              --with-pr-review --with-release --with-deploy \
              --with-spec-pipeline --with-loop --with-core --copy-agents \
              --all --none --dry-run --help --list; do
    printf '%s\n' "$output" | grep -qF -e "$flag" || { echo "--help omits $flag"; return 1; }
  done
}

# ── Task 10: fixtures + regression gates ─────────────────────────────────────

@test "AC-033-46: the new fixtures are covered by make test-scripts" {
  grep -q 'scripts/tests/\*.bats' "$REPO_ROOT/Makefile" || { echo "Makefile glob missing"; return 1; }
  [ -f "$REPO_ROOT/scripts/tests/bootstrap-capability-catalog.bats" ] || { echo "fixture missing"; return 1; }
  run bash "$REPO_ROOT/scripts/check-bats-assertions.sh"
  assert_exit_code 0 "$status"
}

@test "AC-033-47: orchestration references resolve" {
  run bash "$REPO_ROOT/scripts/check-orchestration.sh"
  assert_exit_code 0 "$status"
  printf '%s\n' "$output" | grep -q 'All orchestration references valid.'
}

@test "AC-033-48: skills and gate-consistency gates stay green" {
  run bash "$REPO_ROOT/scripts/check-skills.sh"
  assert_exit_code 0 "$status"
  run bash "$REPO_ROOT/scripts/check-gate-consistency.sh"
  assert_exit_code 0 "$status"
}

@test "AC-033-49: no regression in default output or existing init-ci flags" {
  touch "$CHILD/pom.xml"
  run_bootstrap
  assert_exit_code 0 "$status"
  local expected actual
  expected=$(printf '%s\n' \
    .envrc .gitattributes .gitignore .githooks/pre-commit \
    .github/PULL_REQUEST_TEMPLATE.md .opencode/agents .opencode/commands \
    .opencode/skills AGENTS.md checkstyle.xml config/.gitignore opencode.json \
    pmd-rules.xml session-end-check.sh session-start-check.sh spotbugs-include.xml \
    | sort)
  actual=$(list_files "$CHILD" | grep -vx 'pom.xml')
  [ "$expected" = "$actual" ] || { printf 'default file set changed\n--- expected\n%s\n--- actual\n%s\n' "$expected" "$actual"; return 1; }

  run_init_ci --platform github --backend java --frontend nextjs --with-saga \
              --with-deploy --deploy-tool ssh --with-release --with-pr-review \
              --registry ghcr.io
  assert_exit_code 0 "$status"
  local w="$CHILD/.github/workflows/ci.yml"
  local marker
  for marker in 'ci-java.yml@' 'ci-nextjs.yml@' 'ci-deploy-ssh.yml@' \
                'ci-release.yml@' 'ci-pr-review.yml@' 'docker-registry: ghcr.io'; do
    grep -qF "$marker" "$w" || { echo "init-ci regression: missing $marker"; return 1; }
  done
}
