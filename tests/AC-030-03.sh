#!/usr/bin/env bash
# tests/AC-030-03.sh — T3: skills/e2e-testing/assets/e2e.config.example.ts
# Scenarios from specs/030-e2e-skill-agent/20-acceptance/AC-030-03.md
set -euo pipefail
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ac-030-lib.sh"
cd "$AC030_ROOT"
CFG="skills/e2e-testing/assets/e2e.config.example.ts"

# AC-030-03-01 — Config example file exists
s_030_03_01() { exists "AC-030-03-01" "$CFG"; }

# AC-030-03-02 — Model ids from environment variables
s_030_03_02() {
  contains "AC-030-03-02" "$CFG" 'process\.env' 'process.env indirection for model ids'
  contains "AC-030-03-02" "$CFG" 'E2E_AGENT_MODEL' 'the E2E_AGENT_MODEL variable'
  contains "AC-030-03-02" "$CFG" 'E2E_JUDGE_MODEL' 'the E2E_JUDGE_MODEL variable'
  not_contains_i "AC-030-03-02" "$CFG" "$ID_PATTERNS" 'hardcoded model id strings'
}

# AC-030-03-03 — Port-0 pattern and app launch present
s_030_03_03() {
  contains "AC-030-03-03" "$CFG" 'targets' 'a targets array'
  contains "AC-030-03-03" "$CFG" 'app' 'the app launch block'
  contains "AC-030-03-03" "$CFG" 'command' 'app.command (shell-less launch)'
  if grep -qE 'localhost:0|"0"|:0' "$CFG" && grep -q '{port}' "$CFG"; then
    pass "AC-030-03-03: port 0 url and {port} substitution present"
  else
    fail "AC-030-03-03: port-0 pattern or {port} substitution missing"
  fi
}

# AC-030-03-04 — Budgets and cache modes configured
s_030_03_04() {
  contains_i "AC-030-03-04" "$CFG" 'budget' 'budget configuration'
  contains_i "AC-030-03-04" "$CFG" 'modelCall|model.call|action|timeout' 'budget dimensions (model calls / actions / timeout)'
  contains "AC-030-03-04" "$CFG" 'read-write' 'cache mode read-write'
  contains "AC-030-03-04" "$CFG" 'read-only' 'cache mode read-only'
  contains "AC-030-03-04" "$CFG" 'off' 'cache mode off'
}

# AC-030-03-05 — Telemetry opt-out and tests path present
s_030_03_05() {
  contains "AC-030-03-05" "$CFG" 'E2E_TELEMETRY_DISABLED' 'telemetry opt-out reference'
  contains "AC-030-03-05" "$CFG" 'tests/\*\*/\*\.e2e\.ts' 'the tests/**/*.e2e.ts glob'
  not_contains_i "AC-030-03-05" "$CFG" 'dotenv|loadEnv|from ["'"'"']\.env|import ["'"'"']\.env' 'no .env file loading'
  not_contains_i "AC-030-03-05" "$CFG" '(api[_-]?key|token|secret|password)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_./+-]{12,}' 'credential literals'
}

# unit — the example is valid TypeScript (T3 acceptance criterion "parseable
# by tsc --noEmit or syntactically valid"). No tsc is installed here and npx
# would need the network, so "syntactically valid" is proven via Node's
# type-stripping module loader: import() parses TS syntax (annotations,
# `as` casts) with zero side effects from this config file.
u_030_03_valid_typescript() {
  require "unit T3" "$CFG" || return 0
  if ! command -v node >/dev/null 2>&1; then fail "unit T3: node not available to parse the TS config"; return 0; fi
  local err=""
  err="$(node -e "import('file://$PWD/$CFG').then(()=>process.exit(0), (e) => { console.error(e.message); process.exit(1); })" 2>&1)" || {
    fail "unit T3: node type-strip parse rejected the config: $err"
    return 0
  }
  pass "unit T3: e2e.config.example.ts parses as valid TypeScript (node type-strip import)"
}

# unit — app launch is shell-less: the command is an argv array, not a shell string
u_030_03_shellless_command() {
  require "unit T3" "$CFG" || return 0
  if grep -A3 'command:' "$CFG" | grep -q '\['; then
    pass "unit T3: app.command uses an argv array (shell-less)"
  else
    fail "unit T3: app.command is not an argv array"
  fi
}

# unit — budgets demonstrate both a default and a per-agent override
u_030_03_budget_shapes() {
  require "unit T3" "$CFG" || return 0
  if grep -qiE 'default|budgets?[[:space:]]*:' "$CFG" && grep -qiE 'agent|judge' "$CFG"; then
    pass "unit T3: budget config shows defaults plus per-agent wiring"
  else
    fail "unit T3: budget config lacks default or per-agent shape"
  fi
}

main_dispatch "030_03" "${1:-all}"
finish "AC-030-03"
