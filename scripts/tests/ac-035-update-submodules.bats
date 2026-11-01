#!/usr/bin/env bats
# ac-035-update-submodules.bats — acceptance + characterization tests for
# scripts/update-submodules.sh (spec 035).
#
# Every fixture is a local `git init` repo under $TMPDIR_HELPER with `file://`
# remotes (and a per-test GIT_CONFIG_GLOBAL), so no test touches the network or
# a real sibling repository. Default-mode fixtures use a GitHub-shaped fetch URL
# whose push URL is rewritten to a local bare mirror — the push stays local.
#
# Scenario IDs: AC-035-01 … AC-035-26 (specs/035-child-project-standards-updater).

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  setup_tmpdir
  export GIT_CONFIG_GLOBAL="$TMPDIR_HELPER/gitconfig"
  export GIT_CONFIG_NOSYSTEM=1
  export GH_STUB_STATE="$TMPDIR_HELPER/gh-state"
  # Fixtures use main; never derive the branch from the host checkout (CI
  # push-event checkouts have no origin/HEAD or origin/main).
  export STANDARDS_BRANCH=main
  mkdir -p "$GH_STUB_STATE"
  git config --global user.email "test@example.com"
  git config --global user.name "Test"
  git config --global protocol.file.allow always
  git config --global init.defaultBranch main
  SCRIPT="$REPO_ROOT/scripts/update-submodules.sh"
  BRANCH="chore/bump-engineering-standards"
}

teardown() { teardown_tmpdir; }

# ── fixtures ────────────────────────────────────────────────────────────────

make_standards_remote() { # <dir>
  mkdir -p "$1"
  git -C "$1" init -q
  printf 'standards\n' > "$1/README.md"
  git -C "$1" add -A
  git -C "$1" commit -qm "initial standards"
}

bump_standards_remote() { # <dir>
  printf 'bump\n' >> "$1/CHANGELOG.md"
  git -C "$1" add -A
  git -C "$1" commit -qm "bump standards"
}

make_child() { # <dir> <standards-url>
  mkdir -p "$1"
  git -C "$1" init -q
  printf 'child\n' > "$1/README.md"
  git -C "$1" add -A
  git -C "$1" commit -qm "initial child"
  git -C "$1" -c protocol.file.allow=always submodule add -q "$2" .standards
  git -C "$1" commit -qm "add .standards submodule"
  git -C "$1" config protocol.file.allow always
}

make_child_with_origin() { # <dir> <standards-url> <bare-origin>
  make_child "$1" "$2"
  git init -q --bare "$3"
  git -C "$1" remote add origin "file://$3"
  git -C "$1" push -q -u origin main
}

# GitHub-shaped fetch URL, local push target: default-mode fixtures stay offline.
make_github_child_on() { # <dir> <standards-url> <default-branch>
  make_child "$1" "$2"
  git -C "$1" branch -m "$3"
  git init -q --bare "$TMPDIR_HELPER/gh-mirror/child.git"
  git -C "$1" remote add origin "https://github.com/example/child.git"
  git -C "$1" remote set-url --push origin "file://$TMPDIR_HELPER/gh-mirror/child.git"
  git -C "$1" push -q -u origin "$3"
}

make_github_child() { # <dir> <standards-url>
  make_github_child_on "$1" "$2" main
}

install_gh_stub() {
  mkdir -p "$TMPDIR_HELPER/bin"
  cat > "$TMPDIR_HELPER/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${GH_STUB_STATE}/calls.log"
if [ "$1 $2" = "pr list" ]; then
  if [ -f "${GH_STUB_STATE}/open-pr" ]; then echo 1; else echo 0; fi
elif [ "$1 $2" = "pr create" ]; then
  if [ "${GH_STUB_FAIL_CREATE:-0}" = "1" ]; then
    echo "gh: could not create pull request" >&2
    exit 1
  fi
  : > "${GH_STUB_STATE}/open-pr"
  echo "https://github.com/example/child/pull/1"
else
  echo "unexpected gh invocation: $*" >&2
  exit 1
fi
STUB
  chmod +x "$TMPDIR_HELPER/bin/gh"
}

# PATH containing bash, git and the POSIX tools the script needs — but no gh.
nogh_path() {
  local d="$TMPDIR_HELPER/nogh" b
  mkdir -p "$d"
  for b in bash git find grep sed awk cut dirname cat tr sort head env wc; do
    ln -sf "$(command -v "$b")" "$d/$b"
  done
  printf '%s' "$d"
}

make_diverged_child() { # <dir> <standards-url>
  local dir="$1" bare="$TMPDIR_HELPER/diverged.git" seed="$TMPDIR_HELPER/seed-diverged"
  git init -q --bare "$bare"
  make_child "$seed" "$2"
  git -C "$seed" remote add origin "file://$bare"
  git -C "$seed" push -q -u origin main
  git clone -q "file://$bare" "$dir"
  git -C "$dir" -c protocol.file.allow=always submodule update -q --init
  git clone -q "file://$bare" "$TMPDIR_HELPER/diverged-peer"
  printf 'remote\n' >> "$TMPDIR_HELPER/diverged-peer/README.md"
  git -C "$TMPDIR_HELPER/diverged-peer" add -A
  git -C "$TMPDIR_HELPER/diverged-peer" commit -qm "remote change"
  git -C "$TMPDIR_HELPER/diverged-peer" push -q origin main
  printf 'local\n' >> "$dir/README.md"
  git -C "$dir" add -A
  git -C "$dir" commit -qm "local change"
  git -C "$dir" fetch -q origin
}

# ── AC-035-01 … AC-035-04: eligibility ──────────────────────────────────────

@test "AC-035-01: non-git candidates are skipped and the run exits 0" {
  local a="$TMPDIR_HELPER/plain-a" b="$TMPDIR_HELPER/plain-b"
  mkdir -p "$a" "$b"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$a" "$b"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $a: not a git repository"* ]]
  [[ "$output" == *"[SKIP] $b: not a git repository"* ]]
  [[ "$output" == *"Summary: 0 succeeded, 0 failed, 2 skipped."* ]]
  [ ! -d "$a/.git" ]
  [ ! -f "$a/.gitmodules" ]
}

@test "AC-035-02: a git repo without .gitmodules is skipped" {
  local repo="$TMPDIR_HELPER/no-gitmodules"
  git init -q "$repo"
  printf 'x\n' > "$repo/README.md"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "initial"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $repo: no .gitmodules file"* ]]
  [[ "$output" == *"Summary: 0 succeeded, 0 failed, 1 skipped."* ]]
}

@test "AC-035-03: a repo declaring no .standards submodule is skipped" {
  local repo="$TMPDIR_HELPER/other-submodule"
  git init -q "$repo"
  printf 'x\n' > "$repo/README.md"
  printf '[submodule "other"]\n\tpath = other\n\turl = file:///nonexistent\n' > "$repo/.gitmodules"
  git -C "$repo" add -A
  git -C "$repo" commit -qm "other submodule"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$repo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $repo: no .standards submodule declared"* ]]
}

@test "AC-035-04: a repo declaring .standards is eligible and reaches the update step" {
  local std="$TMPDIR_HELPER/std-04" child="$TMPDIR_HELPER/child-04"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[LATEST] $child: already at latest"* ]]
  [[ "$output" != *"[SKIP]"* ]]
}

# ── AC-035-05: uninitialized submodule guard ────────────────────────────────

@test "AC-035-05: an uninitialized .standards submodule is skipped with a hint" {
  local std="$TMPDIR_HELPER/std-05" child="$TMPDIR_HELPER/child-05"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  git -C "$child" submodule deinit -q -f .standards
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $child: .standards submodule not initialized"* ]]
  [[ "$output" == *"git submodule update --init .standards"* ]]
  run --separate-stderr git -C "$child" submodule status .standards
  [ "$status" -eq 0 ]
  [ "${output:0:1}" = "-" ]
}

# ── AC-035-06 … AC-035-07: pointer update and commit ────────────────────────

@test "AC-035-06: a moved pointer is updated and committed in a single chore commit" {
  local std="$TMPDIR_HELPER/std-06" child="$TMPDIR_HELPER/child-06"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  bump_standards_remote "$std"
  local before
  before=$(git -C "$child" rev-parse HEAD:.standards)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] $child: updated and committed"* ]]
  local after
  after=$(git -C "$child" rev-parse HEAD:.standards)
  [ "$after" = "$(git -C "$std" rev-parse HEAD)" ]
  [ "$after" != "$before" ]
  [ "$(git -C "$child" log -1 --pretty=%s)" = "chore: bump engineering standards submodule" ]
  [ "$(git -C "$child" show --name-only --pretty=format: HEAD | tr -d '\n')" = ".standards" ]
  [ "$(git -C "$child/.standards" rev-parse HEAD)" = "$after" ]
  run git -C "$child" status --porcelain
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "AC-035-07: an already-latest pointer produces no commit" {
  local std="$TMPDIR_HELPER/std-07" child="$TMPDIR_HELPER/child-07"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  local head_before count_before
  head_before=$(git -C "$child" rev-parse HEAD)
  count_before=$(git -C "$child" rev-list --count HEAD)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[LATEST] $child: already at latest"* ]]
  [ "$(git -C "$child" rev-parse HEAD)" = "$head_before" ]
  [ "$(git -C "$child" rev-list --count HEAD)" = "$count_before" ]
}

# ── AC-035-08 … AC-035-12: discovery ────────────────────────────────────────

@test "AC-035-08: --parent-dir scans one level and selects only .standards repos" {
  local p="$TMPDIR_HELPER/P" std="$TMPDIR_HELPER/std-08"
  mkdir -p "$p/A" "$p/D/nested"
  make_standards_remote "$std"
  git init -q "$p/B"
  printf 'x\n' > "$p/B/README.md"
  git -C "$p/B" add -A
  git -C "$p/B" commit -qm "initial"
  make_child "$p/C" "file://$std"
  make_child "$p/D/nested" "file://$std"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --parent-dir "$p" --dry-run --local
  [ "$status" -eq 0 ]
  [[ "$output" == *"$p/C"* ]]
  [[ "$output" != *"$p/A"* ]]
  [[ "$output" != *"$p/B"* ]]
  [[ "$output" != *"$p/D"* ]]
}

@test "AC-035-09: the default parent is the standards repo's own parent, not the cwd" {
  local x="$TMPDIR_HELPER/X" std="$TMPDIR_HELPER/std-09"
  mkdir -p "$x/standards/scripts" "$TMPDIR_HELPER/unrelated"
  cp "$SCRIPT" "$x/standards/scripts/update-submodules.sh"
  make_standards_remote "$std"
  make_child "$x/sibling" "file://$std"
  make_child "$TMPDIR_HELPER/unrelated/local-child" "file://$std"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash -c \
    "cd '$TMPDIR_HELPER/unrelated' && bash '$x/standards/scripts/update-submodules.sh' --dry-run --local"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$x/sibling"* ]]
  [[ "$output" != *"local-child"* ]]
}

@test "AC-035-10: explicit path arguments disable additional discovery" {
  local std="$TMPDIR_HELPER/std-10" r1="$TMPDIR_HELPER/R1" r2="$TMPDIR_HELPER/R2"
  make_standards_remote "$std"
  make_child "$r1" "file://$std"
  make_child "$r2" "file://$std"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --dry-run --local "$r1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"$r1"* ]]
  [[ "$output" != *"$r2"* ]]
}

@test "AC-035-11: repo-list.txt is read when no higher-precedence input is given" {
  local s="$TMPDIR_HELPER/S" std="$TMPDIR_HELPER/std-11"
  mkdir -p "$s/scripts"
  cp "$SCRIPT" "$s/scripts/update-submodules.sh"
  make_standards_remote "$std"
  make_child "$TMPDIR_HELPER/L1" "file://$std"
  make_child "$TMPDIR_HELPER/L2" "file://$std"
  make_child "$TMPDIR_HELPER/L3" "file://$std"
  printf '# comment\n\n%s\n%s\n' "$TMPDIR_HELPER/L1" "$TMPDIR_HELPER/L2" > "$s/repo-list.txt"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$s/scripts/update-submodules.sh" --dry-run --local
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TMPDIR_HELPER/L1"* ]]
  [[ "$output" == *"$TMPDIR_HELPER/L2"* ]]
  [[ "$output" != *"$TMPDIR_HELPER/L3"* ]]
}

@test "AC-035-12: --auto stays cwd-relative" {
  local work="$TMPDIR_HELPER/work" std="$TMPDIR_HELPER/std-12"
  mkdir -p "$work"
  make_standards_remote "$std"
  make_child "$work/C" "file://$std"
  make_child "$TMPDIR_HELPER/outside" "file://$std"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash -c \
    "cd '$work' && bash '$SCRIPT' --auto --dry-run --local"
  [ "$status" -eq 0 ]
  [[ "$output" == *"./C"* ]]
  [[ "$output" != *"outside"* ]]
}

# ── AC-035-13 … AC-035-14: dirty and diverged children ──────────────────────

@test "AC-035-13: a dirty child is skipped and left untouched" {
  local std="$TMPDIR_HELPER/std-13" child="$TMPDIR_HELPER/child-13"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  bump_standards_remote "$std"
  printf 'uncommitted\n' >> "$child/README.md"
  local before head_before
  before=$(git -C "$child" status --porcelain)
  head_before=$(git -C "$child" rev-parse HEAD)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $child: dirty working tree"* ]]
  [ "$(git -C "$child" status --porcelain)" = "$before" ]
  [ "$(git -C "$child" rev-parse HEAD)" = "$head_before" ]
}

@test "AC-035-14: a diverged local branch is skipped like a dirty tree" {
  local std="$TMPDIR_HELPER/std-14" child="$TMPDIR_HELPER/child-14"
  make_standards_remote "$std"
  make_diverged_child "$child" "file://$std"
  local head_before
  head_before=$(git -C "$child" rev-parse HEAD)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $child: local branch diverged from upstream"* ]]
  [ "$(git -C "$child" rev-parse HEAD)" = "$head_before" ]
  run git -C "$child" show-ref --verify --quiet "refs/heads/$BRANCH"
  [ "$status" -ne 0 ]
}

# ── AC-035-15 … AC-035-17: progression ──────────────────────────────────────

@test "AC-035-15: default mode branches, commits, pushes, and opens a PR without touching main" {
  local std="$TMPDIR_HELPER/std-15" child="$TMPDIR_HELPER/child-15"
  make_standards_remote "$std"
  make_github_child "$child" "file://$std"
  bump_standards_remote "$std"
  install_gh_stub
  local main_before
  main_before=$(git -C "$TMPDIR_HELPER/gh-mirror/child.git" rev-parse main)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] $child: updated, committed and pushed on $BRANCH, PR opened"* ]]
  [ "$(git -C "$TMPDIR_HELPER/gh-mirror/child.git" rev-parse main)" = "$main_before" ]
  run --separate-stderr git -C "$TMPDIR_HELPER/gh-mirror/child.git" show-ref --verify "refs/heads/$BRANCH"
  [ "$status" -eq 0 ]
  [ "$(git -C "$TMPDIR_HELPER/gh-mirror/child.git" rev-parse "$BRANCH")" != "$main_before" ]
  grep -q 'pr create' "$GH_STUB_STATE/calls.log"
}

@test "AC-035-16: a re-run reuses the existing branch and open PR" {
  local std="$TMPDIR_HELPER/std-16" child="$TMPDIR_HELPER/child-16"
  make_standards_remote "$std"
  make_github_child "$child" "file://$std"
  bump_standards_remote "$std"
  install_gh_stub
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$child"
  [ "$status" -eq 0 ]
  bump_standards_remote "$std"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"reused open PR"* ]]
  [ "$(grep -c 'pr create' "$GH_STUB_STATE/calls.log")" -eq 1 ]
  [ -f "$GH_STUB_STATE/open-pr" ]
  [ "$(git -C "$TMPDIR_HELPER/gh-mirror/child.git" branch --list "$BRANCH" | wc -l)" -eq 1 ]
}

@test "AC-035-17: --local commits on the current branch and never pushes" {
  local std="$TMPDIR_HELPER/std-17" child="$TMPDIR_HELPER/child-17" mirror="$TMPDIR_HELPER/mirror-17.git"
  make_standards_remote "$std"
  make_child_with_origin "$child" "file://$std" "$mirror"
  bump_standards_remote "$std"
  local main_before
  main_before=$(git -C "$mirror" rev-parse main)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] $child: updated and committed"* ]]
  [ "$(git -C "$child" rev-parse --abbrev-ref HEAD)" = "main" ]
  run git -C "$child" show-ref --verify --quiet "refs/heads/$BRANCH"
  [ "$status" -ne 0 ]
  [ "$(git -C "$mirror" rev-parse main)" = "$main_before" ]
  [ "$(git -C "$mirror" branch --list | wc -l)" -eq 1 ]
}

# ── AC-035-18 … AC-035-23: failures and exit codes ──────────────────────────

@test "AC-035-18: a .standards submodule without a remote fails the child" {
  local std="$TMPDIR_HELPER/std-18" child="$TMPDIR_HELPER/child-18"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  git -C "$child/.standards" remote remove origin
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] $child: .standards submodule has no remote"* ]]
  [[ "$output" == *"Summary: 0 succeeded, 1 failed, 0 skipped."* ]]
  [[ "$output" == *"  - $child: .standards submodule has no remote"* ]]
}

@test "AC-035-19: non-GitHub remote or missing gh fails in default mode" {
  local std="$TMPDIR_HELPER/std-19"
  make_standards_remote "$std"
  local plain="$TMPDIR_HELPER/plain-19" ghchild="$TMPDIR_HELPER/gh-19"
  make_child_with_origin "$plain" "file://$std" "$TMPDIR_HELPER/plain-19.git"
  install_gh_stub
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$plain"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] $plain: remote is not GitHub"* ]]
  make_github_child "$ghchild" "file://$std"
  run env PATH="$(nogh_path)" bash "$SCRIPT" "$ghchild"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] $ghchild: gh CLI not available"* ]]
}

@test "AC-035-20: an unreachable .standards remote is a recorded fetch failure" {
  local std="$TMPDIR_HELPER/std-20" child="$TMPDIR_HELPER/child-20"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  git -C "$child/.standards" remote set-url origin "file://$TMPDIR_HELPER/missing-remote"
  local pointer_before
  pointer_before=$(git -C "$child" rev-parse HEAD:.standards)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] $child: git submodule update --remote failed"* ]]
  [ "$(git -C "$child" rev-parse HEAD:.standards)" = "$pointer_before" ]
}

@test "AC-035-21: a mixed run reports both outcomes and exits 1" {
  local std="$TMPDIR_HELPER/std-21"
  make_standards_remote "$std"
  local good="$TMPDIR_HELPER/good-21" bad="$TMPDIR_HELPER/bad-21"
  make_child "$good" "file://$std"
  make_child "$bad" "file://$std"
  git -C "$bad/.standards" remote remove origin
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$good" "$bad"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[LATEST] $good: already at latest"* ]]
  [[ "$output" == *"Summary: 1 succeeded, 1 failed, 0 skipped."* ]]
  [[ "$output" == *"  - $bad: .standards submodule has no remote"* ]]
}

@test "AC-035-22: zero eligible children is a success" {
  local empty="$TMPDIR_HELPER/empty"
  mkdir -p "$empty"
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --parent-dir "$empty" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"No children were processed."* ]]
}

@test "AC-035-23: --parent-dir naming a non-existent path or a file is a usage error" {
  local missing="$TMPDIR_HELPER/does-not-exist" file="$TMPDIR_HELPER/not-a-dir"
  printf 'x\n' > "$file"
  run --separate-stderr env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --parent-dir "$missing"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$missing"* ]]
  run --separate-stderr env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --parent-dir "$file"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$file"* ]]
}

# ── AC-035-24 … AC-035-25: dry run ──────────────────────────────────────────

@test "AC-035-24: --dry-run prints the plan and mutates nothing" {
  local std="$TMPDIR_HELPER/std-24" child="$TMPDIR_HELPER/child-24"
  make_standards_remote "$std"
  make_github_child "$child" "file://$std"
  bump_standards_remote "$std"
  install_gh_stub
  local head_before sub_before main_before
  head_before=$(git -C "$child" rev-parse HEAD)
  sub_before=$(git -C "$child/.standards" rev-parse HEAD)
  main_before=$(git -C "$TMPDIR_HELPER/gh-mirror/child.git" rev-parse main)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --dry-run "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PLAN] $child: would update .standards, commit on $BRANCH, push, and open a PR"* ]]
  [ "$(git -C "$child" rev-parse HEAD)" = "$head_before" ]
  [ "$(git -C "$child/.standards" rev-parse HEAD)" = "$sub_before" ]
  run git -C "$child" show-ref --verify --quiet "refs/heads/$BRANCH"
  [ "$status" -ne 0 ]
  [ "$(git -C "$TMPDIR_HELPER/gh-mirror/child.git" rev-parse main)" = "$main_before" ]
  [ ! -f "$GH_STUB_STATE/calls.log" ]
}

@test "AC-035-25: --dry-run makes no network calls to an unreachable remote" {
  local std="$TMPDIR_HELPER/std-25" child="$TMPDIR_HELPER/child-25"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  git -C "$child/.standards" remote set-url origin "file://$TMPDIR_HELPER/missing-dry-run"
  local sub_before
  sub_before=$(git -C "$child/.standards" rev-parse HEAD)
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --dry-run --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[PLAN] $child: would update .standards and commit locally"* ]]
  [[ "$output" != *"fatal"* ]]
  [ "$(git -C "$child/.standards" rev-parse HEAD)" = "$sub_before" ]
}

# ── AC-035-26: hermetic characterization + README ───────────────────────────

@test "AC-035-26: the suite is hermetic and the README no longer lists the script as uncharacterized" {
  run grep -q 'file://' "$REPO_ROOT/scripts/tests/ac-035-update-submodules.bats"
  [ "$status" -eq 0 ]
  run grep -q 'update-submodules.sh' "$REPO_ROOT/scripts/tests/README.md"
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016  # the backticks are part of the regex, not a subshell
  run grep -qE '^\| *`update-submodules.sh`' "$REPO_ROOT/scripts/tests/README.md"
  [ "$status" -ne 0 ]
  grep -q 'ac-035-update-submodules.bats' "$REPO_ROOT/scripts/tests/README.md"
}

# ── unit coverage beyond the scenarios ──────────────────────────────────────

@test "update-submodules: --help documents --parent-dir, --auto, --local and --dry-run" {
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"--parent-dir"* ]]
  [[ "$output" == *"--auto"* ]]
  [[ "$output" == *"--local"* ]]
  [[ "$output" == *"--dry-run"* ]]
}

@test "update-submodules: an unknown flag is a usage error" {
  run --separate-stderr env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --bogus
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"unknown option"* ]]
}

@test "update-submodules: --parent-dir without a value is a usage error" {
  run --separate-stderr env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --parent-dir
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"--parent-dir"* ]]
}

@test "update-submodules: --local needs no gh on PATH" {
  local std="$TMPDIR_HELPER/std-unit" child="$TMPDIR_HELPER/child-unit"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  bump_standards_remote "$std"
  run env PATH="$(nogh_path)" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[OK] $child: updated and committed"* ]]
}

@test "update-submodules: a staged-but-uncommitted change also counts as dirty" {
  local std="$TMPDIR_HELPER/std-unit2" child="$TMPDIR_HELPER/child-unit2"
  make_standards_remote "$std"
  make_child "$child" "file://$std"
  printf 'staged\n' >> "$child/README.md"
  git -C "$child" add README.md
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" --local "$child"
  [ "$status" -eq 0 ]
  [[ "$output" == *"[SKIP] $child: dirty working tree"* ]]
  run git -C "$child" diff --cached --name-only
  [ "$status" -eq 0 ]
  [ "$output" = "README.md" ]
}

@test "update-submodules: a master default branch is the PR base" {
  local std="$TMPDIR_HELPER/std-unit3" child="$TMPDIR_HELPER/child-unit3"
  make_standards_remote "$std"
  make_github_child_on "$child" "file://$std" master
  bump_standards_remote "$std"
  install_gh_stub
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$child"
  [ "$status" -eq 0 ]
  grep -q -- '--base master' "$GH_STUB_STATE/calls.log"
}

@test "update-submodules: a push failure is a recorded per-child failure" {
  local std="$TMPDIR_HELPER/std-unit4" child="$TMPDIR_HELPER/child-unit4"
  make_standards_remote "$std"
  make_github_child "$child" "file://$std"
  git -C "$child" remote set-url --push origin "file://$TMPDIR_HELPER/missing-mirror.git"
  bump_standards_remote "$std"
  install_gh_stub
  run env PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$child"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] $child: push failed"* ]]
}

@test "update-submodules: a gh pr create failure is a recorded per-child failure" {
  local std="$TMPDIR_HELPER/std-unit5" child="$TMPDIR_HELPER/child-unit5"
  make_standards_remote "$std"
  make_github_child "$child" "file://$std"
  bump_standards_remote "$std"
  install_gh_stub
  run env GH_STUB_FAIL_CREATE=1 PATH="$TMPDIR_HELPER/bin:$PATH" bash "$SCRIPT" "$child"
  [ "$status" -eq 1 ]
  [[ "$output" == *"[FAIL] $child: gh pr create failed"* ]]
}
