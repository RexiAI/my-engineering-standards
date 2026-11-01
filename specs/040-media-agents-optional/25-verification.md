# 040 — Media agents opt-in for child repos — Verification

- **Attempt:** 1 (first full run)
- **Phase:** 1 (pre-PR loop)
- **Verifier:** `spec-verifier`, stage 4
- **Repo:** `/home/dbueno/.local/share/opencode/worktree/471827/spec-040`
- **Change under test:** relocation of the four media agents `agents/` → `agents-optional/`,
  per-repo `--with-media` opt-in, ADR 0018, docs/test alignment.
- **Prior stages' claim:** Coder + Refactorer green, 754 tests.

## Verdict

**PASS** — every one of the five contract gates ran and produced no FAIL/BLOCK.
Six WARN-level findings are recorded below and flagged to the Architect; none is a
gate finding, and all are structural/documentation, not behavioral.

Verdict is transcribed from the gate exits, not from my reading of the diff.

---

## Evidence: scenario traceability

command: scripts/check-scenario-traceability.sh --json
exit: 0
at: 2026-11-01T12:34:45Z

```
{
  "checks": [1, 2],
  "passes": ["AC-040-01 — traced to a test", "AC-040-02 — traced to a test", "AC-040-03 — traced to a test", "AC-040-04 — traced to a test"],
  "fails": []
}
```

PASS. All four scenario files traced to tests; no dangling reference anywhere in the
repo for any spec number (check 2 resolves every `AC-NNN-NN` citation in test files
against the in-flight `specs/*/20-acceptance/` or an archived `docs/changes/*.md`).

---

## Evidence: full test suite

command: make test
exit: 0
at: 2026-11-01T12:34:56Z

```
2026-11-01T12:34:56Z
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 71 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..754
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
ok 2 AC-001-02: Failing bats test fails the target (not ok)
...
ok 198 AC-040-01-01: the four agents live in agents-optional/ and not in agents/
ok 199 AC-040-01-02: a bridged child without opt-in exposes no media agent
ok 200 AC-040-01-03: default agents/ and commands/ never name a media agent
ok 201 AC-040-02-01: the global installer copies from agents-optional/
ok 202 AC-040-02-02: --uninstall removes them
ok 203 AC-040-02-03: the media-agents catalog row keeps the --with-media flag
ok 204 AC-040-02-04: a child bootstrapped without the flag carries no media agent
ok 205 AC-040-03-01: ADR 0018 amends the media agent family decision
ok 206 AC-040-03-02: the media family record points forward and the index lists it
ok 207 AC-040-04-01: MEDIA_AGENTS.md documents the opt-in and the relocated paths
ok 208 AC-040-04-02: no stale agents/media path survives in the docs
ok 209 AC-040-04-03: the orchestration and skills gates stay green
ok 210 AC-040-04-04: the media agent bats suite is green against agents-optional/
ok 211 media-agents unit: --with-media writes file-prompt agent entries into opencode.json
ok 212 media-agents unit: --with-media merges into an existing opencode.json and is idempotent
ok 213 media-agents unit: --with-media --dry-run plans opencode.json and writes nothing
ok 214 media-agents unit: an existing non-JSON opencode.json is left untouched and reported
...
ok 753 unit: state exactly at the cap is not truncated and emits no reason
ok 754 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
EXIT=0
2026-11-01T12:41:24Z
```

PASS. Independently re-run. `ok` lines: 754. `not ok` lines: 0. `# skip` lines: 0 —
nothing was skipped or silently not run. Duration: 12:34:56Z → 12:41:24Z (6m28s).
The vacuous-assertion pre-gate (`check-bats-assertions.sh`) covers all 71 bats
files, including the two touched by this change.

---

## Evidence: complexity gate

command: scripts/check-code-principles.sh --gates complexity --json -BaseRef HEAD
exit: 0
at: 2026-11-01T12:41:58Z

```
{
  "tier": "mvp",
  "gates": ["complexity"],
  "fails": [],
  "warns": []
}
```

PASS for every file the gate scans. Language-level lint, same run window:

```
$ bash -n scripts/bootstrap-actions.sh
OK scripts/bootstrap-actions.sh
$ node --check scripts/media/install.mjs
OK scripts/media/install.mjs
$ node --check scripts/media/smoke-media.mjs
OK scripts/media/smoke-media.mjs
$ node --check scripts/media/merge-agent-entries.mjs
OK scripts/media/merge-agent-entries.mjs
$ shellcheck -S style scripts/bootstrap-actions.sh
In scripts/bootstrap-actions.sh line 23:
    "$STANDARDS_DIR/scripts/init-ci.sh" | head -1)
     ^------------^ SC2153 (info): Possible misspelling: STANDARDS_DIR may not be assigned. Did you mean STANDARDS_PIN?
shellcheck exit: 1
```

The single `shellcheck` finding is **pre-existing**, proven by re-running the tool
against `git show HEAD:scripts/bootstrap-actions.sh`: identical `SC2153` at the same
line 23. The diff's hunks are `@@ +272,40 @@` only. No new lint finding.

**Caveat — this gate does not cover `.mjs` (WARN W1, below).** The script's own
discovered extension set is `java, go, ts, tsx, js, jsx, py, rs, sh`. All three
`scripts/media/*.mjs` files are outside it. Verified empirically: a synthetic
violation in a `.mjs` file yields
`No source files found … scanned for extensions: java, go, ts, tsx, js, jsx, py, rs, sh`,
exit 0. Re-run with the same files renamed to `.js`, the gate does look — see W1/W2.

This repo has no PMD/golangci-lint/ESLint project config, so `bash -n`,
`node --check`, and `shellcheck` are the real per-language linters; `make lint`
(JSON/YAML) also exits 0.

---

## Evidence: design-principles gate

command: scripts/check-code-principles.sh --json -BaseRef HEAD
exit: 0
at: 2026-11-01T12:34:54Z

```
{
  "tier": "mvp",
  "gates": ["complexity", "dry", "yagni", "solid", "component-per-file", "property-tests", "comments", "naming", "null-discipline"],
  "fails": [],
  "warns": []
}
```

PASS. **No FAIL lines and no WARN lines were emitted** — the arrays are empty, so
there is nothing to transcribe verbatim. `-BaseRef HEAD` scopes the run to the
working-tree diff, so this is a judgement of *this change*, not of the whole tree.
Tier resolves to `mvp` (no property-test obligation at this tier, so the
`property-tests` gate is not a gap here).

Supporting repo-wide structural gates, all exit 0 in the same session:

```
scripts/check-orchestration.sh      → All orchestration references valid.            exit 0
scripts/check-skills.sh             → All SKILL.md files valid (1 warning(s)).        exit 0
scripts/check-governance.sh         → Governance check: every governance requirement verified. exit 0
scripts/check-no-hardcoded-secrets.sh → PASS, no hardcoded credential values.        exit 0
make validate-all                   → All validations passed.                        exit 0
make lint                           → Done.                                          exit 0
```

(`check-skills.sh`'s one warning is `skills/hallmark/SKILL.md — Body has 562 lines` —
pre-existing, untouched by this change.)

---

## Evidence: scenario-to-behavior spot check

command: bats --tap -f "AC-040-01-02|AC-040-02-04|AC-040-03-02" scripts/tests/ac-040-media-agents-optional.bats
exit: 0
at: 2026-11-01T12:36:51Z

```
1..3
ok 1 AC-040-01-02: a bridged child without opt-in exposes no media agent
ok 2 AC-040-02-04: a child bootstrapped without the flag carries no media agent
ok 3 AC-040-03-02: the media family record points forward and the index lists it
```

Three scenarios were read against their tests *and* against the live system, not
just checked for the presence of a passing test with the right ID:

**AC-040-01-02** — Given a child set up by `templates/Makefile.bridge` without
opt-in / When `.opencode/agents/` is listed / Then no `media-*.md` is present.
The test bootstraps `--none` in a hermetic child whose `.standards/` holds real
symlinks, asserts `.opencode/agents` *is* the bridge symlink, then runs
`find -L "$CHILD/.opencode/agents" -maxdepth 3 -name 'media-*.md'`. The `-L` is the
load-bearing detail: a plain `find` would stop at the symlink and pass vacuously;
following it is the only way to observe the real child agent set. **Assertions match
the scenario.**

**AC-040-02-04** — Given a child bootstrapped without `--with-media` / When its
`.opencode/` tree is searched / Then no `media-*.md` file *and* no media agent entry
exists. The test asserts both halves separately: `refute_media_under "$CHILD/.opencode"`
for the file, and `grep -q 'media-image' "$CHILD/opencode.json"` expected to fail for
the entry. Both halves are genuinely asserted, so a regression in either is caught.
**Assertions match the scenario.** (Coverage boundary — `--all` is not exercised here;
see W3.)

**AC-040-03-02** — Given `docs/adr/0007-media-agent-family.md` and
`docs/adr/README.md` / When read / Then 0007's `## Status` mentions 0016 and README
lists 0016. The test extracts the real `## Status` block with
`sed -n "/^## Status$/,/^## /p"` (not a whole-file grep, which would pass on an
unrelated mention) and asserts on that block; then greps `^\| 0016 ` in the index.
**Assertions match the scenario.**

I additionally verified AC-040-02's central behavior claim — that `--with-media`
actually makes the agents *loadable*, not merely that four JSON keys exist — against
real opencode v2.2.5. In an opted-in scratch child, `opencode debug config` resolves
`media-image`, `media-video`, `media-voice`, `media-producer` with their full
`system` prompts read from `.standards/agents-optional/*.md` (so `{file:…}` prompt
resolution works). In a `--none` child the same query resolves only the ten
`spec-*`/`pr-review` agents and zero media agents. Behavior confirmed end to end,
not just structurally.

---

## No unaccounted behavior

**None found.** Every hunk in the diff traces to a task or an acceptance scenario:

| Changed path | Traces to |
|---|---|
| `agents/media-*.md` → `agents-optional/media-*.md` (4 renames, content identical) | Task 1; AC-040-01-01 |
| `scripts/media/install.mjs` (`AGENT_SRC_DIR`) | Task 2; AC-040-02-01/02 |
| `scripts/capabilities.tsv` `media-agents` row (`information` → `media-agents`, target `opencode.json`) | Task 2; AC-040-02-03 |
| `scripts/bootstrap-actions.sh` `act_media_agents` + 3 helpers | Task 2, AC-040-02-04 + the human-gate answer to Q2 (option b) |
| `scripts/media/merge-agent-entries.mjs` (new) | Task 2 / Q2(b) — the writer `act_media_agents` calls |
| `scripts/media/smoke-media.mjs` (`AGENT_SRC_DIR`) | Task 1 consequence of the move |
| `scripts/tests/media-agents.bats` | Task 4; AC-040-04-04 |
| `scripts/tests/ac-040-media-agents-optional.bats` (new) | the 13 scenarios |
| `docs/MEDIA_AGENTS.md` | Task 4; AC-040-04-01 |
| `docs/adr/0018-media-agents-opt-in.md` (new) | Task 3; AC-040-03-01 |
| `docs/adr/0007-media-agent-family.md` (restored) | Task 3; AC-040-03-02 (see (a) below) |
| `docs/adr/0016-…md` Status + Notes pointer | ADR 0018's own Decision ("0016's placement sentence is superseded") |
| `docs/adr/README.md` rows 0007 + 0018 | Task 3 + `scripts/check-governance.sh` AC-010-05-05 ("indexes one ADR per file") — mandatory |

Two pieces of the change go slightly beyond the literal task text and are recorded
here rather than assumed fine: (i) restoring `0007`, and (ii) editing `0016`. Both
are resolved below.

---

## Scrutinised items

### (a) Restoring `docs/adr/0007-media-agent-family.md` — **defensible**

PR #106 deleted 0007. The Coder restored it as a superseded tombstone. Verdict:
required, not opportunistic, and correct against AC-040-03-*.

1. **The approved spec cannot be satisfied without it.** `AC-040-03-02`'s Given is
   literally *"Given `docs/adr/0007-media-agent-family.md` and `docs/adr/README.md`"*,
   and its Then requires that file's `## Status` to mention 0016. `AC-040-03-01`
   likewise requires 0018 to reference `0007-media-agent-family.md` — which would be
   a dangling link against a tree where 0007 does not exist. Task 3 repeats it
   ("ADR 0007 `## Status` line references 0016"). A missing 0007 makes the scenario
   unimplementable, so restoring it is the only conforming reading.
2. **The index row is mandatory, not editor's flourish.** `scripts/check-governance.sh`
   AC-010-05-05 enforces "`docs/adr/README.md` … indexes one ADR per file". Adding the
   file without the row would fail that gate; the run above is exit 0 precisely
   because both rows exist.
3. **Scope is honest.** The restored file defines no behavior
   ("Nothing here is in force"), carries a `Superseded by 0016 — amended by 0018`
   status, an explicit "Alternatives Considered: retaining versus removing a
   superseded record" paragraph, and a dated Notes trail that says it was reinstated
   on 2026-11-01. It is a pointer, not a reinstated decision.
4. **It does reverse a documentation choice made in #106.** #106 also rewrote 0016's
   Note to "the retired record is no longer indexed"; this change rewrites it to
   "(ADR 0007, retained as a superseded pointer)". That is a deliberate policy
   reversal — but of *documentation indexing*, not of any behavior #106 shipped, and
   it is what the approved spec mandates. Flagged for human review, not a defect.

`AC-040-04-02`'s exclusion of `docs/adr/0007-*` from the stale-path grep turns out to
be **vestigial**: I checked the pre-#106 version of 0007 and it contained zero
`agents/media-` references, as does the restored version. The exclusion is harmless
but no longer protects anything — noted so a later reader does not infer that 0007
still carries stale paths.

### (b) ADR numbering 0018 — **correct**

`git log` confirms the sequence: **0016** from `39fdd21` (#106, provider-agnostic
media agents), **0017** from `75d2780` (#107, pipeline single source of truth),
**0018** new in this change. `docs/adr/` contains exactly 0001–0018 with no gaps and
no duplicates; `check-governance.sh` AC-010-05-05 (one index row per ADR file) passes.
`0018` correctly amends 0007 and amends-without-superseding 0016's *contract*, while
superseding 0016's *placement* sentence — which 0016's own Status line now records.

---

## Warnings (review hints — recorded, not pipeline stops)

**W1 — the design-principles and complexity gates are blind to `.mjs`.** The gate
discovers `java, go, ts, tsx, js, jsx, py, rs, sh`; `.mjs` is not among them, and
`-name '*.js'` does not match `merge-agent-entries.mjs`. Three of this change's four
touched/added source files (`merge-agent-entries.mjs`, `install.mjs`,
`smoke-media.mjs`) were therefore **never analysed**, and the exit-0 PASS above is
silent about them. Proven: a synthetic `.mjs` file with a deliberate violation
reports `No source files found … none matched`. The same file renamed to `.js` is
analysed and flagged. The gate is not lying; its scope is narrower than the file set
this change ships. **Proposed follow-up spec:** add `mjs`/`cjs` to the discovered
extension set in `scripts/check-code-principles.sh` and to its self-test.

**W2 — pre-existing cyclomatic complexity 7 in a changed file.** With `.mjs` renamed
to a scanned extension, the gate reports
`FAIL Cyclomatic complexity >6 (node): install.js:36:46:ensureDir:CC=7`. This is
**pre-existing debt, not introduced here**: the same finding appears at
`install.js:32:42` when the probe is run against `git show HEAD:scripts/media/install.mjs`,
and the `install.mjs` diff hunks are at lines 7, 49, 64 — `ensureDir` is untouched.
Classified WARN per the gate's own blame rule ("a finding in a touched file without
overlap is pre-existing debt"). Consequence for the Architect: **the Refactorer's
"complexity ≤6" claim holds only for gate-scanned extensions**, so it is not a
derivation from a green gate for `.mjs`. `merge-agent-entries.mjs` and
`smoke-media.mjs` are clean at ≤6 under the same probe. Fix is out of scope for this
stage; propose a follow-up with W1.

**W3 — AC-040-02-04 does not cover `--all`, and ADR 0018's Compliance bullet
overstates it.** `--all` previously skipped `media-agents` because its action was
`information` (`bootstrap.sh:141`); with the action now `media-agents`, `--all`
selects the row. Verified live: `bootstrap.sh --all` writes the four `agent.*` entries
(preserving the existing ten, idempotent on re-run, nothing written under
`.opencode/`), and `--all --dry-run` prints `CREATED media-agents: opencode.json`.
ADR 0018 documents this correctly under Consequences ("`--all` selects the row like
any other non-baseline capability; the family is still never part of a default
(flagless) run"). But its **Compliance** bullet then claims a test covers "a child
bootstrapped without the flag carries neither file nor entry" — true for `--none`,
**false for `--all`**, which is also "without the flag". The bats test exercises
`--none` only. `AC-040-02-04`'s When clause ("its `.opencode/` tree is searched") is
what keeps this from being a violation, since nothing media-shaped lands under
`.opencode/` in either mode. Recommendation for the Architect: either (i) narrow the
Compliance bullet to "without the flag or `--all`", or (ii) add a `--all` case to
`ac-040-media-agents-optional.bats` asserting the documented behavior. Documentation
accuracy and test-coverage gap only — deliberately **not** raised as a behavioral
FAIL, because the ADR's Consequences section states the real contract and no AC is
contradicted.

**W4 — `10-tasks.md` carries the wrong spec number.** Line 1 reads
`# 035 — Media agents opt-in for child repos — Tasks` in a `specs/040-*/` folder.
Spec 035 is already merged (`75d2780`, autopilot mode). Spec-artifact typo only;
`check-audit-trail.sh` keys off file presence and scenario headings, so nothing
breaks. Worth correcting before the archive one-pager copies the heading.

**W5 — `check-orchestration.sh` no longer covers the media agents.** The script scans
`agents/*.md` and `commands/*.md` at `maxdepth 1`, so relocating the family to
`agents-optional/` removes it from the reference check. Task 1 *requires* that
`agents/` and `commands/` name no media agent, so the Specifier accepted this
trade-off, and both gates exit 0 as Task 4 demands. The loss is real but small: the
agents' only doc reference is `docs/MEDIA_AGENTS.md` (which exists, and is asserted by
`media-agents.bats`). **Proposed follow-up spec:** add `agents-optional/` to the
orchestration scan set.

**W6 (pre-existing, unrelated) —** `check-skills.sh` WARNs on
`skills/hallmark/SKILL.md` (562 lines > 500). Untouched by this change; recorded only
so the WARN in the evidence block is not mistaken for a finding of this stage.

---

## Out-of-scope findings — recorded, not fixed

- `scripts/check-code-principles.sh` does not scan `.mjs`/`.cjs` (W1) — follow-up spec.
- `scripts/media/install.mjs:36 ensureDir` is CC=7 (W2) — follow-up spec, pre-existing.
- `scripts/check-orchestration.sh` does not scan `agents-optional/` (W5) — follow-up spec.

None of these was edited by this stage. The Verifier writes no production code.

---

## Behavior-vs-structural classification of findings

| Finding | Class | Route |
|---|---|---|
| W1 `.mjs` gate blind spot | **Structural** (tooling coverage) | follow-up spec; not Coder/Refactorer work in this spec |
| W2 pre-existing CC=7 `ensureDir` | **Structural** (complexity) | follow-up spec; would route to `spec-refactorer` if adopted |
| W3 `--all` / Compliance overstatement | **Structural** (documentation + test coverage) | Architect decision |
| W4 stale `035` heading | **Structural** (spec artifact) | correct before archive |
| W5 orchestration scan gap | **Structural** (tooling coverage) | follow-up spec |
| W6 hallmark length WARN | **Structural**, unrelated | none |

**No behavioral findings.** Nothing in this change contradicts a scenario's
Given/When/Then; the live `opencode debug config` check confirms the opt-in mechanism
actually loads the agents and that a default child loads none.

---

## Budget

- Attempt 1, phase 1. No BLOCK, no FAIL, so no remediation round was consumed.
- `SPEC_LOOP_COUNT=1`, `SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`.
- Phase-1 budget after this run: 0 of 3 used.
