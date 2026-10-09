# 029 — Local judgment backend: Verification (stage 4)

Spec: `specs/029-local-judgment-backend/` · Branch: `spec/028-typed-judgment-layer`
(029 stacks on 028; PR #73 open — the tree legitimately carries BOTH the committed
028 change set and the uncommitted 029 work; diff scope ruled accordingly:
029 = working-tree changes vs HEAD + untracked 029 files) · Verifier run date:
2026-10-09 (UTC) · **Attempt 1, phase 1** (first full run).

## Overall verdict: **PASS**

With one out-of-scope ruling on gate 2 (test suite), following the spec-028
precedent (`docs/changes/028-typed-judgment-layer.md` Adjudication B) and the
Stop-and-Ask matrix row "Out-of-scope finding — record it; do not fix; propose a
follow-up spec". No in-scope gate produced a finding. The Architect may proceed.

| # | Check | Result | Summary |
|---|---|---|---|
| 1 | Scenario traceability | **PASS** | exit 0 — 55/55 live IDs traced (all AC-029-*), `--json` `fails: []` |
| 2 | Full test suite | **FAIL (out-of-scope: env-caused ×4, branch-state ×1)** | `make test` exit 2 — 290 ok / 5 not ok / 0 skipped of 295; all 136 spec-029-scope tests green; the 5 failures proven NOT attributable to 029 (control runs + root cause below) |
| 3 | Complexity gate | **PASS** | CC ≤6 independently measured for all 55 functions in both changed shell files (worst CC 6); shellcheck: `typed-judgment.sh` clean, `judgment-local-up.sh` 2 advisory findings (1 warning + 1 info, both deliberate word-splitting idioms; CI shellcheck step is `continue-on-error`) — recorded as WARN notes W2 |
| 3.5 | Design-principles gate | **PASS** | `check-code-principles.sh -BaseRef HEAD --json` exit 0, `fails: []`, `warns: []`; full-tree exit 0, 0 FAIL / 14 WARN all pre-existing in `ci/templates/*` (untouched by 029) |
| 4 | Scenario-to-behavior spot check | **PASS** | seed-29 draw: AC-029-70, AC-029-05, AC-029-04 — all three tests assert what their Given/When/Then says (1 coverage note W4) |
| 5 | No unaccounted behavior | **PASS** | full 029 diff skimmed; every hunk traces to a Task 2–6 AC or an OQ-029-0x ruling (finding line below) |

Failing gate IDs (telemetry sense): none in scope — `gatesFailed: []`,
`outcome: pass`; the gate-2 out-of-scope FAIL is carried in warnings per the 028
telemetry precedent.

---

## Prior-stage claims — independently re-verified, not trusted

### Coder claims

- **"70 new tests (44+14+78 across three files)"** — CONFIRMED. Per-file bats
  runs: `typed-judgment.bats` 44/44 (exit 0), `typed-judgment-integration.bats`
  78/78 (exit 0), `judgment-local-up.bats` 14/14 (exit 0) = 136 total;
  136 − 66 spec-028 originals = 70 new. 028-era suite was 27 + 39 = 66.
- **"028's original 66 byte-intact and green"** — CONFIRMED. `git diff HEAD` on
  the two 028 bats files: **539 insertions(+), 0 deletions** — pure append, so
  every original line is byte-intact; all 44 + 78 report `ok` in the full-suite
  TAP (0 skipped anywhere in the run: `grep -c "# skip"` → 0). Structural
  invariant test AC-029-21 (ok 219) additionally pins the AC-028-prefixed
  @test counts (20 + 39; the other 7 of the 27 carry `unit:` names).
- **"Spike winner Kev-4B, p50 117 ms"** — CONFIRMED cross-artifact: spike report
  §Kev-4B table, ADR 0005 §Spike evidence, and the E2E addendum's raw-server
  latencies (66.2 / 176.2 ms server-side; 397 / 565 ms client-side single-call
  probes bracketing the 117 ms loop p50) are mutually consistent.
- **"min-confidence 0.28"** — CONFIRMED consistent in all four places: spike
  report (p5 = 0.2831 → 0.28, method stated), ADR 0005 (`JUDGMENT_MIN_CONFIDENCE=0.28`),
  `config/model.local.env.example` (commented `# JUDGMENT_MIN_CONFIDENCE=0.28` +
  method comment), `judgment-local-up.sh print_env_lines` (0.28). The
  cross-artifact consistency tests (AC-029-42/-46 extract and compare the
  number from all three files) pass.
- **"Stack torn down, GPU free"** — CONFIRMED live: `pgrep -af "kev\.serve"` →
  no matches; port 8009 not listening (`ss -tlnp | grep 8009` empty);
  `nvidia-smi` → 1283 MiB / 16311 MiB used (display baseline; spike recorded
  1243 MiB baseline + ~15.8 GiB under load); run dir `.cache/judgment/` holds
  only `kev.log`, no PID files — consistent with `down` semantics.
- **"Consumers untouched (AC-029-74)"** — CONFIRMED: `git diff HEAD --name-only
  -- agents/ skills/ci-triage/SKILL.md` → empty; `git status --short agents/
  skills/` → empty; test ok 245.

### Refactorer claims

- **"cmd_up CC 12→5, term_tree 8→2, all functions ≤6 CC"** — AFTER-STATE
  CONFIRMED by independent measurement (Evidence: complexity gate). I
  re-implemented the `check-code-principles.sh` `tokens()` heuristic for shell
  (same keyword-class counting, plus shell `elif`/`until`; whole-line and
  trailing-comment stripping) and measured every function in both changed
  shell files: `cmd_up:CC=5`, `term_tree:CC=2`, 55/55 functions ≤6, worst
  `call_api:CC=6` / `check_callable:CC=6` in `typed-judgment.sh`. The
  before-values (12, 8) describe a draft state that no longer exists — not
  re-measurable, and not required: the gate is the after-state. Basis
  spot-check verdict: **sound** — the heuristic is a faithful shell adaptation
  of the script's own counting rule (my simpler string handling slightly
  OVER-counts, e.g. keywords inside `echo` strings, and the ≤6 verdict still
  holds, so the claim is conservative-safe).
- **"136/136 green"** — CONFIRMED (per-file runs above; all also `ok` inside
  the full-suite run).
- **"Property tests skipped per mvp tier"** — CONFIRMED as correct procedure:
  gate JSON reports `"tier": "mvp"`; `docs/SPEC_PIPELINE.md §Conformance tiers`
  row "Refactorer — property tests: skip at mvp". The property-tests gate ran
  (listed in `gates`) and produced no finding.

---

## Adjudication of the 5 pre-existing local failures (issue #72 family + branch state)

`make test` totals: **290 ok / 5 not ok / 0 skipped of 295**. All 5 not-oks are
outside the 029 diff scope (029 modifies none of `ac-001-harness.bats`,
`agent-env.selftest.bats`, `check-pr-review.bats`, or the scripts they test).

**Ruling A — env-caused (4): test 5 `AC-001-05`, tests 31/32/33
`agent-env.selftest` ×3. OUT OF SCOPE for 029.**
Root cause verified by direct execution, not trusted: `bash
scripts/check-no-hardcoded-secrets.sh` → exit 1 with exactly 5 violations, all
in `config/agent.local.env` lines 9/14/18 (`GITHUB_TOKEN`, `GH_TOKEN`,
`BAILIAN_TOKEN_PLAN_API_KEY` — real machine credentials in the gitignored
per-machine file; `git check-ignore config/agent.local.env` → ignored;
`git ls-files config/` → only the two `.example` templates tracked).
`bash scripts/agent-env.selftest.sh` → 20 passed / 1 failed, the failing case
being "real scanned dirs are clean" citing the same file. Control: a detached
worktree of HEAD (gitignored files absent by construction) passes
**AC-001-05 and all 3 agent-env.selftest tests** (Evidence: full test suite,
control run). Identical ruling and root cause as spec 028 Adjudication B; the
third agent-env test (`gitignore checks take the ignored path…`) is new since
028's verification (added in 028 phase-2) and fails from the same single case.
Cannot occur in CI (the file is never committed). Per Stop-and-Ask: recorded,
not fixed; follow-up = the open issue #72 family proposal from 028 (W3 there:
scanner echoes secret values verbatim and scans gitignored local files).

**Ruling B — branch-state-caused (1): test 97 `check-pr-review: clean repo`.
OUT OF SCOPE for 029.**
Root cause verified: `bash scripts/check-pr-review.sh .` → exit 1 with a single
FAIL — `AC-024-01-12: change set modifies agents/spec-*.md: agents/spec-ux.md`.
The check computes its change set as `git diff --name-only origin/main HEAD`
(script line 342) — i.e. the COMMITTED branch delta, which for
`spec/028-typed-judgment-layer` includes 028's own authorized `agents/spec-ux.md`
amendment (confirmed: `git diff --name-only origin/main HEAD -- 'agents/spec-*'`
→ `agents/spec-ux.md`, PR #73 under human review). Control: the test fails
IDENTICALLY in the clean-HEAD worktree (Evidence: full test suite, control run
— not ok 10 there), proving it is not caused by 029's uncommitted work, which
touches zero files under `agents/`. The AC-024-01-12 guard is a
review-prompting gate ("Fix before merging") firing as designed on a stacked
branch; disposition belongs to PR #73's human review, not to spec 029.

**Suite arithmetic note (no finding):** 295 total = 225 at HEAD (028 branch
including its phase-2 commits, +9 tests since 028's verification run at 216) +
70 new from 029. The +9 live in files untouched by the 029 diff and all pass.

**Gate-2 ruling:** transcribed FAIL (exit 2 — the suite is not green on this
machine), ruled **out-of-scope** per Rulings A+B; **non-blocking for the 029
verdict**, exactly as 028's attempt-2 PASS carried its out-of-scope gate-2 FAIL.

---

## Spike report internal consistency (OQ-029-01 made the Coder the spike runner)

Verified against `35-spike-report.md` (read in full):

- **Bar declared** — §"Operational bar applied" states 5 explicit criteria AND a
  deviation note: the numeric bar lives in `00-informal.md §Task 0`, which the
  Coder is information-barred from and which `10-tasks.md`/`20-acceptance/` did
  not restate; the declared bar is derived from the formalized ACs, and the
  report instructs the Verifier/Architect how to re-adjudicate from the measured
  tables if the informal numbers differ. This is the correct information-barrier
  behavior — the Coder declared the assumption instead of guessing silently.
  Every bar criterion has a recorded measurement, so re-deciding is a reading
  task. (I have not read `00-informal.md` — barred; the Architect/human should
  confirm the informal §Task 0 numbers against the declared bar.)
- **Measurements recorded** — all 8 AC-029-01 fields present for the winner
  (VRAM incl. peak + sampling rate, p50 over 48 calls ≥ 20 required with
  cold/warm split, accuracy 12+12 fixtures ≥ 10+10 required, confidence
  distribution correct-vs-wrong, process count, startup warm+cold, download
  size). Fixture provenance disclosed (Coder-authored, stored outside the repo;
  100 % accuracy explicitly labeled an optimistic ceiling against the
  vendor-published 0.817/0.838 — honest).
- **Winner/runner-up** — exactly one each, both with rationale; winner is the
  first candidate in evaluation order meeting the bar (AC-029-02); all 4 later
  candidates carry one-line skip reasons (AC-029-06); runner-up named on
  published evidence with its costs and the condition under which it would have
  won — consistent with stop-at-first-winner procedure.
- **Threshold** — method stated (5th percentile, linear interpolation, floored
  to 2 decimals), p5 = 0.2831 → **0.28**, in (0,1); wrong-answer distribution
  empty (n=0) and explicitly flagged as no-separation-evidence with a
  tighten-in-production instruction (AC-029-03 ✓).
- **Serving recipe** — command, port 8009, model id, health path `/v1/models`,
  API path `/v1/systemone`, default alias `kev-latest` (matches
  `DEFAULT_LOCAL_MODEL` in `typed-judgment.sh:86` with its citing comment),
  process count 1 with the OS-tree nuance and tree-kill note (AC-029-04 ✓).
- **Wire-compat deltas + follow-up proposals** — zero-changes-beyond-switch
  statement verified against live capture with timestamp; 3 fidelity deltas
  ENUMERATED not absorbed (`choice` vs `answer` → normalized `answer:null` with
  a follow-up alias proposal explicitly scoped OUT because it would touch the
  byte-frozen hosted path; top-level `usage`/`latency_ms` → documented 028
  contract fallbacks; string-`criteria` consumer payloads → HTTP 422 → exit-10
  safe fallback with a follow-up map-criteria proposal, correctly NOT changed
  here because AC-029-74 forbids touching consumers) (AC-029-05 ✓).
- **E2E addendum** — E2E-RAN; both question shapes through the real wrapper in
  local mode (no key, no model env); spec-028 telemetry format with every field
  (judgment, question_shape, backend, answer, confidence, latency_ms, usage,
  exit, timestamp); raw-server view recorded alongside the normalized view;
  LLM-fallback comparison recorded (agreement) and explicitly labeled advisory;
  fallback-path probe (422 → 3 attempts → exit 10) measured; cap untouched via
  scratch `JUDGMENT_CAP_DIR` (AC-029-70/71/73 ✓).
- **One minor arithmetic inconsistency (W3, non-blocking):** the threshold
  rationale says "At the old 0.6 the local backend would have discarded **7 of
  24** correct answers (**29 %**)", but the report's own bucket table
  ([0.2,0.4): 3, [0.4,0.6): 5) puts **8 of 24** (33 %) below 0.6. Off-by-one in
  the illustrative prose; ADR 0005 repeats the "29 %" figure. It does NOT
  affect the recommended value (0.28 derives from p5 = 0.2831, independent of
  that sentence), the "23 of 24 stay usable at 0.28" claim (consistent with min
  0.225 being the sole sub-0.28 answer), or any AC. Flagged to the Architect
  for a one-word correction when the ADR/report next changes; proposed
  disposition: fix in the archive one-pager at stage 5b or a follow-up docs
  commit.

**Spike-report consistency verdict: PASS** with note W3.

### Key results tables copied here per OQ-029-02 (evidence survives archiving)

| Metric (winner Kev-4B) | Value |
|---|---|
| VRAM | 15.6–15.8 GiB used of 16311 MiB (peak 15861 MiB sampled at 4 Hz over the 48-call loop) |
| p50 latency | 117 ms client-measured over 48 calls (24 cold + 24 warm); server cold p50 286 ms, warm ~105 ms, first call 761 ms |
| accuracy | 24/24 Coder-authored fixtures (12 ci-triage-style + 12 spec-ux-style); vendor-published new-source 0.817/0.838 = realistic planning figure |
| confidence distribution | correct (n=24): min 0.225, p5 0.283, p10 0.335, median 0.694, max 0.940; buckets [0.2,0.4):3 [0.4,0.6):5 [0.6,0.8):12 [0.8,1.0]:4; wrong: n=0 |
| threshold | JUDGMENT_MIN_CONFIDENCE=0.28 (5th percentile of correct-answer confidence, linear interpolation, floored to 2 decimals) |
| startup | 11.2 s warm; cold first run ≈ 50–55 min (anonymous HF rate limit; HF_TOKEN fixes) |
| download | ≈ 8.95 GiB model files (HF cache) + 6.9 GB uv venv; nothing in the repo tree |
| processes | 1 logical (OS tree 2: uv launcher + python child; single kev.pid, tree-kill) |
| recipe | `uv run --extra serve python -m kev.serve --run jaredpalmer/kev-4b --port 8009`; health GET `/v1/models`; API POST `/v1/systemone`; default alias `kev-latest` |

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh
exit: 0
at: 2026-10-09T18:31:33Z

```
Scenario IDs found: 55 live, 226 archived

PASS AC-029-01 — traced to a test
PASS AC-029-02 — traced to a test
… (AC-029-03 through AC-029-73: PASS, one line each — 52 lines)
PASS AC-029-74 — traced to a test

✔ Scenario traceability check: every scenario traced, every reference resolves.
```

(Excerpt: all 55 AC-029-* lines were PASS; zero FAIL lines; ANSI coloring
stripped. Run window 18:31:33Z → 18:31:34Z.)

JSON transcript:

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-09T18:33:41Z

```json
{
  "checks": [1, 2],
  "passes": ["AC-029-01 — traced to a test", "… 54 more …"],
  "fails": []
}
```

## Evidence: full test suite

command: make test
exit: 2
at: 2026-10-09T18:31:59Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 42 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..295
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
…
not ok 5 AC-001-05: No secrets in harness or fixtures
# (in test file scripts/tests/ac-001-harness.bats, line 53)
#   `[ "$status" -eq 0 ]' failed
…
not ok 31 agent-env.selftest: exits 0 and reports every case passing
# (in test file scripts/tests/agent-env.selftest.bats, line 14)
#   `[ "$status" -eq 0 ]' failed
not ok 32 agent-env.selftest: reports a non-zero assertion count and zero failures
# (in test file scripts/tests/agent-env.selftest.bats, line 20)
#   `[ "$status" -eq 0 ]' failed
not ok 33 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
# (in test file scripts/tests/agent-env.selftest.bats, line 36)
#   `[ "$status" -eq 0 ]' failed
…
not ok 97 check-pr-review: clean repo exits 0 and prints its documented clean line
# (in test file scripts/tests/check-pr-review.bats, line 17)
#   `[ "$status" -eq 0 ]' failed
…
ok 293 unit: local backend without JUDGMENT_MODEL sends the backend default alias
ok 294 unit: local backend honors an explicit JUDGMENT_MODEL override
ok 295 unit: dry-run in local mode prints the default alias without a live call
make: *** [Makefile:115: test-scripts] Error 1
```

(Excerpt of run window 18:31:59Z → 18:33:29Z; ANSI stripped. Totals: **290 ok /
5 not ok / 0 skipped of 295** — `grep -c "^ok "` → 290, `grep -c "^not ok"` → 5,
`grep -c "# skip"` → 0. All 5 not-oks adjudicated out-of-scope in Rulings A/B
above; every AC-029-* test and every unit test in the three judgment files
reports ok.)

Spec-029-scope per-file runs (independent confirmation of Coder/Refactorer counts):

command: bats --tap scripts/tests/typed-judgment.bats | tail -3; bats --tap scripts/tests/typed-judgment-integration.bats | tail -3; bats --tap scripts/tests/judgment-local-up.bats | tail -3
exit: 0 (each file)
at: 2026-10-09T18:36:10Z

```
ok 42 unit: local backend without JUDGMENT_MODEL sends the backend default alias
ok 43 unit: local backend honors an explicit JUDGMENT_MODEL override
ok 44 unit: dry-run in local mode prints the default alias without a live call
EXIT:0
ok 76 unit: typed-judgment.bats names the backend-switch scenarios
ok 77 AC-029-46: content-contract tests verify the config presence (backend switch, local URL, threshold comment)
ok 78 AC-029-58: content-contract verifies ADR 0005 exists with the four required sections
EXIT:0
ok 12 AC-029-38: Makefile targets judgment-up and judgment-down invoke the script
ok 13 unit: unknown subcommand is a usage error
ok 14 unit: up kills its own process and fails cleanly when health never answers
EXIT:0
```

Root-cause runs for Ruling A (credential values redacted in this report — the
scanner prints them verbatim; redaction note carried as 028's W3 follow-up):

command: bash scripts/check-no-hardcoded-secrets.sh
exit: 1
at: 2026-10-09T18:37:42Z

```
config/agent.local.env:9: literal token prefix
  config/agent.local.env:14: literal token prefix
  config/agent.local.env:9: secret-style assignment: GITHUB_TOKEN=ghp_[REDACTED]
  config/agent.local.env:14: secret-style assignment: GH_TOKEN=ghp_[REDACTED]
  config/agent.local.env:18: secret-style assignment: BAILIAN_TOKEN_PLAN_API_KEY=sk-[REDACTED]

✘ check-no-hardcoded-secrets: 5 violation(s) in agents, commands, scripts, docs, .github, config, templates, ci.
```

command: bash scripts/agent-env.selftest.sh (tail)
exit: 1
at: 2026-10-09T18:37:42Z

```
FAIL real scanned dirs (agents/ commands/ scripts/ docs/) are clean (rc=1, out=  config/agent.local.env:9: literal token prefix … 5 violation(s) …)

selftest: 20 passed, 1 failed
✘ agent-env.selftest: 1 case(s) failed.
```

Root-cause run for Ruling B (single FAIL of 90+ assertions):

command: bash scripts/check-pr-review.sh .
exit: 1
at: 2026-10-09T18:37:20Z

```
…
PASS AC-024-01-12: exactly the 8 spec-pipeline agents exist under agents/, none added
FAIL AC-024-01-12: change set modifies agents/spec-*.md: agents/spec-ux.md
…
✘ PR review agent check: 1 violation(s). Fix before merging.
```

(command substitution verified at `scripts/check-pr-review.sh:342`:
`git diff --name-only origin/main HEAD`; and `git diff --name-only origin/main
HEAD -- 'agents/spec-*'` → `agents/spec-ux.md` — 028's committed, PR-#73-scoped
change; `git diff HEAD --name-only -- agents/` → EMPTY, i.e. 029 contributes
nothing to it.)

Clean-HEAD control runs (pre-existing-claim proof; detached worktree of HEAD at
/tmp/opencode/verif029/clean-head, removed after the runs — gitignored files,
including config/agent.local.env, absent by construction; branch state
origin/main..HEAD present by construction):

command: bats --tap /tmp/opencode/verif029/clean-head/scripts/tests/ac-001-harness.bats /tmp/opencode/verif029/clean-head/scripts/tests/agent-env.selftest.bats /tmp/opencode/verif029/clean-head/scripts/tests/check-pr-review.bats
exit: 1
at: 2026-10-09T18:53:59Z

```
1..11
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
ok 6 AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)
ok 7 agent-env.selftest: exits 0 and reports every case passing
ok 8 agent-env.selftest: reports a non-zero assertion count and zero failures
ok 9 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
not ok 10 check-pr-review: clean repo exits 0 and prints its documented clean line
# (in test file /tmp/opencode/verif029/clean-head/scripts/tests/check-pr-review.bats, line 17)
#   `[ "$status" -eq 0 ]' failed
ok 11 check-pr-review: empty tree exits 1 and names the missing artifact
```

The control splits the 5 failures exactly as ruled: the 4 env-caused tests PASS
without the local credentials file (→ Ruling A: env-caused, CI-immune); the
check-pr-review test still FAILS on clean HEAD (→ Ruling B: committed
branch-state, not 029's uncommitted work, not the local env).

## Evidence: complexity gate

This repo's shell complexity gate is cyclomatic complexity ≤6
(`docs/SPEC_PIPELINE.md §Tooling` semantics); there is no shell CC linter in the
repo, so the Refactorer re-implemented `check-code-principles.sh`'s `tokens()`
heuristic for shell. I reproduced that heuristic INDEPENDENTLY (scratch python:
base CC 1 per `name() {…}` function; +1 per word-boundary `if|elif|for|while|
until|case|switch|catch`, `&&`, `||`, `?`; comment lines stripped; brace-depth
function bodies) and measured every function in both changed shell files.

command: python3 /tmp/opencode/verif029/shell_cc.py scripts/judgment-local-up.sh scripts/typed-judgment.sh
exit: 0
at: 2026-10-09T18:44:30Z

```
scripts/judgment-local-up.sh:86:term_tree:CC=2
scripts/judgment-local-up.sh:100:read_pid:CC=5
scripts/judgment-local-up.sh:124:ensure_recipe_installed:CC=5
scripts/judgment-local-up.sh:198:cmd_up:CC=5
scripts/judgment-local-up.sh:164:start_process:CC=4
scripts/judgment-local-up.sh:218:cmd_down:CC=4
scripts/judgment-local-up.sh:236:cmd_status:CC=4
scripts/typed-judgment.sh:227:call_api:CC=6
scripts/typed-judgment.sh:278:check_callable:CC=6
… (55 functions measured across both files; full listing retained in run notes)
functions with CC > 6: 0
```

(Excerpt — the 9 highest-CC functions plus the two Refactorer-claimed values,
which reproduce EXACTLY: `cmd_up:CC=5`, `term_tree:CC=2`. Worst measured CC = 6
≤ 6. Measurement caveat recorded honestly: my repro does not strip string
literals, so it slightly over-counts lines echoing keyword-like prose —
conservative direction; the ≤6 verdict cannot flip from under-counting.)

command: shellcheck scripts/typed-judgment.sh scripts/judgment-local-up.sh
exit: 1
at: 2026-10-09T18:40:12Z

```
In scripts/judgment-local-up.sh line 72:
  [ -n "$kids" ] && kill -"$sig" $kids 2>/dev/null
                                 ^---^ SC2086 (info): Double quote to prevent globbing and word splitting.

In scripts/judgment-local-up.sh line 152:
  local -a p=($JUDGMENT_LOCAL_PROCESSES)
              ^-----------------------^ SC2206 (warning): Quote to prevent word splitting/globbing, or split robustly with mapfile or read -a.
```

(shellcheck 0.10.0, provisioned as a static binary into /tmp/opencode/bin for
this run — not installed locally, same as the 028 verification — and removed at
end of run. `scripts/typed-judgment.sh`: zero findings. Ruling: the 2 findings
are the repo's advisory class — CI's shellcheck step carries
`continue-on-error: true` (self-ci.yml:217-220) — and both are DELIBERATE
word-splitting idioms, verified in context: line 72 `kill -"$sig" $kids` MUST
split (`$kids` is a space-separated child-PID list; quoting would break
tree-kill), line 152 intentionally splits the recipe's process-name list into an
array. No correctness bug, no glob-expansion exposure (both values are
machine-internal: PIDs and a fixed recipe token). Recorded as WARN note W2 with
a hygiene follow-up proposal — not a gate FAIL; the ≤6 CC gate (the blocking
complexity contract) passes under independent measurement.)

Repo-wide advisory census (context only, not attributed to 029):

command: shellcheck scripts/*.sh templates/*.sh
exit: 1
at: 2026-10-09T18:40:14Z

```
161 findings (SC2086 info ×39, SC2016 info ×38, SC2034 warning ×23, SC2317 info ×18, SC1091 info ×9, …) — same pre-existing backlog class recorded since spec 001; 029's two files contribute only the 2 findings above.
```

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef HEAD --json
exit: 0
at: 2026-10-09T18:38:16Z

```json
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

(Change-scoped — the blame-scoping mode self-ci uses and the same mode 028's
verification used: the gate judges the author's change; the 029 diff introduces
zero findings. Tier `mvp` confirms the Refactorer's property-test skip is the
correct tier behavior, per `docs/SPEC_PIPELINE.md §Conformance tiers`.)

Full-tree run, transcribed for completeness:

command: scripts/check-code-principles.sh --json
exit: 0
at: 2026-10-09T18:39:47Z

```
fails: 0
warns: 14
W Method body >20 lines (go): ./ci/templates/go-saga-lint.go:45:71:main:KISS_LINES=28
W Method body >20 lines (go): ./ci/templates/go-saga-lint.go:101:124:checkCompensationPairs:KISS_LINES=25
W Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): …
W Possible duplication (3x … saga-compensation.js:132), (2x … :133, :135, :242, :243)
W Possible duplication (2x … ./ci/templates/archunit/OutboxArchRules.java:122, :4)
W Possible duplication (2x … ./ci/templates/go-saga-lint.go:182, :105)
W Empty method body (java): ./ci/templates/archunit/OutboxArchRules.java:30
W Empty method body (java): ./ci/templates/archunit/SagaArchRules.java:33
```

(WARN lines condensed from the 14-entry JSON array — full JSON retained in run
notes; exit 0 = WARNs are review hints, not findings. ALL 14 sit in
`ci/templates/*` — files 029 does not touch (`git diff HEAD --stat` has no
`ci/` entry). Note vs 028's record: the 5 ci/templates FAILs logged at 028
verification are gone at HEAD — the script is the authority and now exits 0
full-tree; the WARN backlog persists. Flagged to the Architect as pre-existing,
follow-up-spec material, per the WARN-not-FAIL matrix row.)

## Evidence: scenario-to-behavior spot check

Seeded draw (reproducible): all 55 `## AC-029-*` IDs from `20-acceptance/`,
sorted, drawn with a fixed seed of 29:

command: shuf -n 3 --random-source=<(yes 29) /tmp/opencode/verif029/all-acs.txt
exit: 0
at: 2026-10-09T18:57:21Z

```
AC-029-70
AC-029-05
AC-029-04
```

command: grep -rn "AC-029-70\|AC-029-05:\|AC-029-04:" scripts/tests/*.bats | grep "@test"
exit: 0
at: 2026-10-09T18:57:21Z

```
scripts/tests/typed-judgment-integration.bats:346:@test "AC-029-04: spike records the serving recipe (command, port, model id, process count)" {
scripts/tests/typed-judgment-integration.bats:355:@test "AC-029-05: spike records the wire-compatibility result" {
scripts/tests/typed-judgment-integration.bats:524:@test "AC-029-70: E2E addendum records answers per question shape (or a documented skip)" {
```

Manual assertion-vs-scenario comparison (tests read in full, report content
cross-read; all three pass in the suite — ok 214, ok 215, ok 236 in the TAP):

- **AC-029-04** (Then: report records exact serving command, port, model
  identifier, process count): test greps `^## Serving recipe`,
  `python -m kev\.serve`, `--port 8009`, `jaredpalmer/kev-4b`,
  `Process count: 1`. The report's §Serving recipe carries each value (command
  line, port 8009, model id + weights revision, process count with the OS-tree
  nuance). Assertions are concrete-valued and discriminating (deleting any
  recipe element fails the test). **GENUINE.** Minor nuance: "exact serving
  command" is asserted via its distinctive fragment (`python -m kev.serve` +
  `--port 8009`) rather than the full line — acceptable; the parameterization
  consumers (`judgment-local-up.sh` defaults) were separately cross-checked
  against the report and match.
- **AC-029-05** (Then: report states whether the wrapper parses with zero
  changes beyond the switch; lists changes if any): test greps
  `^## Wire compatibility`, `typed-judgment\.sh`, `zero changes beyond the Task
  2 backend switch`. The report states exactly that (measured against the live
  server, timestamped capture), and additionally ENUMERATES 3 fidelity deltas +
  2 follow-up proposals — the Then's list-changes branch is satisfied in
  substance by the delta enumeration (verified by reading, since the applicable
  branch is "zero changes required"). **GENUINE.**
- **AC-029-70** (Then: ≥1 ci-triage-style AND ≥1 spec-ux-style question through
  the wrapper; addendum records answer, confidence, latency_ms, usage per
  question): test asserts `^## E2E addendum`, then branches on the recorded
  outcome — under `E2E-RAN` it requires all six telemetry field names
  (`question shape`, `backend`, `answer`, `confidence`, `latency_ms`, `usage`);
  under a skip it requires `E2E-SKIP` (mirroring AC-029-72). The addendum is
  `E2E-RAN` with two spec-028-format JSON telemetry lines — one
  `"question_shape":"ci-triage"`, one `"question_shape":"spec-ux"` — carrying
  every required field, plus the raw-server view and the fallback probe.
  **GENUINE**, with note W4: the test does not mechanically count ≥1 line per
  question shape (it asserts the field names, not the shape values); I verified
  both shape lines by direct read. Not a false green — every assertion present
  matches the Then — but the per-shape count clause rests on read-verification
  rather than the test. Cheap hardening candidate: add
  `grep -c '"question_shape":"ci-triage"'`/`spec-ux` assertions in a follow-up.

**Spot-check verdict: PASS** (3/3 genuine; 1 hardening note).

---

## Finding: no unaccounted behavior (check 5 — finding line, not a command)

Full 029 diff skimmed (12 modified files, 685 insertions / 14 deletions, + 4
untracked 029 artifacts). Every hunk traces: `scripts/typed-judgment.sh` (+59/−10:
header docs, `DEFAULT_LOCAL_MODEL` constant w/ spike citation, `resolve_backend`,
`resolve_model`, per-backend `configured_credentials`, conditional auth-array in
`api_attempt`, hosted-only model requirement in `check_callable`, `resolve_backend`
call in `main`) → Task 2 ACs + OQ-029-03, hosted path byte-preserved (028's 66
tests green unmodified prove it); `scripts/judgment-local-up.sh` (new, 277 lines)
→ Task 3 ACs + OQ-029-04 (its `ensure_recipe_installed` bootstrap traces to
Task 3's "up starts the winning recipe's process (command and arguments from
spike report)" + the spike §Install steps; guarded to the default recipe,
idempotent); `Makefile` judgment-up/down + .PHONY → AC-029-38; `.gitignore`
`.cache/judgment/` + comment expansion (the −1/+1 on the 028 comment line is a
re-wrap preserving its content — NOT the 028-attempt-1-style corruption) →
AC-029-37; `config/*.example` → Task 4 ACs (hosted lines preserved: 0.6
threshold + hosted URL/model/cap intact); `docs/adr/0005*` + `docs/adr/README.md`
(0004 row re-emitted only for EOF-newline when appending 0005 — cosmetic) →
Task 5; `docs/SPEC_PIPELINE.md` +12, `docs/LOOP_ENGINEERING.md` +4/−1,
`okf/when-to-use-typesafe.md` +29 (`## Local backends`), `okf/log.md` +7 →
Task 6 (provider-name scoping independently re-verified: recursive grep for
`Kev|CLM|jaredpalmer|Contrastive-LM` over `agents/ skills/ docs/` → only
`docs/adr/0005-local-judgment-backend.md`, and within it only the §Spike
evidence section → AC-029-57/-64 hold); the 3 bats files → the tests themselves
(pure append in the 2 modified files); `specs/029-*` → pipeline artifacts incl.
35-spike-report.md. Independent gate re-runs: `scripts/check-orchestration.sh`
exit 0 (AC-029-65). **No unaccounted behavior found.**

---

## Notes / warnings for the Architect (WARN — recorded, not blocking)

- **W1 — gate 2 out-of-scope FAIL stands** (Rulings A/B): 4 env-caused failures
  (machine-local gitignored `config/agent.local.env` with real credentials;
  clean-HEAD control passes; CI cannot see them) + 1 branch-state failure
  (`check-pr-review` guard firing on 028's committed `agents/spec-ux.md` in
  `origin/main..HEAD` — disposition belongs to PR #73's review). Follow-ups:
  the open issue #72 family (scanner hygiene: it echoes secret values verbatim
  and scans gitignored local files — 028's W3, still open); the AC-024-01-12
  guard's behavior on stacked spec branches may deserve a spec of its own.
- **W2 — shellcheck advisory findings on `scripts/judgment-local-up.sh`**
  (SC2206 warning L152, SC2086 info L72): deliberate word-splitting idioms, no
  correctness impact, CI step advisory. Hygiene follow-up: add
  `# shellcheck disable=SC2086,SC2206` directives with a one-line rationale, or
  `mapfile`/`read -a` for L152.
- **W3 — spike report (and ADR 0005) arithmetic slip:** "at 0.6 discarded 7 of
  24 (29 %)" vs the report's own buckets showing 8 of 24 below 0.6 (33 %).
  Does not affect the 0.28 derivation or any AC. One-word fix at next touch
  (or in the stage-5b archive one-pager).
- **W4 — AC-029-70 test hardening candidate:** per-question-shape counts
  verified by read, not asserted mechanically (see spot check).
- **W5 — design-principles full-tree WARN backlog:** 14 WARNs, all in
  `ci/templates/*`, pre-existing, untouched by 029 (028 recorded 17 + 5 FAILs
  at its verification; the FAILs since fixed at HEAD — script now exits 0
  full-tree). Follow-up-spec material per the WARN matrix row.
- **W6 — spike bar provenance:** the numeric bar lives in the informal spec,
  which Coder and Verifier are barred from; the Coder correctly declared an
  operational bar derived from the formalized ACs and recorded re-adjudication
  instructions. **The Architect/human should confirm the informal §Task 0
  numbers against the declared bar** — the report makes this a reading task
  (all measurements recorded); if the informal bar differed (e.g. sub-100 ms
  p50), the runner-up analysis in §Winner and runner-up already names the
  alternate winner.
- Scratch artifacts (/tmp/opencode/verif029, /tmp/opencode/bin shellcheck
  binary, clean-head worktree) removed at end of run; no repo file touched
  except this report. Nothing committed or pushed.

---

Verdict: **PASS** (attempt 1, phase 1). Gate 2 transcribed FAIL with the
out-of-scope ruling above, carried in telemetry warnings per the 028 precedent.
