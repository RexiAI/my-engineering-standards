#!/usr/bin/env bats
# Spec 042 — repo config: the opencode.json bash permission block (AC-042-11)
# and the .gitignore / rb_* capture hardening (AC-042-12).

load test_helper

OPENCODE_JSON="${REPO_ROOT}/opencode.json"
GITIGNORE="${REPO_ROOT}/.gitignore"

# in_repo <command...> — run a git command with the repo as cwd.
in_repo() {
  ( cd "$REPO_ROOT" && "$@" )
}

@test "AC-042-11-01: the config stays valid and the model wiring is untouched" {
  run python3 - "$OPENCODE_JSON" <<'PY'
import json, re, sys
doc = json.load(open(sys.argv[1]))
assert doc["$schema"] == "https://opencode.ai/config.json", doc["$schema"]
agents = doc["agent"]
expected = {
    "spec-specifier", "spec-ux", "spec-verifier", "spec-mutation-runner",
    "spec-pr-opener", "spec-deployer", "spec-coder", "spec-refactorer",
    "spec-pipeline", "pr-review",
}
assert set(agents) == expected, sorted(agents)
for name, cfg in agents.items():
    model = cfg.get("model", "")
    assert re.fullmatch(r"\{env:SPEC_[A-Z0-9_]+\}", model), (name, model)
print("OK schema=%s agents=%d" % (doc["$schema"], len(agents)))
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK schema=https://opencode.ai/config.json agents=10"* ]]
}

@test "AC-042-11-02: the denied commands are blocked" {
  run python3 - "$OPENCODE_JSON" <<'PY'
import json, sys
bash = json.load(open(sys.argv[1]))["permission"]["bash"]
deny = [
    "git push --force*", "git push -f*", "git push --force-with-lease*",
    "git push * main*", "git push * master*", "git push --delete*",
    "git push * --delete*", "git push * :*", "git branch -D*",
    "git branch --delete --force*", "git tag*",
]
wrong = ["%s=%s" % (k, bash.get(k)) for k in deny if bash.get(k) != "deny"]
assert not wrong, "wrong disposition: " + ", ".join(wrong)
print("OK denied=%d" % len(deny))
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK denied=11"* ]]
}

@test "AC-042-11-03: commit and push are asked, not allowed silently" {
  run python3 - "$OPENCODE_JSON" <<'PY'
import json, sys
bash = json.load(open(sys.argv[1]))["permission"]["bash"]
assert bash.get("*") == "allow", bash.get("*")
assert bash.get("git push*") == "ask", bash.get("git push*")
assert bash.get("git commit*") == "ask", bash.get("git commit*")
print("OK catch-all=allow push=ask commit=ask")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK catch-all=allow push=ask commit=ask"* ]]
}

@test "AC-042-11-04: rule order preserves the last-matching-rule contract" {
  run python3 - "$OPENCODE_JSON" <<'PY'
import json, sys
bash = json.load(open(sys.argv[1]))["permission"]["bash"]
keys = list(bash.keys())
assert keys[0] == "*", keys[0]
asks = [i for i, k in enumerate(keys) if bash[k] == "ask"]
denies = [i for i, k in enumerate(keys) if bash[k] == "deny"]
assert asks and denies
assert max(asks) < min(denies), "an ask rule follows a deny rule: %s" % keys
print("OK order=* first, %d ask(s), %d deny(ies)" % (len(asks), len(denies)))
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK order=* first, 2 ask(s), 11 deny(ies)"* ]]
}

@test "AC-042-11-05: the block and its ordering rule are documented" {
  local doc="${REPO_ROOT}/docs/AGENTS_AND_SKILLS.md" block
  run grep -cxF -- '### Repo-level permission block' "$doc"
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  block="$(md_section "$doc" '### Repo-level permission block' 2 3)"
  [ -n "$block" ]
  [[ "$block" == *'opencode.json'* ]]
  [[ "$block" == *'last matching rule wins'* ]]
  [[ "$block" == *'catch-all comes first'* ]]
  [[ "$block" == *'force-push'* ]]
  [[ "$block" == *'main`/`master'* ]]
  [[ "$block" == *'remote-branch delete'* ]]
  [[ "$block" == *'git branch -D'* ]]
  [[ "$block" == *'git tag'* ]]
  [[ "$block" == *'git commit'* ]]
  [[ "$block" == *'git push'* ]]
  [[ "$block" == *'agent frontmatter'* ]]
  [[ "$block" == *'take precedence'* ]]
}

@test "AC-042-12-01: dotenv variants are ignored" {
  grep -qxF -- '.env.*' "$GITIGNORE"
  in_repo git check-ignore --no-index -q .env.staging
  in_repo git check-ignore --no-index -q .env.production.local
}

@test "AC-042-12-02: committed templates stay trackable" {
  ! in_repo git check-ignore --no-index -q config/model.local.env.example
  ! in_repo git check-ignore --no-index -q config/agent.local.env.example
  ! in_repo git check-ignore --no-index -q templates/.envrc.example
}

@test "AC-042-12-03: gate-run capture dumps are ignored and untracked" {
  grep -qxF -- 'rb_*' "$GITIGNORE"
  in_repo git check-ignore --no-index -q rb_check-skills
  run in_repo git ls-files
  [ "$status" -eq 0 ]
  [[ "$output" != *"rb_check"* ]]
  [[ "$output" != *"rb_cpr2"* ]]
  [[ "$output" != *"rb_model-env.selftest"* ]]
  local capture
  for capture in rb_check-governance rb_check-model-env rb_check-no-hardcoded-secrets \
                 rb_check-orchestration rb_check-pr-review rb_check-skills rb_cpr2 \
                 rb_model-env.selftest; do
    [ ! -e "$REPO_ROOT/$capture" ]
  done
}

@test "AC-042-12-04: the telemetry ledger is not swept up" {
  run in_repo git ls-files -- runs.jsonl
  [ "$status" -eq 0 ]
  [ "$output" = "runs.jsonl" ]
  local ledger
  ledger="$(grep -n 'runs.jsonl' "$GITIGNORE")"
  [ -n "$ledger" ]
  [[ "$ledger" == *'scripts/record-gate-run.sh'* ]]
  [[ "$ledger" == *'ledger'* ]]
}

@test "AC-042-12-05: the secret gates still pass" {
  run in_repo bash scripts/guard-env.sh
  [ "$status" -eq 0 ]
  [[ "$output" == *"guard-env: no config/agent.local.env"* ]]
  run bash "$REPO_ROOT/scripts/check-no-hardcoded-secrets.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no hardcoded credential values"* ]]
}

# ── Unit coverage outside the acceptance scenarios ───────────────────────────

@test "repo config: pre-existing ignore entries are retained" {
  local entry
  for entry in '.env' '.env.local' '.envrc' 'config/model.local.env' 'config/agent.local.env' '.cache/'; do
    grep -qxF -- "$entry" "$GITIGNORE"
  done
  in_repo git check-ignore --no-index -q .envrc
  in_repo git check-ignore --no-index -q config/agent.local.env
}

@test "repo config: the permission block declares only the bash category" {
  run python3 - "$OPENCODE_JSON" <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
assert set(doc["permission"]) == {"bash"}, sorted(doc["permission"])
assert set(doc["permission"]["bash"].values()) <= {"allow", "ask", "deny"}
print("OK categories=bash dispositions=allow,ask,deny")
PY
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK categories=bash"* ]]
}
