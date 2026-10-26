# Verification: 034-judgment-preflight-fail-open

- Attempt: 1 (first full run), phase 1
- Branch: `spec/034-judgment-preflight-fail-open` (dirty working tree, uncommitted)
- Base ref: `main` (6eb2c99)
- Verifier scope: re-execute every Coder/Refactorer claim; no production code written.

The two script gates below are transcribed verbatim (exit code + JSON), per the
script-is-authority rule. Where the design-principles gate was run both
unscoped and blame-scoped (`-BaseRef main`), the blame-scoped run is the
verdict for this change set; the unscoped run's pre-existing FAIL is out of
scope and flagged, not a pipeline stop.

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-10-26T02:38:12Z

```
{
  "checks": [1, 2],
  "passes": ["AC-034-01 — traced to a test", "AC-034-02 — traced to a test", "AC-034-03 — traced to a test", "AC-034-04 — traced to a test", "AC-034-05 — traced to a test", "AC-034-06 — traced to a test", "AC-034-07 — traced to a test", "AC-034-08 — traced to a test", "AC-034-09 — traced to a test", "AC-034-10 — traced to a test", "AC-034-11 — traced to a test", "AC-034-12 — traced to a test", "AC-034-13 — traced to a test", "AC-034-14 — traced to a test", "AC-034-15 — traced to a test", "AC-034-16 — traced to a test", "AC-034-17 — traced to a test", "AC-034-18 — traced to a test", "AC-034-19 — traced to a test", "AC-034-20 — traced to a test", "AC-034-21 — traced to a test", "AC-034-22 — traced to a test", "AC-034-23 — traced to a test", "AC-034-24 — traced to a test", "AC-034-25 — traced to a test", "AC-034-26 — traced to a test", "AC-034-27 — traced to a test", "AC-034-28 — traced to a test", "AC-034-29 — traced to a test", "AC-034-30 — traced to a test", "AC-034-31 — traced to a test", "AC-034-32 — traced to a test", "AC-034-33 — traced to a test"],
  "fails": []
}
```

Verdict: PASS — all 33 AC-034 scenario IDs traced to a test; every reference
resolves; no untraced behavior.

---

## Evidence: full test suite

command: make test-scripts   (run twice, as required)
exit: 0
at: 2026-10-26T02:38:38Z

Run 1 — `make test-scripts` exit 0, TAP plan `1..524`, 0 `not ok`. Run 2 —
`make test-scripts` exit 0, TAP plan `1..524`, 0 `not ok`. Representative
excerpt (run 1 tail, the new spec-034 tests):

```
ok 327 AC-034-12: healthy local backend is recorded, exit 0, one probe request
ok 328 AC-034-13: backend down prints exactly one warning and exits 0
ok 329 AC-034-14: unset backend or hosted-unconfigured is silent
ok 330 AC-034-15: --require-judgment or JUDGMENT_REQUIRED=1 turns a failed probe hard
ok 331 AC-034-16: probe result is cached; a second run within TTL does not re-probe
ok 332 AC-034-17: spec-pipeline runs the preflight first for /spec
ok 333 AC-034-18: spec-pipeline runs the preflight first for /build
ok 334 AC-034-19: a preflight warning never halts stage delegation
ok 335 AC-034-20: exit 10 runs the stock applicability check, never BLOCKED
ok 336 AC-034-21: an ambiguous answer still blocks
ok 337 AC-034-22: run and skip answers are unchanged
ok 338 AC-034-23: spec-ux telemetry records fallback plus a reason and admits truncation
ok 339 AC-034-24: ci-triage exit 10 runs the stock classification unchanged
ok 340 AC-034-25: ci-triage exit-10 telemetry records a reason
ok 341 AC-034-26: reports liveness with pid and port, or stopped
ok 342 AC-034-27: reports payload fitness for small and cap-sized probes
ok 343 AC-034-28: a failing max-size probe is reported, not a crash
ok 344 AC-034-29: setup lists make judgment-up as step 0, optional-but-recommended
ok 345 AC-034-30: typed-judgment layer documents the contract and the new surface
ok 346 AC-034-31: ADR records the contract change and the index is updated
ok 347 AC-034-32: no consumer maps exit 10 to BLOCKED
ok 348 AC-034-33: new tests run offline with no live backend required
ok 509 AC-034-01: unconfigured wrapper falls back with reason unconfigured
ok 510 AC-034-02: unreachable backend falls back with reason unreachable
ok 511 AC-034-03: daily cap exceeded falls back with reason error and no request
ok 512 AC-034-04: below-threshold confidence falls back with reason error
ok 513 AC-034-05: reason line never leaks the key or an untruncated state
ok 514 AC-034-06: under-cap state is sent byte-identical with no overflow reason
ok 515 AC-034-07: over-cap state is truncated head + marker + tail, still sent, exit 0
ok 516 AC-034-08: truncation is deterministic across invocations
ok 517 AC-034-09: cap defaults to 12288, honours the env var, and the flag wins
ok 518 AC-034-10: --dry-run prints the truncated body, never the full state
ok 519 AC-034-11: non-JSON string state over the cap is truncated as a string
ok 520 unit: invalid --max-state-bytes values are usage errors (exit 2, no request)
ok 521 unit: invalid JUDGMENT_MAX_STATE_BYTES is a usage error (exit 2)
ok 522 unit: a cap smaller than the marker still never exceeds the cap
ok 523 unit: state exactly at the cap is not truncated and emits no reason
ok 524 unit: successful under-cap call writes no reason line at all
```

Verdict: PASS — 524 tests, 0 failures, twice. No skipped/disabled tests.

---

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity -BaseRef main --json
exit: 0
at: 2026-10-26T02:48:55Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

Note on the "real linter": this change set contains no Go/Java/JS/Python/Rust
source — changed files are `Makefile`, `.sh`, `.bats`, `.md`, and one
`config/model.local.env.example`. `golangci-lint`/PMD/ESLint have no targets
(no `go.mod` in the repo). The cyclomatic-complexity heuristic in
`check-code-principles.sh` (this repo's authoritative complexity gate) reports
zero FAILs scoped to the diff. Refactorer's "no new complexity" claim holds.

Verdict: PASS.

---

## Evidence: design-principles gate

command: scripts/check-code-principles.sh -BaseRef main --json
exit: 0
at: 2026-10-26T02:38:32Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests"],
  "fails": [],
  "warns": []
}
```

For completeness, the unscoped whole-repo run
(`scripts/check-code-principles.sh --json`, exit 1) reports exactly one FAIL,
verbatim:

```
{ "message": "Cyclomatic complexity >6 (node): ./skills/hallmark/site/examples/cobalt-01/script.js:7:90::CC=10", "file": "./skills/hallmark/site/examples/cobalt-01/script.js", "line": "7" }
```

That file is not in this change set (`git diff` does not touch it) and is a
pre-existing whole-repo debt, not introduced by spec 034. The blame-scoped
run (`-BaseRef main`) is the verdict for this change set: zero FAILs, zero
WARNs. Flagging the pre-existing FAIL to the Architect as out-of-scope debt.

Verdict: PASS (scoped to the change set).

---

## Evidence: scenario-to-behavior spot check

command: manual inspection of agents/spec-ux.md, scripts/typed-judgment.sh, scripts/judgment-preflight.sh against AC-034-07, AC-034-13, AC-034-20, AC-034-21
exit: 0
at: 2026-10-26T02:48:55Z

Checked four scenarios at random/representative spread and confirmed the test
assertions match the Given/When/Then, not merely that a same-named test exists:

- AC-034-20 (exit 10 runs stock applicability check, never BLOCKED): the test
  asserts `grep_file "$SPEC_UX" '\*\*exit 10\*\*' 'Applicability check \(first
  action, always\)'` plus a branch extraction that must NOT contain `BLOCKED`.
  I read `agents/spec-ux.md` lines 72-78 directly: the exit-10 branch routes to
  `# Applicability check (first action, always)` and records `fallback:true` +
  reason. Matches. The only `BLOCKED` emissions in the file are exit-0
  `ambiguous` (line 66) and the constraint line 209. Match confirmed.
- AC-034-21 (ambiguous answer still blocks): test asserts `"ambiguous"` +
  `BLOCKED —`. File line 66 emits `BLOCKED — <one question>` only for exit-0
  `ambiguous`. Matches.
- AC-034-07 (over-cap state truncated head + marker + tail, still sent, exit 0):
  test asserts `state_text` ≤ 12288 bytes, head-prefix, tail-suffix, marker,
  `payload_overflow`, one request, exit 0. I reproduced manually: a 25,030-byte
  state (newline-stripped) truncates to exactly 12,288 bytes, head
  `HEAD-012345678` prefix preserved, tail `TAIL-9876543210` suffix preserved,
  marker `[truncated: 12780 bytes omitted]`, stderr `reason=payload_overflow`
  + `truncated original_bytes=25030 cap_bytes=12288`, deterministic across two
  runs. Matches.
- AC-034-13 (backend down prints exactly one warning, exit 0): test asserts one
  stderr line containing `make judgment-up`, `continuing without`, and
  `unreachable`. I reproduced manually against a dead port: exactly one line,
  exit 0. Matches.

Verdict: PASS.

---

## Specific judgments requested

### Exit-10 contract (spec-ux) — PASS

Static assertion re-run by hand: `grep` across `agents/*.md` and
`skills/*/SKILL.md` finds exactly two consumers of the fast-path —
`agents/spec-ux.md` and `skills/ci-triage/SKILL.md` (Task 6's "only two"
claim holds). Neither maps `exit 10` to `BLOCKED`:

- `spec-ux.md` line 72-78: exit 10 → run `# Applicability check (first action,
  always)`, record `fallback:true` + reason, "do not halt the pipeline".
- `ci-triage/SKILL.md` line 103+: exit 10 → run the existing LLM classification
  procedure unchanged, never a block/escalation.

`BLOCKED` remains exclusively the exit-0 + `ambiguous` outcome. No drift.

### Fail-open preflight — PASS

With the live local backend running (`kev: running (pid 1361883, port 8009)`,
left untouched — unreachability was simulated via a dead port, never by killing
the server):

- Healthy (live backend 8009): `judgment-preflight: healthy (…)` exit 0.
- Unreachable (dead port): exactly one stderr line
  `judgment-preflight: local judgment backend unavailable (reason: unreachable)
  — continuing without the typed-judgment fast-path; run \`make judgment-up\` to
  start it`, exit **0** (fail-open).
- Silent (backend unset / hosted-unconfigured): exit 0, no output.
- `--require-judgment`: same warning, exit **1**.
- `JUDGMENT_REQUIRED=1`: same warning, exit **1**.

`/spec` and `/build` therefore proceed with exactly one warning and exit 0 when
the backend is down; strictness is opt-in. Matches AC-034-12…16.

### Payload cap / truncation — PASS (threshold claim: UNVERIFIED)

- Deterministic truncation at 12,288 bytes confirmed by hand: head + marker +
  tail, marker names the omitted byte count, result exactly 12,288 bytes,
  byte-identical across two runs.
- Telemetry confirmed: stderr carries `typed-judgment: reason=payload_overflow`
  then `typed-judgment: truncated original_bytes=25030 cap_bytes=12288`.
- "Usable truncated answer ⇒ fallback:false" is the documented + unit-tested
  contract (AC-034-07 exits 0 with a usable mock answer; both consumer files
  record `"truncated":true` + `"original_bytes":<n>` with `fallback:false`).
  The live backend returned a below-threshold answer on my synthetic garbage
  state (exit 10 `reason=error`), which is correct — the fallback was the low
  confidence, not the truncation.
- Crash-threshold claim (20,547 ok / 20,548 fail): **UNVERIFIED**. Recorded as a
  live bisection in ADR 0012 §Notes and §Context, but not independently
  re-measurable by me: the wrapper now caps every payload at 12,288 bytes
  before the request, so the pre-cap crash cannot be reproduced through the
  wrapper, and sending a raw oversized request directly would risk the running
  backend (which I was instructed not to kill). The cap is 8,260 bytes below
  the lowest measured failure, so it is safe regardless.

### Test amendments (AC-028-35, AC-028-36, AC-029-74) — PASS (reflect new contract)

- AC-028-35 before: `grep_file "$AGENT" 'exit 10' 'BLOCKED'` (asserted the
  defect). After: asserts `exit 10` → `Applicability check` and that the branch
  does NOT contain `BLOCKED`. Corrects the assertion to the fixed contract —
  the old test encoded the exact defect this spec fixes.
- AC-028-36 before: `grep_file "$AGENT" 'fallback' 'BLOCKED'` (asserted the
  defect). After: asserts fallback telemetry carries `"reason"` +
  `unconfigured`/`unreachable` and never blocks. Corrects the assertion.
- AC-029-74 before: `[ -z "$(git diff HEAD -- skills/ci-triage/SKILL.md
  agents/spec-ux.md)" ]` ("consumer files equal HEAD", a spec-029-only delta
  assertion). After: allows a non-empty delta only while spec 034 is in flight
  AND ADR 0012 is present, else still fails. This re-scopes the assertion to the
  documented-change rule (ADR 0012 Decision 6) — a legitimate, necessary
  amendment, since spec 034 must edit both files and ADR 0009's AC-024-01-12
  requires the ADR. Not a weakening of coverage; it preserves the "undocumented
  consumer-file edits fail" guard. Minor note (flag, not FAIL): it hardcodes the
  spec-034 / ADR-0012 escape hatch, so a future spec editing consumer files
  must amend it again.

### ADR 0012 / 0011 — PASS

- `docs/adr/0012-judgment-consumer-contract-fail-open-preflight.md` exists, is
  `Accepted`, follows the `templates/ADR.md` heading set (Title/Status/Context/
  Decision/Consequences/Compliance/Notes, plus Alternatives Considered).
- `docs/adr/README.md` index gains the `| 0012 | … | Accepted |` row.
- `scripts/check-pr-review.sh` AC-024-01-12 PASSes: "change set modifies
  agents/spec-*.md as a documented pipeline change — the same change set adds
  or modifies a docs/adr/*.md record". Governance requirement satisfied.
- `docs/adr/0011*` does not exist; no 0011 index row. 0011 remains
  reserved/untouched (ADR 0012 §Notes: "0011 is reserved by the unmerged PR
  #99").
- `scripts/check-governance.sh` exit 0.

### No live-backend dependency in tests — PASS

New/changed bats tests use the injected fake-curl transport (`BIN/curl`,
`MOCK_CURL_*`). The strings `make judgment-up` and `localhost:8009` appear only
inside content assertions (the warning substring, the docs/`model.local.env.example`
comment contract), never as a real invocation. AC-034-33 asserts this and
passes. `scripts/tests/test_helper.bash` now unsets the full `JUDGMENT_*` set
for a hermetic baseline. Both `make test-scripts` runs passed offline.

---

## No unaccounted behavior

- `scripts/check-post-pr-ci-loop.sh` AC-014-04-09 was amended to allow exactly
  `scripts/judgment-preflight.sh` in the orchestrator (`agents/spec-pipeline.md`)
  while keeping the blanket `scripts/` ban for every other reference. This is
  not a numbered task in `10-tasks.md`, but it is documented in ADR 0012 §Notes
  and is a required consequence of Task 4's wiring (the orchestrator now runs
  the preflight). Verified: `scripts/check-post-pr-ci-loop.sh .` exits 0 with
  "no 'scripts/' in agents/spec-pipeline.md outside the allowed
  judgment-preflight invocation (spec 034)". Accounted for.
- `scripts/tests/test_helper.bash` (hermetic `JUDGMENT_*` unset expansion) traces
  to AC-034-33. Accounted for.
- No other diff hunks lack a task/scenario/ADR trace.

---

## Overall verdict: PASS

Every gate ran and produced no findings against this change set. The only FAIL
in any run is a pre-existing, out-of-scope whole-repo complexity violation
(`skills/hallmark/site/examples/cobalt-01/script.js`), which the blame-scoped
gate correctly excludes. The crash-threshold measurement is recorded but not
independently re-verifiable without risking the live backend; it is flagged to
the Architect, not blocking. Architect may proceed.
