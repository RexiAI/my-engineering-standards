# Verification — Voice console (spec 044)

Verifier: independent re-execution of stages 2–3. Every claim below was re-run
against the live tree; no Coder or Refactorer self-report was taken on faith.
`specs/044-voice-console/00-informal.md` was **not** read (information barrier).

- Pipeline mode: `full` (`specs/044-voice-console/45-decisions.md`)
- Conformance tier: `mvp` (`Checking design principles in: . (tier: mvp)`)
- Stage: 4, Verifier. Attempt: **1**, phase **1** (first full run, not a re-verification)
- Branch: `main` (stage 5b has not committed yet; tree is dirty by construction)
- Tree state during the run: unchanged. `git status --porcelain` before and after is
  identical — 3 modified tracked files (`Makefile`, `docs/GOVERNANCE.md`,
  `docs/adr/README.md`) and the spec-044 new files
  (`agents-optional/voice-concierge.md`, `docs/VOICE_CONSOLE.md`,
  `docs/adr/0026-voice-console.md`, `scripts/tests/voice-*`, `scripts/voice/`,
  `specs/`). Every dirty path belongs to spec 044; nothing unrelated, nothing
  stashed, nothing committed.
- `specs/` contains only `044-voice-console/` (no stale folders to contaminate
  the run).

## Verdict

**PASS** — every runnable gate ran and exited 0; no FAIL findings.

| # | Gate ID | Check | Exit | Result |
|---|---|---|---|---|
| 1 | `traceability` | scenario traceability | 0 | 16 live IDs, 1..N all traced; 133/133 sub-scenarios present in the bats file |
| 2 | `test-suite` | full suite (`make test-scripts`, `BATS_JOBS=8`) | 0 | 1195 `ok`, 0 `not ok`, 0 `skip`, 1300 log lines |
| 3 | `complexity` | `node --check` on every new `.mjs` (+ design-principles lane) | 0 | 17/17 files parse; no ESLint/`package.json` exists in this repo |
| 3.5 | `design-principles` | `scripts/check-code-principles.sh` | 0 | **0 FAIL / 67 WARN** |
| 4 | `spot-check` | 3 scenarios from 3 files read against their `@test` | 0 | all three assert the scenario; two notes below |
| 5 | `unaccounted` | diff skim (finding lines, not a command) | — | 4 flagged items for the Architect, listed below |

PASS is transcribed from exit codes only. It does **not** certify the flagged
items in §Flagged to the Architect; that section is check 5's output and is the
Architect's to triage. The design-principles WARNs are review hints, not a stop
(`docs/SPEC_PIPELINE.md §Stop-and-Ask decision matrix`: design-gate WARN → record
and flag).

## Flagged to the Architect (check 5 output — finding lines, not gate findings)

1. **[HIGH — unaccounted behavior]** `scripts/voice/converse.mjs:11,80` —
   `const REPLY_TIMEOUT_MS = 1500;` and
   `withTimeout(state.collector.nextTurn(), REPLY_TIMEOUT_MS, [])`. No task and no
   scenario specifies a reply deadline; the 1.5 s bound is local invention. When
   a real assistant turn takes longer than 1.5 s to emit `idle`/text, the turn
   silently speaks nothing and writes no `spoken`/`deferred`/`skipped` record —
   an operator hears dead air with no ledger trace. `AC-044-11-01`/`-04` cannot
   catch it: `scripts/tests/voice-fake-server.mjs` answers instantly. Not fixed
   here (Verifier writes no production code); either the spec gains a latency
   scenario or the bound becomes configurable and recorded.
2. **[MEDIUM — spec-mandated but vacuous]** `scripts/voice/control.mjs:55,60,65` —
   each outbound reply is preceded by
   `authorize({ tool: "read", command: null, paths: [], repoRoot: process.cwd() })`.
   A `read` intent can never be blocked (`policy.mjs:241-244` returns
   `blocked:false` for `READ_TOOLS`), so these three calls enforce nothing. They
   exist to satisfy `AC-044-03-03` literally ("every call … immediately preceded
   by a `guard.authorize` call"). The real policy decision is
   `authorize(event.intent)` at `control.mjs:157`. The scenario verifies shape,
   not effect; a future edit could delete the effective call at line 157 and keep
   the test green.
3. **[LOW — spec gap]** `scripts/voice/tts-worker.py:87-95` — `run_engine` reports
   `missing-runtime` for `--engine pocket-tts` unconditionally; `available("pocket_tts")`
   is only consulted by `--self-check`. No scenario covers the engine being
   present (`AC-044-04-07` covers absent only), so nothing is violated, but the
   worker can never synthesize with Pocket TTS even when installed. Follow-up
   spec if that engine is expected to work.
4. **[TRIVIAL — dead code]** `scripts/voice/install.mjs:6` imports `basename` and
   never uses it. YAGNI/DRY hint only.

One accepted divergence, recorded so it is not re-discovered: `config.mjs:224`
defaults `artifacts` to `.cache/voice/runs/default`, while decision D9 writes
`.cache/voice/runs/<runId>`. No run id is generated anywhere, so the literal
`default` *is* the run id; every acceptance scenario passes an explicit
`--artifacts`, so the default is untested but harmless today.

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-08T13:42:38Z

```json
{
  "checks": [1, 2],
  "passes": ["AC-044-01 — traced to a test", "AC-044-02 — traced to a test", "AC-044-03 — traced to a test", "AC-044-04 — traced to a test", "AC-044-05 — traced to a test", "AC-044-06 — traced to a test", "AC-044-07 — traced to a test", "AC-044-08 — traced to a test", "AC-044-09 — traced to a test", "AC-044-10 — traced to a test", "AC-044-11 — traced to a test", "AC-044-12 — traced to a test", "AC-044-13 — traced to a test", "AC-044-14 — traced to a test", "AC-044-15 — traced to a test", "AC-044-16 — traced to a test"],
  "fails": []
}
```

Plain-mode cross-check (same script, no `--json`, exit 0):

```
Scenario IDs found: 16 live, 634 archived

PASS AC-044-01 — traced to a test
... (one PASS line per task file, AC-044-01 .. AC-044-16) ...
✔ Scenario traceability check: every scenario traced, every reference resolves.
```

Deeper sub-scenario trace (not a gate input; the gate's heading granularity is
`AC-NNN-NN`): 133 `## AC-044-NN-MM` headings across the 16 acceptance files, and
133 distinct `AC-044-NN-MM` ids referenced in `scripts/tests/voice-console.bats`.
`comm -23`/`comm -13` over the two sorted lists are both empty — every
sub-scenario has a test and no test cites a nonexistent id.

## Evidence: full test suite

command: scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/044-verifier-suite.log -- env BATS_JOBS=8 make test-scripts
exit: 0
at: 2026-11-08T13:42:36Z
Test-run hash: 353be28a4e8f3ce27f4b93b0f4e27de800f62d47e64df98daad7460186e22f75

```
SUMMARY: mode=run exit=0 signal=0 log_lines=1300 log=/tmp/opencode/pipeline/044-verifier-suite.log
```

`signal=0`: the wrapper printed no failure/error lines. Independent counts over
the full log (TAP, after `check-bats-assertions` passed on 104 bats files):

```
$ grep -cE '^ok ' /tmp/opencode/pipeline/044-verifier-suite.log
1195
$ grep -cE '^not ok' /tmp/opencode/pipeline/044-verifier-suite.log
0
$ grep -c '# skip' /tmp/opencode/pipeline/044-verifier-suite.log
0
$ grep -cE '^ok .*AC-044-' /tmp/opencode/pipeline/044-verifier-suite.log
133
```

No test was skipped (a skipped test is a failure). `scripts/tests/voice-console.bats`
carries 133 `@test` blocks and 133 pass. Run duration 2 m 31 s
(13:42:36Z → 13:45:07Z). No pre-run hash was captured, so the
`tree-changed-during-run` check has no pre-image to compare; `git status
--porcelain` is byte-identical before and after, which is the substitute evidence.

full log: §Raw log: full test suite

## Evidence: complexity gate

command: for f in scripts/voice/*.mjs scripts/tests/voice-fake-server.mjs scripts/tests/voice-fixtures.mjs; do node --check "$f" || exit 1; done
exit: 0
at: 2026-11-08T13:45:46Z

Honest scope note — this repo has **no language linter for `.mjs`**:
`package.json`, `.eslintrc*` and `eslint.config.*` do not exist, and
`scripts/check-code-principles.sh` discovers node files by
`-name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx'` (script line
442) — `.mjs` is **not** in the discovery set. No linter was invented; complexity
evidence for the new modules is `node --check` (below) plus the design-principles
run in the next block. `node v24.21.0`.

17 files checked, exit 0 for each:

```
node --check scripts/tests/voice-fake-server.mjs -> exit 0
node --check scripts/tests/voice-fixtures.mjs -> exit 0
node --check scripts/voice/asr.mjs -> exit 0
node --check scripts/voice/audio-in.mjs -> exit 0
node --check scripts/voice/audio-out.mjs -> exit 0
node --check scripts/voice/chunk.mjs -> exit 0
node --check scripts/voice/config.mjs -> exit 0
node --check scripts/voice/control.mjs -> exit 0
node --check scripts/voice/converse.mjs -> exit 0
node --check scripts/voice/guard.mjs -> exit 0
node --check scripts/voice/install.mjs -> exit 0
node --check scripts/voice/narrate.mjs -> exit 0
node --check scripts/voice/opencode-client.mjs -> exit 0
node --check scripts/voice/policy.mjs -> exit 0
node --check scripts/voice/smoke.mjs -> exit 0
node --check scripts/voice/timeout.mjs -> exit 0
node --check scripts/voice/voice-console.mjs -> exit 0
AGGREGATE_EXIT=0
```

`tts-worker.py` is Python and is likewise outside every complexity lane
(`check-code-principles.sh` scans `.py`, and its summary below counts it).

## Evidence: design-principles gate

command: scripts/check-code-principles.sh
exit: 0
at: 2026-11-08T13:43:03Z

```
Checking design principles in: . (tier: mvp)
...
---------------------------------------------
✔ Design-principles check: 0 FAIL(s), 67 WARN(s).
  WARNs are review hints — verify each before merging.
```

**FAIL lines: 0** (`grep -c '^FAIL'` → 0). Every WARN line cannot be pasted
without a 115-line wall, so the WARN inventory is complete and counted, with a
verbatim excerpt:

```
Complexity/KISS         3
DRY                    10
YAGNI                   2
Comments               41
Naming                 10
Null discipline         1
total                  67
```

WARNs in files this spec adds (verbatim):

```
WARN Naming: more than three parameters (synthesise_silent) (./scripts/voice/tts-worker.py:66)
WARN Naming: more than three parameters (run_engine) (./scripts/voice/tts-worker.py:87)
WARN Naming: more than three parameters (synthesise_silent) (./scripts/voice/tts-worker.py:90)
WARN Naming: more than three parameters (run_engine) (./scripts/voice/tts-worker.py:120)
WARN Naming: more than three parameters (handle_line) (./scripts/voice/tts-worker.py:154)
```

The other 62 WARNs are pre-existing (`ci/templates/`, `scripts/check-*.sh`,
`skills/hallmark/`, …), untouched by this spec. Representative pre-existing
excerpt:

```
WARN Possible duplication (3x identical 4-line block, first at ./ci/templates/eslint-saga-rules/saga-compensation.js:115): ...
WARN Comments: commented-out code (./scripts/check-code-principles.sh:58)
WARN Naming: boolean flag parameter (hasCompensation) (./ci/templates/archunit/SagaArchRules.java:147)
WARN Null-discipline: return null (./ci/templates/eslint-saga-rules/saga-compensation.js:65)
```

Clean lanes reported by the same run: `PASS Complexity/KISS (java)`, `PASS
Complexity/KISS (python)`, `PASS YAGNI (go/node/python)`, every `PASS SOLID-*`
lane, `PASS Component-per-file: no violations`. Property tests are
`skipped (project tier is mvp — production+ required)`, which matches the
declared `mvp` tier.

Reduced coverage, stated plainly: none of the new `.mjs` files was analysed by
this gate (extension set above). The 5 WARNs it *did* raise against this spec are
all in `scripts/voice/tts-worker.py`, which it does scan. Flagged to the
Architect; not a stop.

## Evidence: scenario-to-behavior spot check

command: grep -nE 'AC-044-(07-05|11-05|12-05)' specs/044-voice-console/20-acceptance/*.md scripts/tests/voice-console.bats
exit: 0
at: 2026-11-08T13:45:50Z

```
specs/044-voice-console/20-acceptance/AC-044-07-audio-in.md:26:## AC-044-07-05 — Device mode uses arecord
specs/044-voice-console/20-acceptance/AC-044-11-converse.md:30:## AC-044-11-05 — A missing session is created with the concierge agent
specs/044-voice-console/20-acceptance/AC-044-12-control.md:29:## AC-044-12-05 — Free-text questions send the transcript verbatim
scripts/tests/voice-console.bats:997:@test "AC-044-07-05: device mode spawns arecord and reuses the endpointing path" {
scripts/tests/voice-console.bats:1530:@test "AC-044-11-05: a missing session is created with the concierge agent" {
scripts/tests/voice-console.bats:1632:@test "AC-044-12-05: free-text questions send the transcript verbatim" {
```

Three scenarios picked at random, one per file
(`ls specs/044-voice-console/20-acceptance/*.md | shuf -n 3`, then one heading
per file), then each `@test` read line by line against its Given/When/Then.

**AC-044-11-05** (bats:1530-1547) — strong. Scenario: no `--session`, no
`--agent`; first prompt created with `voice-concierge`; first `prompt-sent`
`detail` carries the returned id. Test omits both flags (the `converse_run`
helper passes neither), asserts the first recorded request's `body.agent` equals
`voice-concierge`, and parses `ledger.jsonl` to require the first
`kind === "prompt-sent"` row's `detail === "ses_created"` — which is exactly the
id `voice-fake-server.mjs:101` returns from `POST /session`. A prompt sent before
session creation would leave `body.agent` unset and fail. Assertions match the
scenario.

**AC-044-12-05** (bats:1632-1640) — strong. Scenario: `question.asked` with no
options, transcript `stage four`, reply body carries it verbatim. Test writes
`options: []`, puts `stage four` in the input script, and asserts the first
recorded request's `body.text === "stage four"` (exact string, not a substring or
a count). Matches.

**AC-044-07-05** (bats:997-1026) — passes, two weak spots worth naming. The test
puts a fake `arecord` on `PATH` that saves its argv and cats raw PCM, then
asserts one utterance and greps the saved argv for `-f`, `S16_LE`, `-r`,
`16000`, `-c`, `-t`, `raw`. Weak spot 1: `-c` is checked for presence only, so
`-c 2` would pass; the scenario says `-c 1`. Weak spot 2: "stdout is fed through
the same endpointing path" is only implied by a callback count of 1, which a
non-endpointing passthrough would also satisfy. I read the implementation
(`audio-in.mjs:136` spawns exactly `["-f","S16_LE","-r","16000","-c","1","-t","raw"]`
and `captureDevice` at :150-158 calls `endpointSamples`), so the behavior is
correct — the test is weaker than the scenario, not wrong. Recorded as a review
hint for the Architect; no scenario-level defect found.

No spot-checked test is vacuous (checked by `check-bats-assertions`, which passed
on all 104 bats files) and all three pass in the recorded suite run (`ok 62`,
`ok 92`, `ok 98`).

## Raw log: full test suite

command: scripts/agent-test-summary.sh --run /tmp/opencode/pipeline/044-verifier-suite.log -- env BATS_JOBS=8 make test-scripts
exit: 0
at: 2026-11-08T13:42:36Z

Checking bats assertions are not vacuous...

[0;32mPASS[0m check-bats-assertions: 104 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..7
ok 1 AC-031-06 — opencode.json agent block gains spec-deployer with an env reference, no literal model id
ok 2 AC-031-07 — config/model.local.env.example carries the committed SPEC_DEPLOYER_MODEL default
ok 3 AC-031-08 — config/agent.local.env.example carries commented Vercel placeholders (angle-bracket convention)
ok 4 AC-031-09 — check-no-hardcoded-secrets.sh exits 0 with the wiring in place
ok 5 AC-031-10 — guard-env.sh still exits 0 (no real env file tracked)
ok 6 unit — the model roster maps spec-deployer to SPEC_DEPLOYER_MODEL
ok 7 unit — the child-bridge template carries the spec-deployer env-reference wiring
1..24
ok 1 AC-036-01-01: selftest scenario passes
ok 2 AC-036-01-02: selftest scenario passes
ok 3 AC-036-01-03: selftest scenario passes
ok 4 AC-036-01-04: selftest scenario passes
ok 5 AC-036-01-05: selftest scenario passes
ok 6 AC-036-01-06: selftest scenario passes
ok 7 AC-036-01-07: selftest scenario passes
ok 8 AC-036-01-08: selftest scenario passes
ok 9 AC-036-02-01: selftest scenario passes
ok 10 AC-036-02-02: selftest scenario passes
ok 11 AC-036-02-03: selftest scenario passes
ok 12 AC-036-03-01: selftest scenario passes
ok 13 AC-036-03-02: selftest scenario passes
ok 14 AC-036-03-03: selftest scenario passes
ok 15 AC-036-03-04: selftest scenario passes
ok 16 AC-036-03-05: selftest scenario passes
ok 17 AC-036-03-06: selftest scenario passes
ok 18 AC-036-03-07: selftest scenario passes
ok 19 AC-036-03-08: selftest scenario passes
ok 20 AC-036-03-09: selftest scenario passes
ok 21 AC-036-04-01: selftest scenario passes
ok 22 AC-036-04-02: selftest scenario passes
ok 23 AC-036-04-03: selftest scenario passes
ok 24 AC-036-unit: selftest exits 0 overall
1..8
ok 1 AC-038-01-01 — every agents/spec-*.md within the cap makes the check exit 0
ok 2 AC-038-01-02 — a fixture agent at exactly 120 lines passes
ok 3 AC-038-01-03 — a fixture agent at 121 lines fails and names the path and count
ok 4 AC-038-01-04 — a 500-line non-spec agent is ignored
ok 5 unit — the cap is a single named constant of 120
ok 6 unit — the scan is a glob, so an unlisted spec-*.md over the cap is caught
ok 7 unit — a missing agents/ directory is a tooling failure, not a silent pass
ok 8 unit — usage rejects more than one argument
1..11
ok 1 AC-041-01 — coder points at the seven named sections, not §Formatting
ok 2 AC-041-02 — refactorer points at §Design Principles only
ok 3 AC-041-03 — checker passes on the repo tree with one [OK] per scanned file
ok 4 AC-041-04 — a bare whole-file reference is a violation
ok 5 AC-041-05 — an anchor matching no heading is a violation
ok 6 AC-041-06 — an anchor matching two headings is ambiguous and fails
ok 7 AC-041-07 — --cost reports referenced-section bytes only
ok 8 AC-041-08 — a missing conventions doc is a tooling failure, not a pass
ok 9 unit — --cost still exits 0 when a reference violates the check
ok 10 unit — -h prints usage and exits 0
ok 11 unit — a file with no reference is still reported [OK]
1..22
ok 1 AC-042-01-01: SSRF section requires a default-deny destination allowlist
ok 2 AC-042-01-02: loopback, private, link-local, and metadata ranges are refused
ok 3 AC-042-01-03: DNS rebinding cannot bypass the check
ok 4 AC-042-01-04: redirects are not followed blindly
ok 5 AC-042-02-01: cookie-authenticated state changes require a CSRF token
ok 6 AC-042-02-02: session cookies carry a SameSite policy
ok 7 AC-042-02-03: Origin or Referer is checked against an allowlist
ok 8 AC-042-02-04: bearer-token APIs are distinguished from cookie APIs
ok 9 AC-042-03-01: wildcard origin is never combined with credentials
ok 10 AC-042-03-02: origins come from an exact allowlist, never reflection
ok 11 AC-042-03-03: preflight responses are minimal
ok 12 AC-042-03-04: CORS is not treated as access control
ok 13 AC-042-04-01: only a password-hashing algorithm is used
ok 14 AC-042-04-02: fast general-purpose hashes are forbidden
ok 15 AC-042-04-03: work factors are recorded as minimums
ok 16 AC-042-04-04: verification is constant-time and hashes are upgraded
ok 17 AC-042-05-01: the section is a checklist with one line per check
ok 18 AC-042-05-02: algorithm allowlist, and alg=none is rejected
ok 19 AC-042-05-03: key selection is bound to a trusted JWKS
ok 20 AC-042-05-04: signature is verified first, then time claims
ok 21 AC-042-05-05: audience and issuer are validated; the section closes the block
ok 22 security docs: the security-hardening gate still passes
1..6
ok 1 unit: write_reward rejects a value other than 0 or 1
ok 2 unit: write_reward requires EVAL_REWARD_FILE
ok 3 unit: eval_task_field returns empty for a missing key
ok 4 unit: run_task rejects an unknown option with exit 2
ok 5 unit: run_verifier reports an invalid manifest instead of crashing
ok 6 unit: build_eval_record emits empty lists and a numeric duration
1..4
ok 1 AC-035-11 — the section declares the trigger and the no-questions rule
ok 2 AC-035-12 — a disposition exists for all 12 matrix rows, including Deploy verification fails
ok 3 AC-035-13 — all 6 hard stops are listed and never converted into a guess
ok 4 AC-035-14 — all 9 never-list refusals are listed as refusals, not decisions
1..7
ok 1 check-audit-trail: no slug exits 2 and prints the usage block
ok 2 check-audit-trail: an absent spec folder is 'nothing to check' and exits 0
ok 3 check-audit-trail: a spec folder missing 25-verification.md exits 1
ok 4 check-audit-trail: --selftest exercises every negative case and exits 0
ok 5 AC-035-33 — 'Autopilot: true' without 45-decisions.md FAILs the folder
ok 6 AC-035-34 — 'Autopilot: true' with a non-empty 45-decisions.md exits 0
ok 7 AC-035-35 — without the marker, 45-decisions.md is optional either way
1..6
ok 1 check-loop-files: clean repo exits 0 and prints its documented clean line
ok 2 check-loop-files: empty tree exits 1 and names the missing artifact
ok 3 check-loop-files: child scope passes a child that has only the six loop templates
ok 4 check-loop-files: child scope still fails when a loop template is missing
ok 5 check-loop-files: default standards scope still rejects a child-shaped tree
ok 6 check-loop-files: an unknown scope is a usage error, not a pass
1..7
ok 1 check-pr-review: clean repo exits 0 and prints its documented clean line
ok 2 check-pr-review: empty tree exits 1 and names the missing artifact
ok 3 unit: AC-024-01-12 fails when a spec agent changes without a docs/adr change in the set
ok 4 unit: AC-024-01-12 passes a documented pipeline change — spec agent plus untracked ADR in the same set
ok 5 unit: AC-024-01-12 fails loudly when no base ref can be resolved — never a vacuous PASS
ok 6 unit: AC-024-01-12 skips the change-set clause on a non-pull_request CI event
ok 7 unit: AC-024-01-12 passes a clean change set through an explicit GITHUB_BASE_SHA
1..8
ok 1 check-specs-archived: no finished specs exits 0 with the all-archived line
ok 2 check-specs-archived: a finished spec with no archive exits 1 and names the missing file
ok 3 check-specs-archived: a finished spec with its archive exits 0 and prints [OK]
ok 4 check-specs-archived: prose mentioning the budget marker does not satisfy the exception
ok 5 check-specs-archived: a line-start marker plus Verdict: ESCALATED defers archival
ok 6 check-specs-archived: a bulleted marker plus bulleted verdict defers archival
ok 7 check-specs-archived: a line-start marker without an ESCALATED verdict still fails
ok 8 check-specs-archived: a mid-line verdict mention does not satisfy the exception
1..8
ok 1 lint-outbox-schema: tree with no outbox table warns and exits 0
ok 2 lint-outbox-schema: outbox table missing required columns exits 1 with a violation count
ok 3 lint-outbox-schema: full outbox schema passes columns, partial index and cleanup
ok 4 lint-outbox-schema: Python Alembic outbox migration with all columns + partial index passes
ok 5 lint-outbox-schema: Python Alembic outbox migration missing a column and the partial index exits 1
ok 6 lint-outbox-schema: Rust sqlx outbox migration with all columns + partial index passes
ok 7 lint-outbox-schema: Rust sqlx outbox migration missing the partial index exits 1
ok 8 lint-outbox-schema: Rust sqlx outbox migration missing a required column exits 1
1..133
ok 1 AC-044-01-01: help lists the three modes and the five exit codes
ok 2 AC-044-01-02: print-config emits exactly one JSON object with the contract keys
ok 3 AC-044-01-03: print-config is inert (no request, no artifacts directory)
ok 4 AC-044-01-04: flag beats environment beats default
ok 5 AC-044-01-05: an unknown flag is a usage error with empty stdout
ok 6 AC-044-01-06: an invalid mode is a usage error naming the accepted values
ok 7 AC-044-01-07: --max-sentences accepts only integers of at least one
ok 8 AC-044-01-08: narrate and control require a parent session
ok 9 AC-044-01-09: narrate rejects audio input before any socket or child
ok 10 AC-044-01-10: ledger records carry the schema, contiguous seq and no clock or pid
ok 11 AC-044-02-01: merge commands are blocked with rule merge
ok 12 AC-044-02-02: tag creation is blocked with rule tag
ok 13 AC-044-02-03: pushing to a protected branch is blocked with rule push-main
ok 14 AC-044-02-04: force-push is blocked with rule force-push
ok 15 AC-044-02-05: branch deletion is blocked with rule delete-branch
ok 16 AC-044-02-06: gate-threshold edits are blocked
ok 17 AC-044-02-07: secret creation and rotation are blocked
ok 18 AC-044-02-08: writes outside the repository are blocked
ok 19 AC-044-02-09: git scaffolding is blocked with rule git-init
ok 20 AC-044-02-10: matching normalises case and whitespace
ok 21 AC-044-02-11: read-only intents need no confirmation
ok 22 AC-044-02-12: unclassified intents require confirmation
ok 23 AC-044-02-13: classification is pure and the module imports no fs or network
ok 24 AC-044-03-01: a blocked action is never sent
ok 25 AC-044-03-02: no flag overrides a never-list refusal
ok 26 AC-044-03-03: one reply path, and the guard runs first
ok 27 AC-044-03-04: mutating tools need terminal confirmation
ok 28 AC-044-03-05: read-only tools may be answered by voice
ok 29 AC-044-03-06: a policy refusal is a distinguishable exit
ok 30 AC-044-04-01: self-check works without optional packages
ok 31 AC-044-04-02: silent engine writes a valid WAV
ok 32 AC-044-04-03: event order is start, chunk, done and the worker stays alive
ok 33 AC-044-04-04: a bad request does not kill the worker
ok 34 AC-044-04-05: a cancel request stops the utterance
ok 35 AC-044-04-06: SIGINT cancels and exits cleanly
ok 36 AC-044-04-07: a missing Pocket TTS runtime exits 3
ok 37 AC-044-04-08: duration arithmetic is exact
ok 38 AC-044-04-09: the worker is file-only
ok 39 AC-044-05-01: split on terminators and retain them
ok 40 AC-044-05-02: decimals are not boundaries
ok 41 AC-044-05-03: abbreviations are not boundaries
ok 42 AC-044-05-04: question and exclamation boundaries need no capital
ok 43 AC-044-05-05: the sentence cap wins
ok 44 AC-044-05-06: the time cap wins when reached first
ok 45 AC-044-05-07: the first sentence is always spoken whole
ok 46 AC-044-05-08: deferred windows drain to empty
ok 47 AC-044-05-09: streaming emits each sentence exactly once
ok 48 AC-044-06-01: parent assistant text is spoken
ok 49 AC-044-06-02: subtask chatter is suppressed
ok 50 AC-044-06-03: foreign sessions and user parts are suppressed
ok 51 AC-044-06-04: growing parts yield only the delta
ok 52 AC-044-06-05: one request per prompt with the verbatim text
ok 53 AC-044-06-06: one request per reply on the documented path
ok 54 AC-044-06-07: upstream failure is bounded and loud
ok 55 AC-044-06-08: stream reconnect is bounded
ok 56 AC-044-06-09: dry run sends nothing
ok 57 AC-044-06-10: the fake server prints LISTENING, records, and exits 0 on SIGTERM
ok 58 AC-044-07-01: two tones produce exactly two utterances
ok 59 AC-044-07-02: leading and trailing silence produce no extra utterance
ok 60 AC-044-07-03: a short blip is dropped
ok 61 AC-044-07-04: long speech is force-split
ok 62 AC-044-07-05: device mode spawns arecord and reuses the endpointing path
ok 63 AC-044-07-06: missing arecord is a dependency exit with no ledger
ok 64 AC-044-07-07: file mode spawns nothing
ok 65 AC-044-07-08: fixtures are deterministic
ok 66 AC-044-08-01: engine precedence
ok 67 AC-044-08-02: an unknown engine is a usage error
ok 68 AC-044-08-03: file transcripts map by index
ok 69 AC-044-08-04: missing transcript lines are skipped
ok 70 AC-044-08-05: blank transcripts produce no prompt
ok 71 AC-044-08-06: no cloud path exists
ok 72 AC-044-08-07: a missing engine runtime exits 3 before reading audio
ok 73 AC-044-08-08: documentation matches the single source of truth
ok 74 AC-044-09-01: the file sink numbers sequentially
ok 75 AC-044-09-02: existing files are never overwritten
ok 76 AC-044-09-03: file mode spawns no child process
ok 77 AC-044-09-04: device mode plays through ffplay
ok 78 AC-044-09-05: missing ffplay is a dependency exit
ok 79 AC-044-09-06: cancellation stops playback promptly
ok 80 AC-044-09-07: a new utterance supersedes the old one
ok 81 AC-044-10-01: narrate never captures and never transcribes
ok 82 AC-044-10-02: budget and parent-only filtering end to end
ok 83 AC-044-10-03: the operator can ask for the rest
ok 84 AC-044-10-04: requesting more after exhaustion is recorded
ok 85 AC-044-10-05: stop cancels the current utterance and the process continues
ok 86 AC-044-10-06: SIGINT exits cleanly, twice forces exit
ok 87 AC-044-10-07: non-interactive stdin never blocks
ok 88 AC-044-11-01: two utterances become two prompts and two replies
ok 89 AC-044-11-02: turns increment and stay contiguous
ok 90 AC-044-11-03: an empty transcript sends nothing
ok 91 AC-044-11-04: the reply budget applies and more resumes it
ok 92 AC-044-11-05: a missing session is created with the concierge agent
ok 93 AC-044-11-06: device capture without a device fails loudly
ok 94 AC-044-12-01: control is opt-in
ok 95 AC-044-12-02: questions surface numbered options
ok 96 AC-044-12-03: answers by number or label
ok 97 AC-044-12-04: unmatched answers re-prompt once and then stay pending
ok 98 AC-044-12-05: free-text questions send the transcript verbatim
ok 99 AC-044-12-06: read-only permissions are answerable by voice
ok 100 AC-044-12-07: mutating permissions wait for the terminal
ok 101 AC-044-12-08: declined or abandoned confirmations send nothing
ok 102 AC-044-12-09: blocked permissions are refused and not overridable
ok 103 AC-044-12-10: slash prompts need terminal confirmation
ok 104 AC-044-13-01: the agent lives outside the default agent set
ok 105 AC-044-13-02: frontmatter shape
ok 106 AC-044-13-03: no pinned model
ok 107 AC-044-13-04: read-only permissions are structural
ok 108 AC-044-13-05: the prompt states its limits
ok 109 AC-044-13-06: the governance row is present and T0
ok 110 AC-044-13-07: the model-pin gate is not weakened
ok 111 AC-044-14-01: install writes the complete tree
ok 112 AC-044-14-02: re-running is idempotent
ok 113 AC-044-14-03: uninstall removes exactly what was installed
ok 114 AC-044-14-04: dry run writes nothing
ok 115 AC-044-14-05: a missing source aborts without partial copies
ok 116 AC-044-14-06: no writes outside the config directory
ok 117 AC-044-14-07: make targets exist
ok 118 AC-044-14-08: smoke output is checkable
ok 119 AC-044-14-09: smoke is offline and Python-optional
ok 120 AC-044-15-01: every scenario is cited exactly once
ok 121 AC-044-15-02: traceability passes
ok 122 AC-044-15-03: no vacuous assertions
ok 123 AC-044-15-04: the suite runs without the optional runtime
ok 124 AC-044-15-05: the suite is hermetic
ok 125 AC-044-15-06: temp fixtures come from the shared helper
ok 126 AC-044-16-01: required sections exist
ok 127 AC-044-16-02: the document does not overclaim duplex
ok 128 AC-044-16-03: privacy and fallback are stated
ok 129 AC-044-16-04: licensing and weights are stated
ok 130 AC-044-16-05: never-list and exit codes match the code
ok 131 AC-044-16-06: configuration matches print-config
ok 132 AC-044-16-07: the ADR is recorded
ok 133 AC-044-16-08: repo gates stay green and no weights are tracked
1..6
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
ok 3 AC-001-03: Helper safely sources shared libs (json_escape, json_array)
ok 4 AC-001-04: Missing bats binary yields actionable error via make test-scripts
ok 5 AC-001-05: No secrets in harness or fixtures
ok 6 AC-001-06: CI invokes the harness (self-ci.yml contains make test-scripts or bats scripts/tests)
1..9
ok 1 AC-031-42 — non-frontend repo: agent writes 40-deploy.md with SKIPPED verdict and the skip reason
ok 2 AC-031-43 — non-frontend 40-deploy.md with SKIPPED never fails the deploy gate
ok 3 AC-031-44 — GHCR container path is untouched: ci-nextjs.yml still pushes ghcr.io and the Vercel lane is a separate file
ok 4 AC-031-45 — preview build timeout records FAIL with the timeout reason and consumes a phase-3 round
ok 5 AC-031-46 — preview build failure records FAIL with the Vercel error classification and build log excerpt
ok 6 AC-031-47 — deploy succeeds but health check fails: FAIL records the response code or timeout
ok 7 AC-031-48 — E2E failure against the live preview URL records FAIL and routes to spec-coder
ok 8 AC-031-49 — no Vercel project linked: SKIPPED with the manual-setup reason, pipeline does not fail
ok 9 unit — --require-deploy does not fail a non-frontend repo missing 40-deploy.md (non-frontend behavior is flag-independent)
1..5
ok 1 AC-037-01-01: index keeps the cross-cutting sections
ok 2 AC-037-01-02: Stop-and-Ask table rows are byte-identical to the base commit
ok 3 AC-037-01-03: index length is at most 250 lines
ok 4 AC-037-01-04: every stage-file path in the Stage files table exists
ok 5 unit: index keeps the stage table rows 5a-5d
1..6
ok 1 AC-038-03-01 — every formerly over-cap agent is at or under 120 lines
ok 2 AC-038-03-02 — every scripts/ or skills/ path a trimmed agent cites exists
ok 3 unit — each trimmed agent points at the stage doc that now carries its procedure
ok 4 unit — the extracted procedures are headings of the stage doc they moved to
ok 5 unit — each trimmed agent still declares the Stop-and-Ask matrix authoritative
ok 6 unit — the extracted stage docs stay inside each stage's read-cost budget
1..5
ok 1 AC-041-45 — the guidance section names every mechanical stage
ok 2 AC-041-46 — the effort-location finding is recorded
ok 3 AC-041-47 — the verified per-agent lever is recorded
ok 4 AC-041-48 — no model id or provider id appears in the section
ok 5 AC-041-49 — shipped defaults are unchanged and the decision is recorded
1..7
ok 1 AC-042-10-01: this repo still passes the gate
ok 2 AC-042-10-02: a new guide at exactly 200 lines passes
ok 3 AC-042-10-03: a new guide at 201 lines fails with an actionable message
ok 4 AC-042-10-04: a grandfathered guide at its ceiling passes
ok 5 AC-042-10-05: a grandfathered guide that grows fails
ok 6 AC-042-10-06: skills/ keeps the 500-line warning
ok 7 AC-042-10-07: the documented checklist matches the script
1..9
ok 1 AC-004-04: mvn wiring documented and CI template references it
ok 2 AC-005-04: internal layout follows Go standards
ok 3 AC-006-04: npm scripts wired and package manager unchanged
ok 4 AC-006-05: Complexity gate referenced at ≤6
ok 5 AC-006-06: Tier awareness documented
ok 6 AC-007-01: Root Makefile exposes unified targets
ok 7 AC-007-02: bootstrap and init-ci reference the new templates
ok 8 AC-007-03: Onboarding guide is concise and covers both tracks
ok 9 AC-007-04: Orchestration check still passes
1..1
ok 1 AC-035-36 — no pipeline agent contains an unconditional ask path (repo exits 0)
1..8
ok 1 check-bats-assertions: a directory of real assertions exits 0 with a PASS line
ok 2 check-bats-assertions: a bare 'true' used as an assertion exits 1 and names file:line
ok 3 check-bats-assertions: 'true || [ ... ]' short-circuit exits 1 and is named as such
ok 4 check-bats-assertions: 'run ... || true' with no status assertion exits 1
ok 5 check-bats-assertions: 'run ... || true' followed by a status assertion is allowed
ok 6 check-bats-assertions: the word 'true' inside a comment is not a violation
ok 7 check-bats-assertions: a missing tests directory is a tooling failure (exit 2)
ok 8 check-bats-assertions: the repo's own bats suite is free of vacuous assertions
1..2
ok 1 check-loop-triage: clean repo exits 0 and prints its documented clean line
ok 2 check-loop-triage: empty tree exits 1 and names the missing artifact
1..2
ok 1 check-pr-review.selftest: exits 0 and reports every case passing
ok 2 check-pr-review.selftest: reports a non-zero assertion count and zero failures
1..7
ok 1 check-stop-and-ask-matrix: an empty tree cannot be checked and exits 2
ok 2 check-stop-and-ask-matrix: a matrix missing the design-gate row exits 1 with FAIL AC-009
ok 3 check-stop-and-ask-matrix: the design-gate row wording is asserted verbatim
ok 4 AC-035-30 — a matrix without the Autopilot mode section FAILs AC-035-30
ok 5 AC-035-31 — a missing disposition for one matrix row FAILs AC-035-31 naming it
ok 6 AC-035-32 — an unconditional question phrase with no autopilot reference FAILs AC-035-32
ok 7 unit — the complete fixture passes the autopilot checks (exit 0)
1..10
ok 1 media-agents: every agent file exists
ok 2 media-agents: the default agent set carries no media agent (ADR 0018)
ok 3 media-agents: description and mode frontmatter, no pinned model
ok 4 media-agents: deny git push and rm -rf in the permission block
ok 5 media-agents: each agent references the backend contract
ok 6 media-agents: no vendor-specific token in agents, docs, or contract example
ok 7 media-agents: contract example parses and carries every core operation
ok 8 media-agents: smoke-media.mjs exits 0 with the expected OK lines
ok 9 media-agents: install survives dangling symlinks in the config dir
ok 10 media-agents: install writes the tree, is idempotent, keeps user config, uninstall reverses
1..6
ok 1 AC-004-05: No speculative generality in scaffold
ok 2 AC-004-06: Complexity threshold stays at ≤6
ok 3 AC-005-05: Mutation and lint wiring referenced
ok 4 AC-005-06: Red-then-green loop documented
ok 5 AC-007-05: Smoke bootstrap Java and Go features from templates
ok 6 AC-007-06: Existing gates still green
1..6
ok 1 AC-031-56 — check-orchestration.sh exits 0 with spec-deployer wired in
ok 2 AC-031-57 — check-model-env.sh exits 0 (env-reference roster incl. spec-deployer)
ok 3 AC-031-58 — check-audit-trail.sh --selftest still exits 0 after the 40-deploy extension
ok 4 AC-031-59 — check-no-hardcoded-secrets.sh exits 0 over the scanned tree
ok 5 AC-031-60 — guard-env.sh exits 0 (config/agent.local.env not tracked)
ok 6 unit — model-env selftest stays green with the 10-agent roster
1..6
ok 1 AC-037-04-01: the split tree passes check-orchestration
ok 2 AC-037-04-02: a missing docs/spec-pipeline path is reported and exits 1
ok 3 AC-037-04-03: a missing §anchor in a stage doc prints file:line and exits 1
ok 4 AC-037-04-04: an index §anchor that exists resolves and exits 0
ok 5 unit: an index §anchor that does not exist is reported
ok 6 unit: a heading that is a prefix of another word does not resolve
1..33
ok 1 AC-039-01-01: an explicit LITE argv token prints lite
ok 2 AC-039-01-02: an explicit full argv token prints full
ok 3 AC-039-01-03: no mode token prints auto
ok 4 AC-039-01-04: partial tokens do not match
ok 5 AC-039-01-05: conflicting tokens exit non-zero with an empty stdout
ok 6 AC-039-02-01: a docs-only spec with 3 scenarios is lite
ok 7 AC-039-02-02: exactly one scripts/ file with 5 scenarios is lite
ok 8 AC-039-02-03: a docs-only spec with 6 scenarios is full
ok 9 AC-039-02-04: two scripts/ files with 2 scenarios is full
ok 10 AC-039-02-05: a spec without 20-acceptance/ falls back to full
ok 11 AC-039-02-06: a missing spec folder exits non-zero naming the path
ok 12 AC-039-02-07: the classifier is byte-identical across runs
ok 13 AC-039-03-01: the production tier refuses an explicit lite token
ok 14 AC-039-03-02: the production tier refuses a classifier lite
ok 15 AC-039-03-03: the multi-service tier refuses an explicit lite token
ok 16 AC-039-03-04: an undetectable tier refuses an explicit lite token
ok 17 unit: a relative spec path with an undetectable tier resolves full and terminates
ok 18 AC-039-03-05: the mvp tier permits an explicit lite token
ok 19 AC-039-04-01: the classifier decides when there is no token
ok 20 AC-039-04-02: an explicit full token overrides a classifier lite
ok 21 AC-039-04-03: an explicit lite token overrides a classifier full
ok 22 AC-039-04-04: a tier refusal is logged with why tier
ok 23 AC-039-04-05: the decision entry is appended in the six-line format
ok 24 AC-039-04-06: a resolution writes only inside the spec folder
ok 25 unit: the trigger match lives only in lite-trigger.sh
ok 26 unit: the spec folder's own artifacts count as docs surface
ok 27 unit: a slash command token is not a named path
ok 28 unit: a path outside docs/specs/scripts and not markdown forces full
ok 29 unit: a spec naming no path falls back to full
ok 30 unit: a missing 10-tasks.md falls back to full
ok 31 unit: resolution of a missing spec folder exits non-zero
ok 32 unit: the resolved mode prints as exactly one bare token
ok 33 unit: the classifier bases its answer only on the spec folder
1..7
ok 1 AC-041-38 — the verifier records the hash inside the full-test-suite block
ok 2 AC-041-39 — a tree that changes during the run is recorded, not hidden
ok 3 AC-041-40 — the reuse branch executes no test command
ok 4 AC-041-41 — the re-run branch records its own evidence
ok 5 AC-041-42 — mutation testing is never reused
ok 6 AC-041-43 — the verifier never reuses
ok 7 AC-041-44 — a reuse-form report still passes the audit-trail gate
1..21
ok 1 AC-043-01: ADR follows the mandated template in order and is Proposed
ok 2 AC-043-02: ADR records the four load-bearing decisions
ok 3 AC-043-03: ADR records rejected alternatives and the out-of-scope list
ok 4 AC-043-04: the ADR is indexed exactly once and governance passes
ok 5 AC-043-05: evals/ is a top-level package with the documented contract
ok 6 AC-043-06: the pipeline surface never references evals
ok 7 AC-043-07: the gate follows the check-script conventions
ok 8 AC-043-08: a missing package fails with a FAIL line, not a shell error
ok 9 AC-043-09: a pipeline reference to evals fails and names the file
ok 10 AC-043-10: every task carries the five required entries
ok 11 AC-043-11: manifests declare the required keys and types
ok 12 AC-043-12: only the three probe tasks declare a probe contract
ok 13 AC-043-13: a missing or empty required entry fails and names it
ok 14 AC-043-14: malformed TOML fails without a traceback
ok 15 AC-043-15: duplicate task ids are rejected and both dirs named
ok 16 AC-043-16: an unresolvable agent or invalid timeout is rejected
ok 17 AC-043-59: self-CI runs the gate and its self-test
ok 18 AC-043-60: the agent-eval step cannot be skipped
ok 19 AC-043-61: the self-test fails closed on its fixture set
ok 20 AC-043-62: the gate is read-only and offline
ok 21 AC-043-63: the governance link is enforced
1..9
ok 1 AC-004-01: Java scaffold directory and pom fragment exist
ok 2 AC-004-02: Java layered skeleton mirrors ARCHITECTURE.md (controller/service/repository)
ok 3 AC-004-03: Java sample acceptance test is traceable and Given/When/Then named
ok 4 AC-005-01: Go scaffold directory and Makefile ci ladder exist
ok 5 AC-005-02: Go test command matches the standards (-race -shuffle=on -count=1)
ok 6 AC-005-03: Go sample tests use stdlib testing and a testing/quick property test, not testify
ok 7 AC-006-01: JS scaffold directory and package wiring exist
ok 8 AC-006-02: JS sample acceptance test carries its AC id in the it() name
ok 9 AC-006-03: Stryker mutation threshold 80 is configured in the JS scaffold
1..3
ok 1 AC-035-15 — the orchestrator never asks in autopilot and records each resolved ask
ok 2 AC-035-16 — the 9 never-list actions are hard refusals, never decisions
ok 3 AC-035-17 — the queue stops at the first hard stop and writes the morning report
1..2
ok 1 check-ci-sweeper: clean repo exits 0 and prints its documented clean line
ok 2 check-ci-sweeper: empty tree exits 1 and names the missing artifact
1..6
ok 1 check-model-env: missing opencode.json exits 1 and names the expected path
ok 2 check-model-env: a literal provider/model id in an agent block exits 1
ok 3 check-model-env: a bridge template missing an agent exits 1 and names it
ok 4 check-model-env: a bridge template with a literal model id exits 1
ok 5 check-model-env: a root without a bridge template skips check 4 and exits 0
ok 6 check-model-env: the real repo has no literal model ids and exits 0
1..2
ok 1 check-remediation-budget: clean repo exits 0 and prints its documented clean line
ok 2 check-remediation-budget: empty tree exits 1 and names the missing artifact
1..8
ok 1 AC-002-01: detect-saga-outbox happy path detects saga file
ok 2 detect-saga-outbox: sagaStep() in a JS/TS file sets SAGA_DETECTED=true
ok 3 AC-002-02: detect-saga-outbox no-saga repo yields negative signal
ok 4 detect-saga-outbox: run is hermetic — leaves scripts/ untouched
ok 5 detect-saga-outbox: saga_step in a .py file sets SAGA_DETECTED=true
ok 6 detect-saga-outbox: Compensable impl in a .rs file sets SAGA_DETECTED=true
ok 7 detect-saga-outbox: OutboxRelay in a .py file sets OUTBOX_DETECTED=true
ok 8 detect-saga-outbox: publish_pending in a .rs file sets OUTBOX_DETECTED=true
1..3
ok 1 model-env.selftest: exits 0 and reports every case passing
ok 2 model-env.selftest: reports a non-zero assertion count and zero failures
ok 3 model-env.selftest: gitignore check takes the ignored path, not the could-not-run path
1..49
ok 1 AC-030-01-01: SKILL.md frontmatter exists with required fields
ok 2 AC-030-01-02: name field is exactly e2e-testing (matches directory)
ok 3 AC-030-01-03: name format valid, lowercase-hyphen, <=64 chars
ok 4 AC-030-01-04: description non-empty and within 1024-char limit
ok 5 AC-030-01-05: body line count within 500-line limit
ok 6 AC-030-01-06: required body sections present
ok 7 AC-030-01-07: version pin 0.17.0 and pre-1.0 instability warning present
ok 8 AC-030-01-08: telemetry opt-out E2E_TELEMETRY_DISABLED mandated
ok 9 AC-030-01-09: act+expect golden rule stated
ok 10 AC-030-01-10: opaque Secret path taught, inline credentials forbidden
ok 11 AC-030-01-11: no literal model or provider ids in SKILL.md
ok 12 AC-030-01-12: no forbidden re-run phrasing in SKILL.md
ok 13 AC-030-02-01: all six reference files exist
ok 14 AC-030-02-02: each reference file is referenced from SKILL.md
ok 15 AC-030-02-03: no nested reference chains between reference files
ok 16 AC-030-02-04: setup.md content coverage
ok 17 AC-030-02-05: writing-tests.md content coverage
ok 18 AC-030-02-06: running-debugging.md content coverage
ok 19 AC-030-02-07: bug-bash.md content coverage
ok 20 AC-030-02-08: ci.md and mobile-rn.md content coverage
ok 21 AC-030-03-01: config example file exists
ok 22 AC-030-03-02: model ids read from process.env, none hardcoded
ok 23 AC-030-03-03: port-0 pattern and shell-less app launch present
ok 24 AC-030-03-04: budgets and cache modes configured
ok 25 AC-030-03-05: telemetry opt-out, tests glob, no .env loading
ok 26 AC-030-04-01: agent frontmatter has required fields
ok 27 AC-030-04-02: permission denies git push and git commit
ok 28 AC-030-04-03: permission denies edits outside allowed paths, .e2e read-only
ok 29 AC-030-04-04: no model key in frontmatter
ok 30 AC-030-04-05: body has required sections for both duties
ok 31 AC-030-04-06: workflow vs agent choice justified
ok 32 AC-030-04-07: ground truth and stopping conditions stated
ok 33 AC-030-04-08: bug-bash bounds, confirmation gate, hygiene
ok 34 AC-030-05-01: docs/TESTING.md agentic E2E section, skill pointer, Playwright preserved
ok 35 AC-030-05-02: AGENTS.md Reading the Standards line added
ok 36 AC-030-05-03: no literal model ids added to docs
ok 37 AC-030-06-01: opencode.json e2e-runner entry uses env reference (conditional)
ok 38 AC-030-06-02: config/model.local.env.example defines the var (conditional)
ok 39 AC-030-06-03: model-env roster updated and check-model-env green (conditional)
ok 40 AC-030-07-01: check-skills.sh exits 0
ok 41 AC-030-07-02: check-orchestration.sh exits 0
ok 42 AC-030-07-03: check-model-env.sh exits 0 and holistic hygiene holds
ok 43 AC-030-01: T1 full suite (scenarios + units) exits 0
ok 44 AC-030-02: T2 full suite (scenarios + units) exits 0
ok 45 AC-030-03: T3 full suite (scenarios + units) exits 0
ok 46 AC-030-04: T4 full suite (scenarios + units) exits 0
ok 47 AC-030-05: T5 full suite (scenarios + units) exits 0
ok 48 AC-030-06: T6 full suite (scenarios + units) exits 0
ok 49 AC-030-07: T7 full suite (scenarios + units) exits 0
1..9
ok 1 AC-031-28 — phase-3 counter is its own max-3 budget, independent of phase 1 and phase 2
ok 2 AC-031-29 — 3rd failure stops the pipeline before 5d, relays 40-deploy.md evidence verbatim, escalates
ok 3 AC-031-30 — E2E runner non-zero routes to spec-coder
ok 4 AC-031-31 — Vercel configuration-classified error routes to spec-deployer retry
ok 5 AC-031-32 — structural/complexity gate failure routes to spec-refactorer
ok 6 AC-031-33 — ambiguous BUILD_FAILED with no clear diagnostic escalates to the human, no invented heuristic
ok 7 AC-031-34 — Stop-and-Ask matrix has the deploy row with the fix-routing action
ok 8 AC-031-35 — spec-deployer refuses vercel deploy and records the refusal in 40-deploy.md
ok 9 AC-031-36 — phase 3 does not start on a phase-2 FAIL verdict
1..5
ok 1 AC-037-05-01: every stage reads at most 50% and the script exits 0
ok 2 AC-037-05-02: a stage over the budget exits 1 and is named
ok 3 AC-037-05-03: a stage at exactly 50% of the baseline passes
ok 4 unit: a shared file named in a Must read block is counted
ok 5 unit: a missing index is a tooling failure, not a silent pass
1..12
ok 1 AC-039-05-01: lite runs Coder, Verifier, PR Opener, Archiver and nothing else
ok 2 AC-039-05-02: the full stage list is unchanged
ok 3 AC-039-05-03: a lite run records the mode and each skipped stage as skipped (lite)
ok 4 AC-039-05-04: check-orchestration exits 0 after the change
ok 5 AC-039-06-01: every hard gate still runs in lite
ok 6 AC-039-06-02: a principles FAIL is a Verifier FAIL and stops the lite run
ok 7 AC-039-06-03: a secrets finding is a Verifier FAIL and no commit or push occurs
ok 8 AC-039-07-01: the ADR exists with status Proposed and is indexed
ok 9 AC-039-07-02: the index documents lite mode and links the ADR
ok 10 AC-039-07-03: check-orchestration and check-skills both exit 0
ok 11 unit: the orchestrator applies the resolved mode before delegating
ok 12 unit: the lite stage file names every skipped stage and the retained gates
1..17
ok 1 AC-041-27 — hash output is one lowercase sha256 line
ok 2 AC-041-28 — the hash is deterministic on an unchanged tree
ok 3 AC-041-29 — a tracked content change changes the hash
ok 4 AC-041-30 — a new untracked file changes the hash
ok 5 AC-041-31 — a new commit changes the hash
ok 6 AC-041-32 — a matching hash authorizes reuse
ok 7 AC-041-33 — a hash mismatch forces a re-run
ok 8 AC-041-34 — no evidence block forces a re-run
ok 9 AC-041-35 — a non-zero recorded exit forces a re-run
ok 10 AC-041-36 — a missing hash line forces a re-run
ok 11 AC-041-37 — usage error and non-repo are tooling errors
ok 12 unit — a deleted tracked file changes the hash
ok 13 unit — recording the hash in the evidence file leaves the fingerprint unchanged (REUSE)
ok 14 unit — a runs.jsonl telemetry append is excluded from the fingerprint
ok 15 unit — the evidence exclusion does not hide a dirty tracked file
ok 16 unit — an unreadable verification file is exit 2 with nothing on stdout
ok 17 unit — --help prints usage and exits 0
1..8
ok 1 unit: the probe workspace is a detached scratch worktree with no origin
ok 2 unit: origin and the discoverable repo path cannot reach the real source
ok 3 unit: an explicit source-path push is blocked and the source is unchanged
ok 4 unit: the agent environment is scrubbed
ok 5 unit: a source mutation is an environment block, never a pass
ok 6 unit: the source snapshot covers ignored files, hooks, info/exclude, packed and remote refs
ok 7 unit: the host-mode isolation control fails closed and names sandbox=none
ok 8 unit: the isolation control refuses when the sandbox is unavailable
1..3
ok 1 agent-env.selftest: exits 0 and reports every case passing
ok 2 agent-env.selftest: reports a non-zero assertion count and zero failures
ok 3 agent-env.selftest: gitignore checks take the ignored path, not the could-not-run path
1..5
ok 1 AC-035-24 — a tree dirty only inside specs/<slug>/ passes
ok 2 AC-035-25 — gh auth, GITHUB_TOKEN, and GH_TOKEN are required and fail fast
ok 3 AC-035-26 — a named slug whose spec folder does not exist fails with a reason
ok 4 AC-035-27 — the judgment backend is optional and never fails preflight
ok 5 unit — a dirty path outside the current spec folder fails, and so does a non-repo
1..51
ok 1 AC-032-01-01: the ADR exists with the mandated section shape
ok 2 AC-032-01-02: the ADR records the taxonomy, the rollout, and the rejected blanket ban
ok 3 AC-032-01-03: the ADR is indexed and governance still passes
ok 4 AC-032-02-01: the three new names are accepted by --gates and --blocking
ok 5 AC-032-02-02: unknown and empty gate values still exit 2 and list all nine
ok 6 AC-032-02-03: a default run selects nine gates, a scoped run says so in the summary
ok 7 AC-032-02-04: help text documents the three gates, the allowlist, and the strict switch
ok 8 AC-032-02-05: each new gate has its own dispatch block
ok 9 AC-032-03-01: shell files are scanned for comments
ok 10 AC-032-03-02: excluded directories are not scanned
ok 11 AC-032-03-03: shell is not dragged into the existing gates
ok 12 AC-032-03-04: the scanned-extension message names shell, and its test is updated
ok 13 AC-032-04-01: two consecutive code-shaped comment lines produce one finding
ok 14 AC-032-04-02: a single code-shaped comment line is not a finding
ok 15 AC-032-04-03: two consecutive prose comment lines are not a finding
ok 16 AC-032-05-01: a token-subset comment produces a finding
ok 17 AC-032-05-02: an extra token in the comment suppresses the finding
ok 18 AC-032-05-03: short comments and non-adjacent comments do not fire
ok 19 AC-032-06-01: TODO and FIXME without an issue reference warn
ok 20 AC-032-06-02: an issue reference suppresses the TODO/FIXME finding
ok 21 AC-032-06-03: section dividers and attributions warn
ok 22 AC-032-06-04: advisory findings never become FAIL
ok 23 AC-032-07-01: the first five lines of a file are never scanned
ok 24 AC-032-07-02: tool directives are skipped per line, and do not disable the file
ok 25 AC-032-07-03: ponytail and standards markers are preserved and skipped
ok 26 AC-032-07-04: licence markers and URLs are skipped
ok 27 AC-032-07-05: doc blocks attached to public API are skipped; private code is not
ok 28 AC-032-08-01: default classification is WARN with exit 0
ok 29 AC-032-08-02: STRICT_CLEAN_CODE=1 promotes the blocking-class rules
ok 30 AC-032-08-03: --blocking comments promotes without the environment switch
ok 31 AC-032-08-04: only the literal value 1 promotes, and advisory rules never promote
ok 32 AC-032-08-05: Python and Rust findings stay WARN under the strict switch
ok 33 AC-032-08-06: --json and -ReportPath carry the classification
ok 34 AC-032-09-01: single-character identifiers fire, loop counters do not
ok 35 AC-032-09-02: noise words fire at word boundaries only
ok 36 AC-032-09-03: encoded identifiers fire, ordinary camelCase does not
ok 37 AC-032-09-04: boolean flag parameters fire, other booleans do not
ok 38 AC-032-09-05: more than three parameters fires at four, not at three
ok 39 AC-032-09-06: naming never emits FAIL and never scans shell
ok 40 AC-032-10-01: return null is reported
ok 41 AC-032-10-02: null arguments are reported; comparisons and assignments are not
ok 42 AC-032-10-03: Python and Rust are not scanned
ok 43 AC-032-10-04: null findings never become FAIL
ok 44 AC-032-11-01: gate consistency passes with nine gates
ok 45 AC-032-11-02: the blame suite reflects that naming is now a gate
ok 46 AC-032-11-03: CODING_CONVENTIONS documents the new gates
ok 47 AC-032-11-04: the check-principles skill lists all nine gates
ok 48 AC-032-12-01: the selftest proves each new rule and each allowlist control
ok 49 AC-032-12-02: the new scenarios run as bats tests and are not vacuous
ok 50 AC-032-12-03: the new gates cannot turn the repository red on day one
ok 51 AC-032-12-04: existing gate behavior is unchanged
1..11
ok 1 check-no-hardcoded-secrets: clean scratch root exits 0 with PASS line
ok 2 check-no-hardcoded-secrets: literal GitHub token prefix exits 1 and prints file:line
ok 3 check-no-hardcoded-secrets: secret-style assignment with a literal value exits 1
ok 4 check-no-hardcoded-secrets: placeholder and ${VAR} values are not violations
ok 5 check-no-hardcoded-secrets: a gitignored, untracked credentials file is not a violation
ok 6 check-no-hardcoded-secrets: a gitignored file that is force-added IS still caught (no bypass)
ok 7 check-no-hardcoded-secrets: a non-git scratch root still scans every file
ok 8 check-no-hardcoded-secrets: the matched secret VALUE is never printed
ok 9 check-no-hardcoded-secrets: a literal token prefix is reported without echoing the line
ok 10 check-no-hardcoded-secrets: a credential literal in skills/ is caught (widened scope)
ok 11 check-no-hardcoded-secrets: placeholders in language-specific/ still pass (no doc false positive)
1..6
ok 1 check-saga-tests: neither saga nor outbox detected warns and exits 0
ok 2 check-saga-tests: saga detected without an integration test exits 1 and names the required pattern
ok 3 check-saga-tests: saga detected with a compensation integration test exits 0
ok 4 check-saga-tests: Python saga with a pytest compensation test exits 0
ok 5 check-saga-tests: Rust saga with a tests/ integration test exits 0
ok 6 check-saga-tests: Python saga without an integration test exits 1
1..6
ok 1 gate-report-lib: sources safely and exposes json_escape and json_array
ok 2 gate-report-lib: strip_dashes normalizes single- and double-dash flag names
ok 3 gate-report-lib: json_array emits a comma-separated list of quoted, escaped items
ok 4 gate-report-lib: json_array with no arguments emits nothing
ok 5 gate-report-lib: emit_json_report writes atomically and leaves no .tmp sibling
ok 6 emit_json_report returns 1 and reports the path when the target is unwritable
1..5
ok 1 model-env.vars: the var roster and the agent roster are the same length
ok 2 model-env.vars: every agent in the roster maps to its own SPEC_*_MODEL var, in order
ok 3 model-env.vars: an unknown agent maps to the empty string
ok 4 model-env.vars: spec-coder maps to SPEC_CODER_MODEL
ok 5 model-env.vars: every plus-tier agent is also a member of the agent roster
1..5
ok 1 AC-031-50 — ADR 0008 exists, follows templates/ADR.md structure, and records the four decisions
ok 2 AC-031-51 — ADR 0008 status is Accepted
ok 3 AC-031-52 — ADR index has a 0008 row with title and link to the file
ok 4 unit — docs/adr carries the numbered 0008 file and all ADR files use 4-digit numbers (0008 pinned at spec 031's time)
ok 5 unit — ADR 0010 (--require-deploy gate split) exists, carries every template heading, and is indexed
1..7
ok 1 AC-031-11 — stage table lists 5a, 5b (no longer archives), 5c Deploy Verifier (spec-deployer), 5d Archiver (spec-pr-opener)
ok 2 AC-031-12 — artifact layout lists 40-deploy.md with its deploy-evidence purpose
ok 3 AC-031-13 — definition of done requires 40-deploy.md present with verdict or skip reason
ok 4 AC-031-14 — commit-and-push carve-out names stage 5d explicitly alongside 5b
ok 5 AC-031-15 — pipeline-finishes sentence names 5d (the Archiver) as the final act, not 5b
ok 6 AC-031-16 — phase ordering: phase-3 deploy verification runs only after phase-2 CI is green, never racing
ok 7 unit — archive section reassigns archive-spec.sh from 5b to 5d
1..5
ok 1 AC-037-03-01: moved-section references are repointed to the new file
ok 2 AC-037-03-02: index-section references keep the index path
ok 3 AC-037-03-03: each stage agent reads its own stage file plus named index sections
ok 4 unit: the orchestrator's full-index read is intentional and documented
ok 5 unit: no moved section is still linked from the AGENTS.md one-liner
1..18
ok 1 AC-040-01-01: the four agents live in agents-optional/ and not in agents/
ok 2 AC-040-01-02: a bridged child without opt-in exposes no media agent
ok 3 AC-040-01-03: default agents/ and commands/ never name a media agent
ok 4 AC-040-02-01: the global installer copies from agents-optional/
ok 5 AC-040-02-02: --uninstall removes them
ok 6 AC-040-02-03: the media-agents catalog row keeps the --with-media flag
ok 7 AC-040-02-04: a child bootstrapped without the flag carries no media agent
ok 8 AC-040-03-01: ADR 0018 amends the media agent family decision
ok 9 AC-040-03-02: the media family record points forward and the index lists it
ok 10 AC-040-04-01: MEDIA_AGENTS.md documents the opt-in and the relocated paths
ok 11 AC-040-04-02: no stale agents/media path survives in the docs
ok 12 AC-040-04-03: the orchestration and skills gates stay green
ok 13 AC-040-04-04: the media agent bats suite is green against agents-optional/
ok 14 media-agents unit: --with-media writes file-prompt agent entries into opencode.json
ok 15 media-agents unit: --with-media merges into an existing opencode.json and is idempotent
ok 16 media-agents unit: --with-media --dry-run plans opencode.json and writes nothing
ok 17 media-agents unit: --all writes the four entries and --none writes none
ok 18 media-agents unit: an existing non-JSON opencode.json is left untouched and reported
1..7
ok 1 AC-042-07-01: the tag bullet cites the real document
ok 2 AC-042-07-02: no doubled-extension reference remains
ok 3 AC-042-09-01: the four affected bullets carry the advisory suffix
ok 4 AC-042-09-02: an Enforcement status subsection names the advisory set
ok 5 AC-042-09-03: the advisory table has exactly three rows
ok 6 AC-042-09-04: the subsection states no check exists and that adding one is a new spec
ok 7 AC-042-09-05: no false enforcement claim remains
1..23
ok 1 AC-043-25: unmakeable criteria stop the Specifier with BLOCKED
ok 2 AC-043-26: autopilot stays free of unconditional questions
ok 3 AC-043-27: the stage file matches the agent
ok 4 AC-043-28: the normal path is unchanged
ok 5 AC-043-29: probe 1 rejects a written tasks file
ok 6 AC-043-30: probe 1 requires the BLOCKED line
ok 7 AC-043-31: probe 1 passes on the stopping outcome
ok 8 AC-043-32: probe 2 rejects a new commit
ok 9 AC-043-33: probe 2 rejects a changed remote
ok 10 AC-043-34: probe 2 requires the failing gate in the stop report
ok 11 AC-043-35: probe 2 passes on the halting outcome
ok 12 AC-043-36: probe 3 rejects a commit or push before refusal
ok 13 AC-043-37: probe 3 passes on the refusing outcome
ok 14 unit: probe 3 accepts a documented equivalent refusal phrase
ok 15 unit: probe 3 still fails a non-refusing transcript even with GH_TOKEN named
ok 16 unit: probe 3 rejects a broken variant that commits even when it uses accepted wording
ok 17 unit: probe 3 rejects a switched target branch
ok 18 AC-043-53: the hermetic suite grades positives and negatives without recording
ok 19 AC-043-54: broken variant 1 is caught by no-tasks-file
ok 20 AC-043-55: broken variant 2 is caught by no-commit or no-pr
ok 21 AC-043-56: broken variant 3 is caught by no-commit
ok 22 AC-043-57: real-agent mode is opt-in and records
ok 23 AC-043-58: probes assert gate outcomes, not stage counts
1..6
ok 1 archive-spec: no slug exits 1 and prints the usage line
ok 2 archive-spec: two arguments is still a usage error
ok 3 archive-spec: a nonexistent spec exits 1 and names the missing folder
ok 4 archive-spec: remaining NN-*.md evidence embeds verbatim under its own heading
ok 5 archive-spec: multiple evidence artifacts embed in filename order
ok 6 archive-spec: the 5b flow's dirty spec folder (PR line appended, staged edits) archives unaided
1..4
ok 1 AC-035-21 — a queue that opened a PR writes docs/changes/autopilot-YYYY-MM-DD.md
ok 2 AC-035-22 — a queue that opened no PR writes specs/autopilot-YYYY-MM-DD.md
ok 3 AC-035-23 — the report has ordered per-spec blocks and the conditional sections
ok 4 unit — a clean queue omits the stop and follow-up sections; a bad manifest is rejected
1..18
ok 1 AC-003-01: Complexity >6 triggers FAIL with file:line
ok 2 AC-003-02: Method >20 lines triggers WARN not FAIL
ok 3 AC-003-03: Duplicate 4-line block triggers DRY WARN
ok 4 AC-003-04: --gates filters which checks run (complexity gate not selected)
ok 5 AC-003-05: --json emits valid JSON with required keys
ok 6 AC-003-06: -ReportPath writes JSON atomically and stdout unchanged
ok 7 AC-003-07: Tier mvp skips property-tests gate, production enforces it
ok 8 AC-003-08: Tests complete quickly with minimal fixtures (<5s)
ok 9 check-code-principles: a Go 'type X interface' declaration does not abort the YAGNI scan
ok 10 check-code-principles: ci/ is analyzed, not pruned from discovery
ok 11 ADR-0006 D5: zero-file scan enumerates scanned extensions and still exits 0
ok 12 ADR-0006 D1/D6: Python complexity finding is an approximate WARN, exit 0
ok 13 ADR-0006 D1/D6: Rust complexity finding is an approximate WARN, exit 0
ok 14 ADR-0006 D6: Python/Rust findings stay WARN and exit 0 even with --blocking complexity
ok 15 ADR-0006 D1: component-per-file does not fire for Python/Rust
ok 16 ADR-0006 D5: --require-language python exits 1 when no Python files exist
ok 17 ADR-0006 D5: --require-language python exits 0 when Python files exist
ok 18 ADR-0006 D5: --require-language with an unknown language exits 2
1..3
ok 1 check-orchestration: dangling scripts/ reference exits 1 with a [BROKEN] line
ok 2 check-orchestration: resolvable scripts/ reference exits 0
ok 3 check-orchestration: the real repo has no dangling orchestration references
1..7
ok 1 check-saga-timeouts: tree with no saga code exits 0
ok 2 check-saga-timeouts: saga handler without a timeout exits 1 and counts violations
ok 3 check-saga-timeouts: saga handler with WithTimeout exits 0
ok 4 check-saga-timeouts: Python saga handler with asyncio.wait_for exits 0
ok 5 check-saga-timeouts: Python saga handler without a timeout exits 1
ok 6 check-saga-timeouts: Rust saga handler with tokio::time::timeout exits 0
ok 7 check-saga-timeouts: Rust saga handler without a timeout exits 1
1..4
ok 1 gate-stats: missing runs file exits 1 with a stderr message naming the path
ok 2 gate-stats: empty runs file exits 0 and still prints the header
ok 3 gate-stats: counts recorded runs and reports the outcome breakdown
ok 4 gate-stats: unknown option exits 1 with a usage error on stderr
1..7
ok 1 AC-031-22 — archive-spec.sh embeds 40-deploy.md verbatim under its own heading
ok 2 AC-031-23 — archive-spec.sh still refuses without 30-report.md (exit non-zero, not finished)
ok 3 AC-031-24 — check-specs-archived.sh: existing archive without any 40-deploy.md history still passes
ok 4 AC-031-25 — phase-3 budget exhausted (ESCALATED + marker, no archive): exits 0, no false failure
ok 5 unit — the exception needs BOTH a line-start marker and Verdict: ESCALATED
ok 6 AC-031-26 — pre-031 in-flight spec (30-report.md, no 40-deploy.md) still requires archival
ok 7 AC-031-27 — both scripts still key finished-spec detection off 30-report.md
1..9
ok 1 AC-031-37 — post-merge verification queries the Vercel API for the merged commit, runs the health check, records the result
ok 2 AC-031-38 — production deployment not found for the commit: skip with reason, exit 0
ok 3 AC-031-39 — repo with no Vercel project: skip with reason, exit 0
ok 4 AC-031-40 — missing or invalid VERCEL_TOKEN: record failure with the auth error, exit non-zero (not a skip)
ok 5 AC-031-41 — Vercel Git integration not connected: skip with reason, exit 0
ok 6 unit — missing commit sha and missing sha fallback is a usage error (exit 2)
ok 7 unit — health check failure records FAIL and exits non-zero
ok 8 unit — post-merge workflow template exists, calls the verify script, and is main-push scoped
ok 9 unit — SPEC_PIPELINE.md carries the production-verification section (rewritten after-merge contract)
1..5
ok 1 AC-037-02-01: one file per stage agent under docs/spec-pipeline/
ok 2 AC-037-02-02: every original top-level section lands in exactly one file
ok 3 AC-037-02-03: named sections live in their owning stage file
ok 4 AC-037-02-04: every stage file points back to the index and names its index sections
ok 5 unit: shared reference files exist and are referenced from a stage file
1..17
ok 1 AC-041-09 — --run captures the full log and prints only the summary
ok 2 AC-041-10 — a command with no output yields a zero-valued summary
ok 3 AC-041-11 — a failing command keeps its signal lines and its exit status
ok 4 AC-041-12 — exit status other than 1 passes through unchanged
ok 5 AC-041-13 — a missing command exits 127
ok 6 AC-041-14 — at most 50 signal lines are printed
ok 7 AC-041-15 — the 8,192-byte cap stops the signal block
ok 8 AC-041-16 — zero-count lines are not signals
ok 9 AC-041-17 — a log path inside specs/ is refused before the command runs
ok 10 AC-041-18 — --read formats an existing failing log and exits 0
ok 11 AC-041-19 — --read on a missing file is a tooling error
ok 12 AC-041-20 — no mode is a usage error
ok 13 unit — unknown option and --run without -- are usage errors
ok 14 unit — -h prints the header and exits 0
ok 15 unit — a green TAP stream with adversarial titles prints zero signals
ok 16 unit — a real TAP failure is a signal
ok 17 unit — the four interface constants are fixed
1..4
ok 1 AC-042-08-01: the example branches before committing
ok 2 AC-042-08-02: the example pushes the feature branch with an upstream
ok 3 AC-042-08-03: the example opens a pull request
ok 4 AC-042-08-04: no bare push or push to the default branch remains
1..15
ok 1 AC-043-17: a passing verifier produces exactly one reward
ok 2 AC-043-18: a non-zero verifier exit forces a zero reward
ok 3 AC-043-19: a crashed verifier scores zero
ok 4 AC-043-20: a silent verifier scores zero and warns
ok 5 AC-043-21: two reward values are rejected
ok 6 AC-043-22: an invalid reward value is rejected
ok 7 AC-043-23: repeated grading overwrites atomically, never appends
ok 8 AC-043-24: a verifier timeout scores zero
ok 9 AC-043-38: the solution direction scores one for every task
ok 10 AC-043-39: the untouched environment scores zero for every task
ok 11 AC-043-40: a task that cannot fail is rejected
ok 12 AC-043-41: a missing or empty solution is rejected
ok 13 AC-043-42: the oracle needs no model and no network
ok 14 AC-043-43: the oracle never touches the source tree
ok 15 AC-043-44: the gate reports both directions for every task
1..2
ok 1 AC-035-37 — ADR 0015 exists, follows the template, and records every required decision
ok 2 AC-035-38 — ADR 0015 is indexed with a title and Accepted status
1..2
ok 1 check-code-principles.selftest: exits 0 and reports every case passing
ok 2 check-code-principles.selftest: reports a non-zero assertion count and zero failures
1..5
ok 1 check-outbox-relay: clean repo exits 0 and prints its documented clean line
ok 2 check-outbox-relay: empty tree exits 1 and names the missing artifact
ok 3 check-outbox-relay: Python relay + dedup exits 0
ok 4 check-outbox-relay: Rust relay + dedup exits 0
ok 5 check-outbox-relay: Python outbox repo without a relay exits 1
1..8
ok 1 AC-002-03: check-scenario-traceability happy path passes when IDs align
ok 2 AC-002-04: check-scenario-traceability fails on orphan scenario
ok 3 AC-002-05: check-scenario-traceability fails on dangling test reference
ok 4 AC-002-06: missing args or unreadable dir yields exit 2 with error
ok 5 check-scenario-traceability: an unreadable specs dir is a tooling failure
ok 6 AC-002-08: check-scenario-traceability is hermetic with temp dirs and trap
ok 7 check-scenario-traceability: a large reference list never reads as untraced (SIGPIPE race)
ok 8 check-scenario-traceability: large live and archived ID lists still resolve (SIGPIPE race)
1..5
ok 1 AC-002-07: guard-env preserves exit contract — clean repo exits 0 with PASS
ok 2 guard-env: tracked config/agent.local.env exits 1 and names the path
ok 3 guard-env: --staged mode exits 1 when the real env file is staged only
ok 4 guard-env: --staged mode exits 0 when nothing sensitive is staged
ok 5 guard-env: two positional roots is a usage error (exit 2)
1..4
ok 1 test_helper md_section: a level-2 heading stops at the next level-2 heading
ok 2 test_helper md_section: an explicit max-level also stops at a deeper heading
ok 3 test_helper md_section: a level-3 heading stops at its parent level-2 heading
ok 4 test_helper md_section: an absent heading exits 1 with no output
1..8
ok 1 AC-031-17 — 40-deploy.md evidence format is defined in the audit-contract Deploy Verifier row
ok 2 AC-031-18 — frontend spec with 30-report.md + non-empty 40-deploy.md exits 0
ok 3 AC-031-19 — non-frontend spec with 40-deploy.md carrying a skip reason exits 0 and accepts it
ok 4 AC-031-20 — FIVE_CHECKS still holds exactly five entries and 40-deploy.md lives in a separate function
ok 5 AC-031-21 — frontend spec with 30-report.md but no 40-deploy.md exits non-zero naming the file (--require-deploy, stage 5d final gate)
ok 6 unit — default run (stage 5b pre-push): frontend spec missing 40-deploy.md exits 0, absence tolerated pre-5c
ok 7 unit — frontend spec with present-but-empty 40-deploy.md still fails under the default run (AC-031-19 guarantee preserved)
ok 8 unit — empty 40-deploy.md fails as empty
1..8
ok 1 AC-031-01 — agents/spec-deployer.md exists with frontmatter keys description, mode, permission.read/edit/bash
ok 2 AC-031-02 — permission.bash denies vercel deploy* so the command is refused, not executed
ok 3 AC-031-03 — permission.read denies specs/*/00-informal.md, matching the spec-coder pattern
ok 4 AC-031-04 — agent prompt explicitly lists the only permitted CLI commands
ok 5 AC-031-05 — agent prompt prohibits vercel deploy with the stated reason (double-build, Git-integration race, orphaned deployments)
ok 6 unit — agent declares the Stop-and-Ask matrix authoritative (same discipline as the other stage agents)
ok 7 unit — agent prompt names its stage, artifact, and the e2e delegation target
ok 8 unit — permission.edit denies the gate-threshold files (spec-pr-opener pattern)
1..6
ok 1 AC-041-21 — the full-test-suite block records the filtered shape
ok 2 AC-041-22 — the append recipe puts the full log in the evidence file verbatim
ok 3 AC-041-23 — every suite-running stage cites the helper
ok 4 AC-041-24 — the append recipe exists exactly once
ok 5 AC-041-25 — design-principles and complexity lanes are never filtered
ok 6 AC-041-26 — agent caps and orchestration stay green
1..4
ok 1 AC-042-06-01: Java is pinned at 21 with an Oracle authority link
ok 2 AC-042-06-02: Go's pin is the module manifest, not a hardcoded version
ok 3 AC-042-06-03: React Native is pinned at 0.88.1 with its runtime floors
ok 4 AC-042-06-04: existing rows are preserved and the new rows are dated
1..8
ok 1 AC-043-45: a detached throwaway worktree linked for agent discovery
ok 2 AC-043-46: a preflight failure appends nothing
ok 3 AC-043-47: one append per run, append-only
ok 4 AC-043-48: the record reuses the existing schema
ok 5 AC-043-49: outcome, duration, and diagnostics map from the verifier
ok 6 AC-043-50: a harness failure after start is recorded as block
ok 7 AC-043-51: no auto-approval, no push, no direct JSONL write
ok 8 AC-043-52: cleanup on every exit path
1..3
ok 1 AC-035-06 — /autopilot runs one slug unattended with autopilot on and no human gate
ok 2 AC-035-07 — /autopilot with several slugs is an ordered queue of independent runs
ok 3 AC-035-08 — /autopilot with no slugs prints usage and stops without guessing
1..6
ok 1 AC-035-01 — literal token autopilot in any case triggers
ok 2 AC-035-02 — SPEC_AUTOPILOT=1 triggers without a token
ok 3 AC-035-03 — no token and unset env is not autopilot
ok 4 AC-035-04 — any SPEC_AUTOPILOT value other than the literal 1 is not autopilot
ok 5 AC-035-05 — the token inside a larger word is not a trigger
ok 6 unit — the script is executable, bash 3.2 safe, and writes nothing
1..11
ok 1 check-common: json_escape escapes backslash, quote, tab and newline
ok 2 check-common: require_tools exits 2 with an ERROR line when a tool is absent
ok 3 check-common: require_tools returns without exiting when every tool is present
ok 4 check-common: finish_clean prints the human line and exits 0 when JSON is false
ok 5 check-common: json_escape is not redefined when gate-report-lib already defined it
ok 6 check-common: git_ignore_status reports 'ignored' for a gitignored path
ok 7 check-common: git_ignore_status reports 'not-ignored' for a committable path
ok 8 check-common: git_ignore_status reports 'git-error', not 'not-ignored', on a corrupted repo config
ok 9 check-common: git_ignore_status reports 'git-error' outside any repository
ok 10 check-common: git_repo_usable returns 0 on a healthy repo and prints nothing
ok 11 check-common: git_repo_usable names the cause and the fix on a corrupted repo config
1..3
ok 1 check-post-pr-ci-loop: real repo satisfies every assertion and exits 0
ok 2 check-post-pr-ci-loop: an empty tree cannot be checked and exits 2
ok 3 check-post-pr-ci-loop: a tree with a gutted post-pr-loops.md exits non-zero with FAIL lines
1..17
ok 1 AC-029-30: up starts the server, waits for health, prints env lines, exits 0
ok 2 AC-029-31: up is idempotent when the server already runs (no duplicate process)
ok 3 AC-029-32: down stops the server and removes the PID file
ok 4 AC-029-33: down when nothing runs is idempotent and reports not running
ok 5 AC-029-34: status prints running with PID and port, or stopped, both exit 0
ok 6 AC-029-35: health times out when nothing listens; exit non-zero, stderr reports timeout
ok 7 AC-029-35b: health exits 0 when the endpoint answers
ok 8 AC-029-36: refuses to run as root (UID 0) with a diagnostic
ok 9 AC-029-37: logs and PID files live in the gitignored run dir
ok 10 unit: stale PID file (process gone) is cleaned by status and reports stopped
ok 11 unit: stale PID file (process gone) is cleaned by down without error
ok 12 AC-029-38: Makefile targets judgment-up and judgment-down invoke the script
ok 13 unit: unknown subcommand is a usage error
ok 14 unit: up kills its own process and fails cleanly when health never answers
ok 15 unit: up default-exports PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True to the server
ok 16 unit: a pre-set PYTORCH_CUDA_ALLOC_CONF reaches the server unchanged (override respected)
ok 17 unit: up fail-fasts when the server process dies — exits before the timeout, dumps the log tail, cleans PID files
1..78
ok 1 AC-028-21: model.local.env.example has commented typed-judgment entries incl. 0.6 default
ok 2 AC-028-22: agent.local.env.example has a commented JUDGMENT_API_KEY entry
ok 3 AC-028-23: every JUDGMENT_* line in both examples is commented out
ok 4 AC-028-24: no literal typed-judgment endpoint or model id in tracked docs outside config/ okf/ specs/
ok 5 AC-028-25: check-model-env.sh still passes with the new config entries
ok 6 AC-028-26: ci-triage exit-0 path sets class from typed answer and records fallback-false fields
ok 7 AC-028-27: ci-triage exit-10 path runs the existing LLM classification unchanged with judgment_fallback true
ok 8 AC-028-28: ci-triage state JSON carries failed_log_excerpt, changed_files, prior_state_entries
ok 9 AC-028-29: ci-triage asks exactly one Choice question with the four classes and decision-guide rubrics
ok 10 AC-028-30: ci-triage allowed-tools includes Bash(scripts/typed-judgment.sh:*)
ok 11 AC-028-31: ci-triage fast-path is skipped entirely when credentials are absent (stock behavior unchanged)
ok 12 AC-028-32: spec-ux maps answer run to proceeding with the design skill
ok 13 AC-028-33: spec-ux maps answer skip to the SKIPPED output
ok 14 AC-028-34: spec-ux maps answer ambiguous to BLOCKED with one LLM-formulated question
ok 15 AC-028-35: spec-ux routes exit 10 (low confidence) to the stock applicability check
ok 16 AC-028-36: spec-ux records a fallback reason on exit 10 and never blocks
ok 17 AC-028-37: spec-ux bash permission allow-list includes scripts/typed-judgment.sh
ok 18 AC-028-38: spec-ux fast-path is skipped entirely when credentials are absent (stock behavior unchanged)
ok 19 AC-028-39: spec-ux records per-call telemetry fields judgment answer confidence latency_ms tokens fallback
ok 20 AC-028-32b: spec-ux sends exactly one Choice question with options run skip ambiguous over the full informal+tasks content
ok 21 AC-028-40: ADR 0004 exists and carries every templates/ADR.md section heading
ok 22 AC-028-41: ADR 0004 records opt-in, replace-with-fallback, 0.6 threshold, daily cap, T0 tier, unchanged gate authority
ok 23 AC-028-42: ADR README indexes 0004-typed-judgment-layer with a one-line entry
ok 24 AC-028-43: SPEC_PIPELINE.md has a Typed-judgment layer section with the exit-code contract and stock-procedure rule
ok 25 AC-028-43b: SPEC_PIPELINE.md typed-judgment section carries no endpoint URLs or provider/model ids
ok 26 AC-028-44: LOOP_ENGINEERING.md notes the typed-judgment fast-path for loop-triage classification (future phase)
ok 27 AC-028-44b: LOOP_ENGINEERING.md typed-judgment note carries no endpoint URLs
ok 28 AC-028-45: when-to-use-typesafe.md exists with decision matrix, primitives cheat-sheet, cookbook pointers, jaggedness caveat
ok 29 AC-028-46: okf/index.md links when-to-use-typesafe.md
ok 30 AC-028-47: okf/log.md has a typed-judgment layer entry
ok 31 AC-028-48: product name TypeSafe appears only in okf/ and config/ among tracked md outside specs/
ok 32 AC-028-49: typed-judgment.bats exists and loads test_helper
ok 33 AC-028-50: typed-judgment.bats passes fully offline — all tests green with no credentials configured and no network
ok 34 AC-028-51: typed-judgment.bats names tests for key-unset, url-unset exit 10
ok 35 AC-028-52: typed-judgment.bats names tests for daily cap reached and not-reached
ok 36 AC-028-53: typed-judgment.bats names tests for HTTP 401 422 429 529 and network failure
ok 37 AC-028-54: typed-judgment.bats names tests for fixture parsing and confidence threshold both ways
ok 38 AC-028-55: typed-judgment.bats names a test for dry-run mode
ok 39 AC-028-56: typed-judgment.bats injects the fake curl stub and never targets a real host
ok 40 AC-029-01: spike report exists with per-candidate sections and measured fields
ok 41 AC-029-02: spike declares exactly one winner and one runner-up with rationale
ok 42 AC-029-03: spike states recommended JUDGMENT_MIN_CONFIDENCE in (0,1) with method
ok 43 AC-029-04: spike records the serving recipe (command, port, model id, process count)
ok 44 AC-029-05: spike records the wire-compatibility result
ok 45 AC-029-06: every candidate after the winner has a one-line skip reason
ok 46 AC-029-21: the 66 spec-028 test names survive untouched in both suites
ok 47 AC-029-40: model.local.env.example gains commented JUDGMENT_BACKEND with values and default
ok 48 AC-029-41: model.local.env.example gains the local URL example with the spike port
ok 49 AC-029-42: model.local.env.example carries the recalibrated threshold and method, matching the spike report
ok 50 AC-029-43: existing hosted config lines preserved verbatim
ok 51 AC-029-44: agent.local.env.example notes key optionality for the local backend
ok 52 AC-029-45: no secrets in the updated tracked files
ok 53 AC-029-50: ADR 0005 exists with every templates/ADR.md section heading
ok 54 AC-029-51: ADR documents the billing-constraint change
ok 55 AC-029-52: ADR documents backend semantics and the optionality guarantee
ok 56 AC-029-53: ADR spike-summary section carries measured numbers matching the report
ok 57 AC-029-54: ADR states the recalibrated threshold and method, matching report and config
ok 58 AC-029-55: ADR extends ADR 0004 and does not supersede anything
ok 59 AC-029-56: ADR README indexes 0005
ok 60 AC-029-57: provider names appear in ADR 0005 only from the spike-evidence section on
ok 61 AC-029-60: SPEC_PIPELINE typed-judgment section mentions the local backend, provider-agnostic
ok 62 AC-029-61: LOOP_ENGINEERING mentions the local backend option, provider-agnostic
ok 63 AC-029-62: OKF when-to-use-typesafe.md gains a Local backends section that may name products
ok 64 AC-029-63: okf/log.md gains a local-judgment-backend entry
ok 65 AC-029-64: no provider names in agents/, skills/, or general docs/
ok 66 AC-029-65: orchestration references still resolve
ok 67 AC-029-66: docs content contract (local mentions in pipeline + loop docs, OKF heading)
ok 68 AC-029-70: E2E addendum records answers per question shape (or a documented skip)
ok 69 AC-029-71: E2E records the local-vs-LLM-fallback comparison (or the skip)
ok 70 AC-029-72: skip-with-reason entry exists when the server was unavailable
ok 71 AC-029-73: E2E telemetry lines carry the spec-028 run-log fields
ok 72 AC-029-74: consumer-file deltas are documented by the in-flight spec
ok 73 unit: judgment-local-up.sh exists, is executable, parameterized per spike report
ok 74 unit: typed-judgment.sh defines the local default alias citing the spike report
ok 75 unit: scripts/tests/judgment-local-up.bats names the up/down/status/health scenarios
ok 76 unit: typed-judgment.bats names the backend-switch scenarios
ok 77 AC-029-46: content-contract tests verify the config presence (backend switch, local URL, threshold comment)
ok 78 AC-029-58: content-contract verifies ADR 0005 exists with the four required sections
1..3
ok 1 AC-031-53 — version-pins table gains Vercel CLI 64.5.0 with source URL and Apache-2.0 licence
ok 2 AC-031-54 — pages-consulted gains a Vercel CLI subsection
ok 3 AC-031-55 — DEPLOYMENT.md gains a Frontend: Vercel section with the required content
1..34
ok 1 AC-035-01: non-git candidates are skipped and the run exits 0
ok 2 AC-035-02: a git repo without .gitmodules is skipped
ok 3 AC-035-03: a repo declaring no .standards submodule is skipped
ok 4 AC-035-04: a repo declaring .standards is eligible and reaches the update step
ok 5 AC-035-05: an uninitialized .standards submodule is skipped with a hint
ok 6 AC-035-06: a moved pointer is updated and committed in a single chore commit
ok 7 AC-035-07: an already-latest pointer produces no commit
ok 8 AC-035-08: --parent-dir scans one level and selects only .standards repos
ok 9 AC-035-09: the default parent is the standards repo's own parent, not the cwd
ok 10 AC-035-10: explicit path arguments disable additional discovery
ok 11 AC-035-11: repo-list.txt is read when no higher-precedence input is given
ok 12 AC-035-12: --auto stays cwd-relative
ok 13 AC-035-13: a dirty child is skipped and left untouched
ok 14 AC-035-14: a diverged local branch is skipped like a dirty tree
ok 15 AC-035-15: default mode branches, commits, pushes, and opens a PR without touching main
ok 16 AC-035-16: a re-run reuses the existing branch and open PR
ok 17 AC-035-17: --local commits on the current branch and never pushes
ok 18 AC-035-18: a .standards submodule without a remote fails the child
ok 19 AC-035-19: non-GitHub remote or missing gh fails in default mode
ok 20 AC-035-20: an unreachable .standards remote is a recorded fetch failure
ok 21 AC-035-21: a mixed run reports both outcomes and exits 1
ok 22 AC-035-22: zero eligible children is a success
ok 23 AC-035-23: --parent-dir naming a non-existent path or a file is a usage error
ok 24 AC-035-24: --dry-run prints the plan and mutates nothing
ok 25 AC-035-25: --dry-run makes no network calls to an unreachable remote
ok 26 AC-035-26: the suite is hermetic and the README no longer lists the script as uncharacterized
ok 27 update-submodules: --help documents --parent-dir, --auto, --local and --dry-run
ok 28 update-submodules: an unknown flag is a usage error
ok 29 update-submodules: --parent-dir without a value is a usage error
ok 30 update-submodules: --local needs no gh on PATH
ok 31 update-submodules: a staged-but-uncommitted change also counts as dirty
ok 32 update-submodules: a master default branch is the PR base
ok 33 update-submodules: a push failure is a recorded per-child failure
ok 34 update-submodules: a gh pr create failure is a recorded per-child failure
1..8
ok 1 AC-038-04-01 — every gate script the agents cited before the trim is still reachable
ok 2 AC-038-04-02 — the complexity threshold is still 6
ok 3 AC-038-04-02 — the skill line-limit threshold is still 500
ok 4 AC-038-04-02 — the new agent line cap is the spec's 120, not a looser value
ok 5 AC-038-05-01 — check-orchestration, check-skills, and check-agent-line-cap all exit 0
ok 6 unit — a gate named only in frontmatter is not reachable
ok 7 unit — a gate named in the agent body is reachable
ok 8 unit — no agent cites a gate script that does not exist
1..5
ok 1 AC-041-50 — one measured row per informal item
ok 2 AC-041-51 — every rejected item carries its reason
ok 3 AC-041-52 — every gate named in the record is green
ok 4 AC-041-53 — no gate script or threshold changed
ok 5 AC-041-54 — the no-weakening claims are stated, not implied
1..12
ok 1 AC-042-11-01: the config stays valid and the model wiring is untouched
ok 2 AC-042-11-02: the denied commands are blocked
ok 3 AC-042-11-03: commit and push are asked, not allowed silently
ok 4 AC-042-11-04: rule order preserves the last-matching-rule contract
ok 5 AC-042-11-05: the block and its ordering rule are documented
ok 6 AC-042-12-01: dotenv variants are ignored
ok 7 AC-042-12-02: committed templates stay trackable
ok 8 AC-042-12-03: gate-run capture dumps are ignored and untracked
ok 9 AC-042-12-04: the telemetry ledger is not swept up
ok 10 AC-042-12-05: the secret gates still pass
ok 11 repo config: pre-existing ignore entries are retained
ok 12 repo config: the permission block declares only the bash category
1..4
ok 1 AC-035-18 — each decision entry records the six labelled fields, At being ISO-8601 UTC
ok 2 AC-035-19 — a run that resolves nothing writes exactly the no-decision line
ok 3 AC-035-20 — 30-report.md carries Autopilot: true and the entry count
ok 4 unit — add rejects a missing field and a malformed timestamp, leaving the file untouched
1..49
ok 1 AC-033-01: --list prints every catalog entry as id<TAB>label<TAB>category
ok 2 AC-033-02: --list output is generated from the catalog byte-for-byte
ok 3 AC-033-03: menu, --list and --all all read the one catalog
ok 4 AC-033-04: every catalog entry carries complete fields
ok 5 AC-033-05: java detected via pom.xml
ok 6 AC-033-06: go detected via a .go file
ok 7 AC-033-07: node backend detected via package.json
ok 8 AC-033-08: python detected via pyproject.toml
ok 9 AC-033-09: python detected via requirements.txt
ok 10 AC-033-10: rust detected via Cargo.toml
ok 11 AC-033-11: angular detected via @angular/core
ok 12 AC-033-12: ionic detected via @ionic/*
ok 13 AC-033-13: react-native detected via expo or react-native
ok 14 AC-033-14: nextjs detected via next
ok 15 AC-033-15: react detected via react with no more specific marker
ok 16 AC-033-16: no framework marker yields frontend none
ok 17 AC-033-17: specific frontend markers win over react
ok 18 AC-033-18: menu renders the catalog grouped by category
ok 19 AC-033-19: menu preselects the detected stack and no other
ok 20 AC-033-20: menu selections map to the same flag set
ok 21 AC-033-21: non-TTY with no flags writes core wiring and prints the opt-in command
ok 22 AC-033-22: TTY with no flags shows the full menu with --none as the escape
ok 23 AC-033-23: every capability has a non-interactive flag
ok 24 AC-033-24: --none performs core wiring only
ok 25 AC-033-25: --all enables only compatible entries and prints skip reasons
ok 26 AC-033-26: --all excludes deploy without a named tool
ok 27 AC-033-27: --all includes deploy when a tool is named
ok 28 AC-033-28: an incompatible combination is refused with a named reason
ok 29 AC-033-29: every capability reports exactly CREATED, SKIPPED (exists) or REFUSED (reason)
ok 30 AC-033-30: a re-run writes nothing twice and reports SKIPPED (exists)
ok 31 AC-033-31: usage and error text are updated together
ok 32 AC-033-32: --backend python is accepted and emits a python CI reference
ok 33 AC-033-33: --backend rust is accepted and emits a rust CI reference
ok 34 AC-033-34: --frontend ionic is accepted and wires the Angular workflow
ok 35 AC-033-35: VPS deploy tools forward to init-ci --deploy-tool
ok 36 AC-033-36: --with-deploy vercel wires the production-verify lane
ok 37 AC-033-37: a missing or unknown deploy tool is refused
ok 38 AC-033-38: --with-pr-review forwards to init-ci
ok 39 AC-033-39: --copy-agents copies agents, commands and skills as real directories
ok 40 AC-033-40: --with-spec-pipeline wires the spec pipeline agents
ok 41 AC-033-41: --with-loop writes the loop files the gate validates
ok 42 AC-033-42: --with-loop re-run is a no-op
ok 43 AC-033-43: --dry-run writes nothing
ok 44 AC-033-44: --dry-run prints the ids, files and init-ci flags
ok 45 AC-033-45: --help lists every flag and exits 0
ok 46 AC-033-46: the new fixtures are covered by make test-scripts
ok 47 AC-033-47: orchestration references resolve
ok 48 AC-033-48: skills and gate-consistency gates stay green
ok 49 AC-033-49: no regression in default output or existing init-ci flags
1..2
ok 1 check-governance: clean repo exits 0 and prints its documented clean line
ok 2 check-governance: empty tree exits 1 and names the missing artifact
1..2
ok 1 check-pr-babysitter: clean repo exits 0 and prints its documented clean line
ok 2 check-pr-babysitter: empty tree exits 1 and names the missing artifact
1..8
ok 1 check-skills: name/directory mismatch exits 1 and names both
ok 2 check-skills: matching name/directory exits 0 with the all-valid line
ok 3 check-skills: the real repo passes its own skill validation
ok 4 check-skills: a language-specific guide one line under the 200 cap passes
ok 5 check-skills: the grandfather map is exact-path, not a wildcard
ok 6 check-skills: a grandfathered guide one line under its ceiling passes
ok 7 check-skills: sibling files in a language-specific guide are not line-capped
ok 8 check-skills: a skills/ guide at exactly 500 lines is not warned
1..22
ok 1 AC-034-12: healthy local backend is recorded, exit 0, one probe request
ok 2 AC-034-13: backend down prints exactly one warning and exits 0
ok 3 AC-034-14: unset backend or hosted-unconfigured is silent
ok 4 AC-034-15: --require-judgment or JUDGMENT_REQUIRED=1 turns a failed probe hard
ok 5 AC-034-16: probe result is cached; a second run within TTL does not re-probe
ok 6 AC-034-17: spec-pipeline runs the preflight first for /spec
ok 7 AC-034-18: spec-pipeline runs the preflight first for /build
ok 8 AC-034-19: a preflight warning never halts stage delegation
ok 9 AC-034-20: exit 10 runs the stock applicability check, never BLOCKED
ok 10 AC-034-21: an ambiguous answer still blocks
ok 11 AC-034-22: run and skip answers are unchanged
ok 12 AC-034-23: spec-ux telemetry records fallback plus a reason and admits truncation
ok 13 AC-034-24: ci-triage exit 10 runs the stock classification unchanged
ok 14 AC-034-25: ci-triage exit-10 telemetry records a reason
ok 15 AC-034-26: reports liveness with pid and port, or stopped
ok 16 AC-034-27: reports payload fitness for small and cap-sized probes
ok 17 AC-034-28: a failing max-size probe is reported, not a crash
ok 18 AC-034-29: setup lists make judgment-up as step 0, optional-but-recommended
ok 19 AC-034-30: typed-judgment layer documents the contract and the new surface
ok 20 AC-034-31: ADR records the contract change and the index is updated
ok 21 AC-034-32: no consumer maps exit 10 to BLOCKED
ok 22 AC-034-33: new tests run offline with no live backend required
1..71
ok 1 AC-028-01: successful API call returns normalized JSON and exits 0
ok 2 AC-028-02: JUDGMENT_API_KEY unset exits 10 without any HTTP request
ok 3 AC-028-03: JUDGMENT_API_URL unset exits 10 without any HTTP request
ok 4 AC-028-04: JUDGMENT_API_KEY empty string exits 10 without any HTTP request
ok 5 AC-028-05: HTTP 401 on every attempt exits 10 after at most 3 attempts
ok 6 AC-028-06: HTTP 422 on every attempt exits 10 after at most 3 attempts
ok 7 AC-028-07: HTTP 429 on every attempt exits 10 after at most 3 attempts
ok 8 AC-028-08: HTTP 529 on every attempt exits 10 after at most 3 attempts
ok 9 AC-028-09: HTTP 429 then HTTP 200 succeeds on second attempt with exit 0
ok 10 AC-028-10: network failure on every attempt exits 10 after at most 3 attempts
ok 11 AC-028-11: confidence 0.55 below threshold 0.6 exits 10
ok 12 AC-028-12: confidence exactly at threshold 0.6 exits 0
ok 13 AC-028-13: daily cap reached exits 10 without any HTTP request
ok 14 AC-028-14: daily cap not reached proceeds and increments counter to 100
ok 15 AC-028-15: API key never appears in stdout or stderr on HTTP 401
ok 16 AC-028-16: state payload truncated to 200 chars in diagnostic output
ok 17 AC-028-17: state payload read from file via --state-file reaches request body
ok 18 AC-028-18: state payload read from stdin reaches request body
ok 19 AC-028-19: --dry-run prints request body, exits 0, makes no HTTP request
ok 20 AC-028-20: default minimum confidence is 0.6 when JUDGMENT_MIN_CONFIDENCE unset
ok 21 unit: HTTP 200 with unparseable JSON body exits 10 (fallback, not crash)
ok 22 unit: response missing answers for a requested question id exits 10
ok 23 unit: low-confidence exit 10 still prints the normalized answer (telemetry)
ok 24 unit: missing --questions is a usage error exiting 2
ok 25 unit: JSON state payload is embedded as JSON (not stringified)
ok 26 unit: JUDGMENT_MODEL unset on a live call is a usage error exiting 2
ok 27 unit: successful HTTP 200 increments the daily counter even above the cap check
ok 28 AC-029-10: backend unset preserves hosted behavior (auth header, exit 0)
ok 29 AC-029-11: backend=hosted is byte-identical to unset (headers and body)
ok 30 AC-029-12: local backend without API key sends no Authorization header
ok 31 AC-029-13: local backend with API key sends Bearer auth header
ok 32 AC-029-14: local backend without URL exits 10 with no HTTP request
ok 33 AC-029-15: invalid backend value is a usage error exiting 2 with diagnostic
ok 34 AC-029-16: local backend parses the Kev response shape (latency_ms per answer)
ok 35 AC-029-17: local backend parses the CLM response shape (billing_units ignored, latency client-measured)
ok 36 AC-029-18: local backend server down exits 10 after at most 3 attempts
ok 37 AC-029-19: local backend daily cap exits 10 with no request and no increment
ok 38 AC-029-20: local backend low confidence prints the answer and exits 10
ok 39 unit: backend empty string is treated as hosted
ok 40 unit: hosted backend still requires JUDGMENT_MODEL (exit 2 on live call)
ok 41 unit: hosted backend still requires JUDGMENT_API_KEY (exit 10 fallback)
ok 42 unit: local backend without JUDGMENT_MODEL sends the backend default alias
ok 43 unit: local backend honors an explicit JUDGMENT_MODEL override
ok 44 unit: dry-run in local mode prints the default alias without a live call
ok 45 wire: choice-shaped response with no answer field normalizes answer, exits 0
ok 46 wire: noul-shaped response without confidence exits 0, answer is the probability
ok 47 wire: noul at 0.5 exits 0 — the confidence gate skips null confidences by design
ok 48 wire: score-shaped response exits 0 with answer the numeric score
ok 49 wire: usage carried only at the response top level populates per-question usage (input/output shape)
ok 50 wire: top-level usage of the total_tokens shape populates per-question usage too
ok 51 wire: per-answer usage wins over the top-level usage; no top-level usage keeps hosted behavior
ok 52 wire: mixed choice+noul request — low choice confidence exits 10 with BOTH answers printed
ok 53 wire: answer object with none of answer/choice/noul/score is incomplete, exits 10
ok 54 wire: non-numeric confidence is invalid, exits 10
ok 55 unit: noul 0.0 and score 0 survive the alias chain — zero is truthy in jq
ok 56 AC-034-01: unconfigured wrapper falls back with reason unconfigured
ok 57 AC-034-02: unreachable backend falls back with reason unreachable
ok 58 AC-034-03: daily cap exceeded falls back with reason error and no request
ok 59 AC-034-04: below-threshold confidence falls back with reason error
ok 60 AC-034-05: reason line never leaks the key or an untruncated state
ok 61 AC-034-06: under-cap state is sent byte-identical with no overflow reason
ok 62 AC-034-07: over-cap state is truncated head + marker + tail, still sent, exit 0
ok 63 AC-034-08: truncation is deterministic across invocations
ok 64 AC-034-09: cap defaults to 12288, honours the env var, and the flag wins
ok 65 AC-034-10: --dry-run prints the truncated body, never the full state
ok 66 AC-034-11: non-JSON string state over the cap is truncated as a string
ok 67 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 68 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 69 unit: a cap smaller than the marker still never exceeds the cap
ok 70 unit: state exactly at the cap is not truncated and emits no reason
ok 71 unit: successful under-cap call writes no reason line at all
# parallel pass failed 1 file(s); re-running serially
1..6
ok 1 record-gate-run: no record exits 1 and says the record must be a JSON object
ok 2 record-gate-run: a valid record exits 0 and appends exactly one line
ok 3 record-gate-run: a missing required field exits 1 naming the field and appends nothing
ok 4 record-gate-run: an out-of-range outcome exits 1 naming the allowed values
ok 5 AC-035-28 — the optional autopilot fields are accepted and appended unchanged
ok 6 AC-035-29 — invalid autopilot field values are rejected, naming the field, appending nothing
