# 040-media-agents-optional

> Spec pipeline archive. Original source: `specs/040-media-agents-optional/` (deleted by this script).
> Archived: 2026-11-01

## Original ask

# Make media agents opt-in for child repos

Problem: agents/media-{image,video,voice,producer}.md ship to every child repo via the .standards submodule, adding unrelated agents to every engineering session's agent list (token + selection noise). ADR 0007 (docs/adr/0007-media-agent-family.md) deliberately added them, so this is NOT a deletion.

Want: media agents stay in this repo but are not loaded by default in child repos; a child opts in explicitly (e.g. an init flag or documented opencode.json snippet). Supersede/amend ADR 0007 with the rationale. scripts/tests/media-agents.bats, scripts/capabilities.tsv and docs/MEDIA_AGENTS.md stay consistent. check-orchestration.sh and check-skills.sh stay green.

## Tasks

# 040 — Media agents opt-in for child repos — Tasks

Context (facts from repo, not requirements): child repos receive agents via
`templates/Makefile.bridge`, which symlinks (or `COPY_AGENTS=1` copies) the whole
`.standards/agents` directory to `.opencode/agents`. Any file under `agents/` is
therefore loaded in every child session. `scripts/media/install.mjs` already
copies media agents to the opencode global dir (`~/.config/opencode/agents/`).
`scripts/check-orchestration.sh` scans only `agents/*.md` and `commands/*.md`
(maxdepth 1).

Design decision taken by Specifier (see Open question Q1): relocate the four
media agent files from `agents/` to a new top-level directory `agents-optional/`.
Because the bridge links only `agents/`, they leave the default child set without
being deleted. Opt-in = the existing installer (global) or the per-repo
`--with-media` capability.

## Task 1 — Relocate media agents out of the default agent set
- `agents-optional/media-image.md`, `media-video.md`, `media-voice.md`, `media-producer.md` exist; content unchanged except path references.
- None of `agents/media-image.md`, `agents/media-video.md`, `agents/media-voice.md`, `agents/media-producer.md` exists.
- No file in `agents/` or `commands/` names `media-image`, `media-video`, `media-voice`, or `media-producer`.
- `templates/Makefile.bridge` is unchanged in what it links (`.standards/agents` only); nothing under it references `agents-optional`.
- Scenarios: AC-040-01.

## Task 2 — Opt-in mechanisms
- `scripts/media/install.mjs` reads source files from `agents-optional/` (not `agents/`); install and `--uninstall` still target `~/.config/opencode/agents/media-*.md`.
- `scripts/capabilities.tsv` `media-agents` row keeps flag `--with-media`; its description/target text no longer implies default loading.
- When a child repo is bootstrapped with `--with-media`, the four media agents become loadable in that repo per the mechanism documented in `docs/MEDIA_AGENTS.md` (see Q2); without the flag, no media agent file is placed under the child's `.opencode/`.
- Scenarios: AC-040-02.

## Task 3 — ADR amendment
- New ADR `docs/adr/0018-media-agents-opt-in.md` exists, status `Accepted`, with sections Context, Decision, Consequences, and states it amends ADR 0007.
- ADR 0007 `## Status` line references 0016 (e.g. "Amended by 0016").
- `docs/adr/README.md` index lists 0016.
- Scenarios: AC-040-03.

## Task 4 — Docs and tests consistent
- `docs/MEDIA_AGENTS.md` component table paths point to `agents-optional/…`; it contains a section stating media agents are not loaded by default in child repos and describes both opt-in paths (global installer, `--with-media`).
- `docs/GOVERNANCE.md` contains no `agents/media-*` path.
- `scripts/tests/media-agents.bats` checks files under `agents-optional/`; adds a test asserting no `agents/media-*.md` exists; all its tests pass under `make test`.
- `scripts/check-orchestration.sh` exits 0 and `scripts/check-skills.sh` exits 0 on the repo.
- Scenarios: AC-040-04.

## Open questions
- **Q1 (non-blocking, default chosen):** directory name/location `agents-optional/`. Alternative: `agents/optional/` subdir — rejected because whether opencode loads nested agent subdirs is unverified. Human may rename at review.
- **Q2 (needs answer before /build):** per-repo `--with-media` mechanism. `.opencode/agents` is a symlink to the whole `.standards/agents`, so files cannot be added inside it. Options: (a) `--with-media` only prints/runs the global installer (machine-wide, not per-repo); (b) `--with-media` writes `agent` entries into the child `opencode.json` using `{file:.standards/agents-optional/media-*.md}` prompts; (c) drop the per-repo flag, global installer only. Default if unanswered under autopilot: (a), since it reuses existing `install.mjs` without new config surface.

## Human review decisions (2026-10-30)

Approved at review gate: all recommended defaults accepted.
- Q1: folder name `agents-optional/` — accepted.
- Q2: option (b) — `--with-media` adds `agent` entries to the child's `opencode.json` pointing at `.standards/agents-optional/`.

## Acceptance scenarios

## AC-040-01-01 — Files relocated
## AC-040-01-02 — Default bridge links no media agent
## AC-040-01-03 — No dangling references from default agents/commands
## AC-040-02-01 — Global installer sources relocated files
## AC-040-02-02 — Uninstall removes them
## AC-040-02-03 — Capability catalog keeps the opt-in flag
## AC-040-02-04 — Bootstrap without flag places no media agent
## AC-040-03-01 — New ADR present
## AC-040-03-02 — ADR 0007 points forward and index updated
## AC-040-04-01 — MEDIA_AGENTS.md documents opt-in
## AC-040-04-02 — No stale agents/media paths in docs
## AC-040-04-03 — Orchestration and skills gates green
## AC-040-04-04 — Media bats suite green

## Verification

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

---

# Phase 2 — Post-PR CI check

- **Round:** 1 (first post-PR CI check)
- **PR:** #109 — https://github.com/RexiAI/my-engineering-standards/pull/109
- **Head SHA checked:** `351b72f2910f7043c809a1559207b8656d664c6b` (unchanged across the
  round — the PR did not move during the check)
- **Workflow(s) observed:** `Self CI`, `PR Review Agent`
- **Polling:** all three check runs were already terminal (`bucket: fail`) at first
  query; no `pending` check was observed and none had to be waited on.

## Evidence: PR check query

command: gh pr checks 109 --json name,state,bucket,workflow,link
exit: 0
at: 2026-11-01T13:37:16Z

```
[{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41311726533/job/124863392546","name":"Review PR / Review PR","state":"FAILURE","workflow":"PR Review Agent"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41311726500/job/124863331920","name":"Validate","state":"FAILURE","workflow":"Self CI"},{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41311720252/job/124863313323","name":"Validate","state":"FAILURE","workflow":"Self CI"}]
```

## Evidence: failing check IDs

command: gh api repos/RexiAI/my-engineering-standards/commits/351b72f2910f7043c809a1559207b8656d664c6b/check-runs --jq '.check_runs[] | select(.conclusion=="failure") | {name,id}'
exit: 0
at: 2026-11-01T13:37:17Z

```
{"id":124863392546,"name":"Review PR / Review PR"}
{"id":124863331920,"name":"Validate"}
{"id":124863313323,"name":"Validate"}
```

| # | Check | Bucket | Job ID | Run | Classification |
|---|---|---|---|---|---|
| 1 | `Review PR / Review PR` | `fail` | 124863392546 | 41311726533 | **Environmental** — ignored in verdict |
| 2 | `Validate` (Self CI) | `fail` | 124863331920 | 41311726500 (pull_request) | **Structural** — pipeline sequencing |
| 3 | `Validate` (Self CI) | `fail` | 124863313323 | 41311720252 (push, same SHA) | same failure, duplicated by the `push` trigger |

Runs 2 and 3 are the same SHA on two triggers (`pull_request` + `push`), so they are
one failure counted twice, not two independent findings.

## Evidence: Self CI failing step log

command: gh run view 41311726500 --log-failed
exit: 0
at: 2026-11-01T13:37:05Z

```
Validate	Check finished specs are archived	2026-11-01T13:32:43.1211632Z ^[[36;1m./scripts/check-specs-archived.sh^[[0m
Validate	Check finished specs are archived	2026-11-01T13:32:43.1445272Z ^[[31m  [FAIL] 040-media-agents-optional is finished (has 30-report.md) but not archived — missing docs/changes/040-media-agents-optional.md^[[0m
Validate	Check finished specs are archived	2026-11-01T13:32:43.1446855Z          Run: scripts/archive-spec.sh 040-media-agents-optional (stage 5d does this automatically)
Validate	Check finished specs are archived	2026-11-01T13:32:43.1447753Z ^[[31m1 finished spec(s) not archived!^[[0m
Validate	Check finished specs are archived	2026-11-01T13:32:43.1463170Z ##[error]Process completed with exit code 1.
```

## Evidence: local reproduction of the failing gate

command: ./scripts/check-specs-archived.sh
exit: 1
at: 2026-11-01T13:37:00Z

```
  [FAIL] 040-media-agents-optional is finished (has 30-report.md) but not archived — missing docs/changes/040-media-agents-optional.md
         Run: scripts/archive-spec.sh 040-media-agents-optional (stage 5d does this automatically)
1 finished spec(s) not archived!
```

Deterministic, not a CI flake: the same gate exits 1 against the PR head checked out
locally at `/tmp/opencode/spec-040-ci-verify` (`git log -1` = `351b72f`).

## Failing steps vs. passing steps (Self CI, job `Validate`)

17 steps succeeded, 1 failed, **17 skipped**:

```
success	Check for CRLF in committed blobs
success	Check CI sweeper deliverables
success	Check agent definitions are model-agnostic
success	Check shell scripts parse (bash -n)
success	make validate-all
success	Check design-gate blame scoping (scratch repos)
success	Check gate list consistency
success	Check orchestration references
success	Check bats assertions are not vacuous
success	Check post-PR CI loop mechanics
success	Check skills specification
failure	Check finished specs are archived
skipped	Check spec audit trails
skipped	make lint
skipped	Install pinned opencode binary and verify model env resolution
skipped	Check agent env guard and hardcoded secrets
skipped	Run loop files check
skipped	Check Daily Triage loop deliverables
skipped	Check PR Babysitter loop deliverables
skipped	Check PR review agent deliverables
skipped	Check security-hardening deliverables
skipped	Check remediation budget
skipped	Install shellcheck
skipped	shellcheck scripts and templates
skipped	Install bats-core
skipped	Run shell gate bats tests (spec 001 Track B)
skipped	Run gate selftests
skipped	Check scenario traceability (live tree)
skipped	Validate YAML syntax (.github, ci)
```

**This matters for the verdict:** the archive gate is early in the workflow, so the
19 steps after it never executed. The 754-test shell track, shellcheck, the gate
selftests, and `check-scenario-traceability.sh` (live tree) have **not** been
validated by CI at this SHA. The attempt-1 `25-verification.md` above ran them
locally and they were green, but CI itself carries no signal for them until the
archive lands and the job runs past step 12.

## Diagnosis

Root cause: `specs/040-media-agents-optional/30-report.md` is committed, which makes
the spec "finished" to `scripts/check-specs-archived.sh`, but
`docs/changes/040-media-agents-optional.md` does not exist on the branch. Stage 5d
(the Archiver, `scripts/archive-spec.sh`) has not run yet. The gate's spec-031
deferral exception does **not** apply: it requires the pair
`Phase-3 budget exhausted` + `Verdict: ESCALATED` at line start in `40-deploy.md`, and
`40-deploy.md` records `Verdict: SKIPPED` (non-frontend repo, phase-3 attempt count
0 of 3). A `SKIPPED` verdict is the *precondition* for stage 5d running the archive —
it does not excuse skipping it.

## Behavior vs. structural classification

| Finding | Class | Detail |
|---|---|---|
| Missing `docs/changes/040-media-agents-optional.md` | **Structural** (pipeline sequencing) | Stage 5d archive not yet executed. No product behavior is wrong, no scenario is contradicted, no test asserts the wrong thing. The fix is `scripts/archive-spec.sh 040-media-agents-optional` + commit — an Archiver action, not Coder/Refactorer work. |
| `Review PR / Review PR` | **Environmental** | Repo-wide, per the orchestrator's standing note and confirmed in this run's log: `AI_APICallError: Upstream request failed: Invalid credential`, plus the workflow's own `::warning::Review skipped — billing/quota error from model provider (exit ${review_rc}). Not a code defect.` Unrelated to this PR; the step still exits 1. Excluded from the verdict. |

**No behavioral finding in this round.** Nothing observed here contradicts a
scenario's Given/When/Then or points at the media-agents opt-in implementation.

## Verdict — round 1

**FAIL** — one non-excluded required check (`Self CI` / `Validate`) is red with a
real, locally reproduced exit 1.

- Failing check ID: **124863331920** (`Validate`, `pull_request`, run 41311726500);
  duplicate **124863313323** (`Validate`, `push`, run 41311720252).
- Excluded from the verdict: **124863392546** (`Review PR / Review PR`) —
  environmental, invalid `OPENCODE_API_KEY`.
- Route: stage 5d Archiver runs the archive, then this check is re-triggered as a
  **scoped re-check** of check ID 124863331920 only (round 2).
- Phase-2 budget after this round: 1 of 3 used.

`SPEC_LOOP_COUNT=1`, `SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`.

## Quality gates

# 040 — Media agents opt-in for child repos — Mutation Runner report

- **Stage:** 5a (Mutation Runner)
- **Agent:** `spec-mutation-runner`
- **Repo:** `/home/dbueno/.local/share/opencode/worktree/471827/spec-040`
- **Base commit:** `39fdd21095b68ee8bbe31a9d674dda69bd9dbb35` (detached HEAD; stage 5b creates `spec/040-media-agents-optional`)
- **Conformance tier:** `mvp` — detected, not assumed (see the mutation-score block below)
- **Autopilot:** false (`SPEC_AUTOPILOT` unset, no `autopilot` argument; `runs.jsonl` entry for this slug carries `loopCount: 0`)
- **Change under test:** relocation of the four media agents `agents/` → `agents-optional/`, per-repo `--with-media` opt-in, ADR 0018, docs/test alignment, plus the three post-verification WARN fixes (ADR 0018 Compliance wording, `10-tasks.md` heading `035`→`040`, one new `--all` bats case).

## Status

**GREEN** — every stage-5a gate this tier configures passed, and the full suite is green
on its final run (`exit 0`, 755/755). Mutation testing is a `production`-tier gate and is
skipped at `mvp`, so there are no surviving mutants and no mutants to kill.

One **WARN** was found during this stage and is recorded under §Findings: a pre-existing,
load-triggered SIGPIPE race in a spec-030 test assertion that is not part of this diff. It
is a WARN under the stop-and-ask matrix ("design gate WARN → record, do not stop, flag"),
not a stage failure — but it is a real defect and it did make two of my three full-suite
runs red. Both outcomes are reported verbatim below; nothing is cherry-picked.

## Required rows

| Row | Value |
|---|---|
| Verifier verdict (carried forward) | **PASS** (`25-verification.md`, attempt 1, phase 1) |
| Mutation score | **skipped — `mvp` tier** (not run; `make mutation` exits 0 with the skip line) |
| Mutants generated / killed / survived / equivalent | `0 / 0 / 0 / 0` — no mutation run at this tier |
| Equivalent mutants | **none** — no mutants were produced, so none can be equivalent |
| Complexity summary (carried from the Refactorer, re-recorded by the Verifier) | complexity gate `exit 0`, `fails: []`, `warns: []`, tier `mvp`; see §Complexity summary |
| Final test status | **GREEN — 755/755, 0 `not ok`, 0 `# skip`**, `exit 0` |
| Remediation record | **none** — no BLOCK occurred in this stage; phase 1 carried forward at 0 of 3 used |
| New tests added by this stage | **0** — nothing survives to kill at `mvp` tier |

---

## Evidence: mutation score

command: make mutation
exit: 0
at: 2026-11-01T13:19:48Z

```
skipped — production tier required (current tier is mvp, see docs/CONFORMANCE_TIERS.md)
```

The skip comes from the repo's own tier detector, not from my judgement. `Makefile:135`
runs mutation only when `AGENTS.md` (or `AGENTS_*.md`) declares
`Conformance tier: production`; no such declaration exists:

```
$ grep -rn "Conformance tier:" AGENTS.md
AGENTS.md: no 'Conformance tier:' declaration (=> mvp floor)
```

`docs/CONFORMANCE_TIERS.md §How to declare a tier` makes `mvp` the floor when nothing is
declared, and `docs/spec-pipeline/coder.md §Conformance tiers` lists the Architect's mutation
testing as `skip` at `mvp`. There is also no mutation tool to run: no `package.json`,
`stryker.conf.*`, Maven `pom.xml`, or Go module at the repo root — this is a shell/docs
repo whose test surface is bats, which none of PiTest/Gremlins/Stryker covers.

Per `AGENTS.md` §Design Principles and `docs/SPEC_PIPELINE.md`, a tier-gated rule above the
declared tier is **not a gap** — it is out of scope until the project graduates. I did not
run a mutation tool as a substitute, and I did not treat the absence of a mutation score as
a test-quality claim: the change's behavior is instead anchored by 28 named tests (see
§Tests guarding this change).

---

## Evidence: final test status

command: make test
exit: 0
at: 2026-11-01T13:14:32Z

```
Checking bats assertions are not vacuous...

PASS check-bats-assertions: 71 bats file(s), no vacuous assertions.
Running bats tests (TAP)...
1..755
ok 1 AC-001-01: Harness runs a passing bats test (TAP ok)
...
ok 198 AC-040-01-01: the four agents live in agents-optional/ and not in agents/
...
ok 214 media-agents unit: --all writes the four entries and --none writes none
ok 215 media-agents unit: an existing non-JSON opencode.json is left untouched and reported
...
ok 755 unit: successful under-cap call writes no reason line at all
test: shell track passed (lang scaffolds are template smoke, see docs/TESTING_TDD_GUIDE.md)
EXIT=0
```

- `ok` lines: **755**. `not ok` lines: **0**. `# skip` lines: **0** — nothing was skipped or
  silently not run.
- Plan `1..755` matches the `ok` count exactly; the vacuous-assertion pre-gate covers all
  71 bats files, including the two this change touches.
- Duration: `13:14:32Z` → `13:19:42Z` (5m10s), load average `2.05` at start.

### Full-suite run history — all three runs, nothing hidden

Two earlier runs of the same command on the same tree were **red**, on the pre-existing
flake documented in §Findings. The final run above was green. All three are recorded so the
green is not mistaken for the only data point.

| # | Started (UTC) | Load avg at start | Result | Failing test |
|---|---|---|---|---|
| 1 | 2026-11-01T12:59:08Z | ~13.1 (external 8-worker Stryker run in an unrelated repo) | `exit 2` — 754 ok, 1 `not ok` | `not ok 55 AC-030-01` (+ `not ok 51 AC-030-06-03`) |
| 2 | 2026-11-01T13:09:05Z | ~13.0 | `exit 2` — 754 ok, 1 `not ok` | `not ok 55 AC-030-01` |
| 3 | 2026-11-01T13:14:32Z | 2.05 | **`exit 0` — 755 ok, 0 `not ok`** | — |

Every failure in runs 1-2 is one of the two spec-030 assertion races described in
§Findings. No failure at any point cited an `AC-040-*` test, and no file this change touches
is on the failing path. The trigger is CPU contention, measured, not guessed: the same
assertion pipeline fails 9/200 times with `pipefail` and 0/200 without it, and the failure
disappears when the external load does.

I did not "re-run until green" as an unbudgeted loop: the re-runs are a controlled
experiment against a stated hypothesis (load-dependence), the hypothesis was measured
independently of the suite (§Findings), and the score is reported as a range with its
condition rather than as an unqualified pass.

---

## Complexity summary

Carried forward from the Refactorer, re-recorded by the Verifier in `25-verification.md`:

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

Full design-principles gate, same session (`scripts/check-code-principles.sh --json
-BaseRef HEAD`, `exit 0`, `at: 2026-11-01T12:34:54Z`): `fails: []`, `warns: []` across
`complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming,
null-discipline`. Property tests are not an `mvp` obligation, so the empty
`property-tests` gate is in-scope-clean here.

Two carried caveats, both **pre-existing and not introduced by this change** — they qualify
what the green complexity gate actually covers:

- **W1 — the gate is blind to `.mjs`.** Its discovered extension set is
  `java, go, ts, tsx, js, jsx, py, rs, sh`. Three of this change's four touched/added source
  files (`merge-agent-entries.mjs`, `install.mjs`, `smoke-media.mjs`) were therefore never
  analysed, and the exit-0 result is silent about them.
- **W2 — pre-existing CC=7 in `scripts/media/install.mjs:36 ensureDir`.** Visible only when
  the file is renamed to a scanned extension; proven pre-existing by the same finding
  against `git show HEAD:scripts/media/install.mjs`. A finding in a touched file without
  diff overlap is pre-existing debt under the gate's own blame rule.

The Refactorer's "complexity ≤6" claim therefore holds **for gate-scanned extensions only**.
That is a statement about the gate, not a defect of this change, and it does not become a
stage-5a failure.

---

## Equivalent mutants

**None.** No mutation run occurred (`mvp` tier), so no mutant was generated, no mutant
survived, and there is nothing to classify as equivalent. This is not a claim that a
`production`-tier run would find zero equivalent mutants — only that this stage produced no
mutants to name.

---

## Tests guarding this change

The mutation gate substitutes for a surviving-mutant inventory at this tier, so here is the
actual behavioural surface the change rests on — 28 tests, all green in the final run:

- **13 `AC-040-*` scenario tests** (`scripts/tests/ac-040-media-agents-optional.bats`), lines
  198-210: relocation, no media agent in the default child set, `agents/`/`commands/` clean,
  installer source dir, `--uninstall`, the `--with-media` catalog row, a child bootstrapped
  without the flag, ADR 0018, the 0007→0016 pointer plus index row, `MEDIA_AGENTS.md`,
  no stale `agents/media` path, both structural gates green, and the media bats suite.
- **5 `media-agents unit` tests** (lines 211-215), including the new
  `--all` case added by the post-verification fix (`--all` writes the four entries,
  `--none` writes none) — the W3 coverage gap the Verifier flagged.
- **10 `media-agents` tests** (`scripts/tests/media-agents.bats`, lines 583-592): file
  presence, absence from the default set, frontmatter, permission denies, backend contract,
  no vendor token, contract example, smoke run, dangling-symlink tolerance, install/idempotent/
  uninstall round trip.

---

## Findings

### F1 (WARN, pre-existing, **not this change**) — latent SIGPIPE race makes two spec-030 assertions flaky

**Symptom.** Under CPU contention, `bash tests/AC-030-01.sh` fails
`AC-030-01-06: heading for 'when to use' missing` — a false FAIL. The assertion's subject
(`skills/e2e-testing/SKILL.md`) does contain that heading; a direct grep matches it.

**Root cause.** `tests/AC-030-01.sh:54` pipes `awk` into `grep -q` inside a script that runs
`set -euo pipefail`:

```
tests/AC-030-01.sh:8:  set -euo pipefail
tests/AC-030-01.sh:54: if body_of "$SK" | grep -qiE "^#{1,6}[[:space:]].*${sec}"; then
```

`grep -q` exits at the first match (line 2 of the body). `awk` still has the rest of the
5.7 KB to write, takes `SIGPIPE`, and exits 141; `pipefail` promotes 141 to the pipeline's
status, so the `if` takes the else branch and reports a missing heading. Later sections
(`exit codes`, near the end of the file) rarely lose the race, which is why only
`when to use` is reported — the earliest section, with the most unwritten output left.

**Measured, both directions.**

```
$ bash /tmp/opencode/proof.sh        # exact pipeline, pipefail ON
pipefail-on:  ok=191  sigpipe141=9  other=0  (n=200)

$ bash /tmp/opencode/proof2.sh       # identical pipeline, pipefail OFF
pipefail-OFF: ok=200  fail=0  (n=200)
```

`9/200` = 4.5% per invocation, and the assertion is reached twice per `make test`
(once standalone, once through the `AC-030-01` task-suite entry point), so a loaded machine
fails the suite far more often than 4.5%.

**Same defect class in a second place.** `scripts/check-model-env.sh:117,122` pipes
`printf` into `grep -qx` under its own `set -euo pipefail` (`check-model-env.sh:32`). The
string is short enough that it usually loses nothing, but the same 141→`if !` inversion can
report a false FAIL, which is the most likely explanation for the single
`not ok 51 AC-030-06-03` in run 1 (it passed standalone and in 5 subsequent bats runs).

**Proof it is not this change.**

```
$ git diff --quiet HEAD -- tests/AC-030-01.sh tests/ac-030-lib.sh && echo IDENTICAL-TO-HEAD
IDENTICAL-TO-HEAD: tests/AC-030-01.sh tests/ac-030-lib.sh
```

Both files are byte-identical to the base commit `39fdd21` — the diff does not touch them,
and their subject (`skills/e2e-testing/SKILL.md`) is untouched too. The Verifier's single
green run at `12:34` was a run on a quieter machine, not a different tree.

**Disposition.** WARN, per the matrix ("design gate WARN → record in the report; do not
stop"). I did **not** fix it: it is an out-of-scope finding in an unrelated spec's test
harness, and per the matrix out-of-scope findings are recorded and proposed as a follow-up,
never fixed by a stage that did not raise them. A one-line fix exists and is listed below.

**Minimal fix for the follow-up spec** (deterministic, semantics-preserving — the asserted
heading set is unchanged):

```sh
# tests/AC-030-01.sh:54 — grep the file directly; no upstream process to SIGPIPE
if grep -qiE "^#{1,6}[[:space:]].*${sec}" <<<"$(body_of "$SK")"; then
# or capture once outside the loop: local body; body="$(body_of "$SK")"
```

Equivalent treatment for `scripts/check-model-env.sh:117,122` (`grep -qx` on a here-string
instead of a pipe). Neither change alters what is asserted.

---

### F2 (WARN, pre-existing, unrelated) — carried forward

`scripts/check-skills.sh` WARNs on `skills/hallmark/SKILL.md` (562 lines > 500). Untouched
by this change; carried forward from `25-verification.md` W6 so the warning in the
Verifier's evidence block is not mistaken for a finding of this stage.

---

## Remediation record

**None — no BLOCK occurred during stage 5a.** No gate emitted a FAIL, so no phase-1
remediation round was consumed by this stage. The two red suite runs in §Full-suite run
history were diagnosed to a pre-existing, load-triggered race (F1) and are not BLOCKs; no
code or threshold was changed to obtain the green.

Carried forward verbatim from `25-verification.md §Budget`:

- Verifier: Attempt 1, phase 1. No BLOCK, no FAIL, so no remediation round was consumed.
- `SPEC_LOOP_COUNT=1`, `SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=0`.
- Phase-1 budget after the Verifier run: **0 of 3 used**.
- Stage 5a adds **0** phase-1 attempts. Phase-2 (post-PR CI) has not started — that is
  stage 5b's and the post-PR loop's territory — so it stands at **0 of 3 used**.
- Cross-check: `runs.jsonl` records this slug with `loopCount: 0`, `phase1Retries: 0`,
  `phase2Retries: 0`, `outcome: "pass"` — consistent with the above.

No attempt information was missing, so nothing in this record is inferred or invented.

---

## Carried forward — out-of-scope findings (recorded, not fixed)

From `25-verification.md`, unchanged by this stage, each still worth a follow-up spec:

- **W1** — `scripts/check-code-principles.sh` does not scan `.mjs`/`.cjs`, so three of this
  change's four source files were never analysed. Add `mjs`/`cjs` to the discovered extension
  set and to the gate's self-test.
- **W2** — pre-existing `CC=7` in `scripts/media/install.mjs:36 ensureDir` (untouched lines).
  Becomes visible once W1 is fixed.
- **W3** — resolved by the post-verification fix: ADR 0018's Compliance bullet was narrowed
  and `AC-040-02-04`'s gap is closed by the new `--all` bats case (line 214). Verify the
  wording and the test against each other at review; both are green.
- **W4** — resolved by the post-verification fix: `10-tasks.md` heading now reads `040`.
- **W5** — `scripts/check-orchestration.sh` scans `agents/*.md` and `commands/*.md` at
  `maxdepth 1`, so relocation to `agents-optional/` removes the media family from the
  reference check. Task 1 requires that trade-off; add `agents-optional/` to the scan set.
- **W6** — see F2.

**New in this stage:**

- **F1** — the `pipefail` / `grep -q` SIGPIPE race in `tests/AC-030-01.sh:54` and
  `scripts/check-model-env.sh:117,122`. Fix as shown in §F1; until then the full suite is
  load-sensitive and can report false FAILs on a busy machine.

None of these was edited by this stage.

---

## Handoff to stage 5b (PR Opener)

- `30-report.md` status: **GREEN** — mutation gate skipped by tier, final suite `exit 0`,
  755/755, 0 `# skip`.
- Working tree is the pipeline's in-flight change (18 paths, uncommitted, on a detached
  HEAD at `39fdd21`). That is expected at this stage: committing per task from
  `10-tasks.md` is stage 5b's job. I committed, pushed, and tagged nothing.
- Reviewer attention requested on: F1 (pre-existing flake, follow-up spec) and the two
  documentation reversals the Verifier flagged for human review — the restored
  `docs/adr/0007-media-agent-family.md` and the amended 0016 Note.

---

## Stage 5b — PR record

PR: https://github.com/RexiAI/my-engineering-standards/pull/109

- Commits: **5** on `spec/040-media-agents-optional` ahead of base `39fdd21` at PR open
  (task 1 `b302bea`, task 2 `d57a9dd`, task 3 `ecf282e`, task 4 `9376d82`, spec artifacts
  `8f887a9`), plus this records commit.
- Audit-trail gate at stage 5b (no `--require-deploy`): `scripts/check-audit-trail.sh
  040-media-agents-optional` — **exit 0**.
- Deploy artifact: `40-deploy.md` present with `Verdict: SKIPPED — Non-frontend repo —
  deploy verification not applicable` (stage 5c-equivalent, phase-3 attempt count 0 of 3).

## 40-deploy.md

# 040 — Media agents opt-in for child repos — Deploy verification (stage 5c)

- **Stage:** 5c (Deploy Verifier)
- **Agent:** `spec-pr-opener` running the stage-5c-equivalent skip path (this repo is
  non-frontend; no deploy lane exists to verify). Recorded as a skip — no deployment,
  health check, or E2E run was performed, and none is applicable.
- **Repo:** `/home/dbueno/.local/share/opencode/worktree/471827/spec-040`
- **Branch:** `spec/040-media-agents-optional`
- **Phase-3 attempt count:** 0 of 3 — the phase-3 loop never started.

## Repo classification

**Non-frontend.** The deploy-lane signals are both absent — no `vercel.json` at the
repo root, and no `package.json` at the repo root (so no framework dependency to
match). Per `agents/spec-deployer.md` §Scope and
`docs/spec-pipeline/deployer.md §Deploy verification loop (phase 3)`, a non-frontend repo
records the skip and exits cleanly: non-frontend repos never fail the deploy gate.

## Evidence: repo classification

command: ls vercel.json package.json
exit: 2
at: 2026-11-01T13:30:47Z

```
ls: cannot access 'vercel.json': No such file or directory
ls: cannot access 'package.json': No such file or directory
```

Both frontend signals the gate keys off (`frontend_repo()` in
`scripts/check-audit-trail.sh`) are absent, so the classifier agrees with the
observation rather than being inferred from package contents.

## Statuses

| Field | Value |
|---|---|
| Deploy URL | none — no Vercel project, no deployment |
| Build status | `skip` |
| Health check status | `skip` |
| E2E verdict | `skip` |
| Timestamp | 2026-11-01T13:30:47Z |
| Phase-3 attempt count | 0 of 3 |

## Verdict

Verdict: SKIPPED — Non-frontend repo — deploy verification not applicable

---

# Post-PR CI check (phase 2) — round 2 of max 3

- **Round:** 2 (scoped re-check of the round-1 failing check)
- **Re-verification attempt index:** 2, phase 2 (phase-1 attempt 1 → phase-2
  round 1 → this round 2)
- **PR:** #109 — https://github.com/RexiAI/my-engineering-standards/pull/109
- **Head checked:** `b5987db4ed2d82020a59ab4f11799c67919b73e8` (the stage-5d
  archive commit; local worktree HEAD identical, working tree clean at round start)
- **Workflows at this head:** `Self CI` (pull_request + push), `PR Review Agent`
- **Polling:** all three runs were already terminal at the first query
  (13:49:59Z); no `pending` check was observed and none was ruled on while pending.

**Scope.** Round 1 failed solely on the two `Self CI` / `Validate` checks because
`docs/changes/040-media-agents-optional.md` did not yet exist. This round
re-checks those two checks at the new head, and — because in round 1 the archive
gate sat at step 16 and masked the 17 steps after it — additionally confirms the
**whole run executed to completion**, not just the archive step. The other gates'
round-1 results stand per the scoped rule; the PR Review Agent's run was
re-triggered, so it was polled to terminal state and is adjudicated below.

**Fix verification.** `b5987db` is the stage-5d archive: it adds
`docs/changes/040-media-agents-optional.md` (1035 lines at this head) and removes
`specs/040-media-agents-optional/`. The previously failing gate now exits 0
locally at this head (evidence below).

## Round-2 verdict: **PASS** — phase-2 CI loop closes

| Check | Workflow | Event | Bucket | Run / check id | Round 1 |
|---|---|---|---|---|---|
| Review PR / Review PR | PR Review Agent | pull_request | `fail` — **environmental, excluded** | run 41312478978, check 124865568693 | fail (excluded) |
| Validate | Self CI | pull_request | **pass** | run 41312478810, check **124865567899** | fail (124863331920) |
| Validate | Self CI | push | **pass** | run 41312474722, check **124865554923** | fail (124863313323) |

Whole-run confirmation, pull_request event: **33 of 33 substantive steps
`success`, zero `skipped`, zero `failure`** — including the 17 steps round 1
never reached (audit trails, lint, pinned-opencode model env, secret scan, loop
deliverables, remediation budget, shellcheck, bats suite, gate selftests, live
scenario traceability, YAML). The push event at the same SHA is likewise all
green. Bats tally identical on both events: TAP plan `1..755`, **755 ok /
0 not ok / 0 skip**. The 13 AC-040 scenarios are green, including
`ok 210 AC-040-04-04`.

Exactly three runs exist at this head — the same workflow set as round 1; no new
checks appeared.

## Evidence: PR checks at the new head

command: gh pr checks 109 --json name,state,bucket,workflow,link
exit: 0
at: 2026-11-01T13:51:54Z

```
[{"bucket":"fail","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41312478978/job/124865568693","name":"Review PR / Review PR","state":"FAILURE","workflow":"PR Review Agent"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41312478810/job/124865567899","name":"Validate","state":"SUCCESS","workflow":"Self CI"},{"bucket":"pass","link":"https://github.com/RexiAI/my-engineering-standards/actions/runs/41312474722/job/124865554923","name":"Validate","state":"SUCCESS","workflow":"Self CI"}]
```

## Evidence: check runs (terminal state) at the new head

command: gh api repos/RexiAI/my-engineering-standards/commits/b5987db4ed2d82020a59ab4f11799c67919b73e8/check-runs --jq '.check_runs[] | {id,name,status,conclusion,started_at,completed_at}'
exit: 0
at: 2026-11-01T13:51:54Z

```
{"completed_at":"2026-11-01T13:42:54Z","conclusion":"failure","id":124865568693,"name":"Review PR / Review PR","started_at":"2026-11-01T13:41:34Z","status":"completed"}
{"completed_at":"2026-11-01T13:47:39Z","conclusion":"success","id":124865567899,"name":"Validate","started_at":"2026-11-01T13:41:34Z","status":"completed"}
{"completed_at":"2026-11-01T13:47:46Z","conclusion":"success","id":124865554923,"name":"Validate","started_at":"2026-11-01T13:41:31Z","status":"completed"}
```

## Evidence: workflow runs at the new head

command: gh run list --repo RexiAI/my-engineering-standards --branch spec/040-media-agents-optional --limit 10 --json databaseId,workflowName,event,status,conclusion,headSha,createdAt --jq '.[] | select(.headSha=="b5987db4ed2d82020a59ab4f11799c67919b73e8")'
exit: 0
at: 2026-11-01T13:51:58Z

```
{"conclusion":"failure","createdAt":"2026-11-01T13:41:32Z","databaseId":41312478978,"event":"pull_request","headSha":"b5987db4ed2d82020a59ab4f11799c67919b73e8","status":"completed","workflowName":"PR Review Agent"}
{"conclusion":"success","createdAt":"2026-11-01T13:41:32Z","databaseId":41312478810,"event":"pull_request","headSha":"b5987db4ed2d82020a59ab4f11799c67919b73e8","status":"completed","workflowName":"Self CI"}
{"conclusion":"success","createdAt":"2026-11-01T13:41:28Z","databaseId":41312474722,"event":"push","headSha":"b5987db4ed2d82020a59ab4f11799c67919b73e8","status":"completed","workflowName":"Self CI"}
```

Exactly three runs at this head — same workflow set as round 1; no new checks.

## Evidence: whole-run step inventory (pull_request, previously masked steps)

command: gh run view 41312478810 --json event,headSha,status,conclusion,jobs --jq '.jobs[] | {name, conclusion, total_steps:(.steps|length), non_success:[.steps[]|select(.conclusion!="success")|{number,name,conclusion}], steps:[.steps[]|{number,name,conclusion}]}'
exit: 0
at: 2026-11-01T13:51:58Z

```
{"conclusion":"success","name":"Validate","non_success":[],"steps":[{"conclusion":"success","name":"Set up job","number":1},{"conclusion":"success","name":"Run actions/checkout@11d5960a326750d5838078e36cf38b85af677262","number":2},{"conclusion":"success","name":"Run actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065","number":3},{"conclusion":"success","name":"Install PyYAML","number":4},{"conclusion":"success","name":"Check for CRLF in committed blobs","number":5},{"conclusion":"success","name":"Check CI sweeper deliverables","number":6},{"conclusion":"success","name":"Check agent definitions are model-agnostic","number":7},{"conclusion":"success","name":"Check shell scripts parse (bash -n)","number":8},{"conclusion":"success","name":"make validate-all","number":9},{"conclusion":"success","name":"Check design-gate blame scoping (scratch repos)","number":10},{"conclusion":"success","name":"Check gate list consistency","number":11},{"conclusion":"success","name":"Check orchestration references","number":12},{"conclusion":"success","name":"Check bats assertions are not vacuous","number":13},{"conclusion":"success","name":"Check post-PR CI loop mechanics","number":14},{"conclusion":"success","name":"Check skills specification","number":15},{"conclusion":"success","name":"Check finished specs are archived","number":16},{"conclusion":"success","name":"Check spec audit trails","number":17},{"conclusion":"success","name":"make lint","number":18},{"conclusion":"success","name":"Install pinned opencode binary and verify model env resolution","number":19},{"conclusion":"success","name":"Check agent env guard and hardcoded secrets","number":20},{"conclusion":"success","name":"Run loop files check","number":21},{"conclusion":"success","name":"Check Daily Triage loop deliverables","number":22},{"conclusion":"success","name":"Check PR Babysitter loop deliverables","number":23},{"conclusion":"success","name":"Check PR review agent deliverables","number":24},{"conclusion":"success","name":"Check security-hardening deliverables","number":25},{"conclusion":"success","name":"Check remediation budget","number":26},{"conclusion":"success","name":"Install shellcheck","number":27},{"conclusion":"success","name":"shellcheck scripts and templates","number":28},{"conclusion":"success","name":"Install bats-core","number":29},{"conclusion":"success","name":"Run shell gate bats tests (spec 001 Track B)","number":30},{"conclusion":"success","name":"Run gate selftests","number":31},{"conclusion":"success","name":"Check scenario traceability (live tree)","number":32},{"conclusion":"success","name":"Validate YAML syntax (.github, ci)","number":33},{"conclusion":"success","name":"Post Run actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065","number":65},{"conclusion":"success","name":"Post Run actions/checkout@11d5960a326750d5838078e36cf38b85af677262","number":66},{"conclusion":"success","name":"Complete job","number":67}],"total_steps":36}
```

`non_success` is empty: every step that ran concluded `success`; none is
`skipped`. The masked tail of round 1 (steps 17–33) now executes.

## Evidence: whole-run tallies and previously masked gate outputs (both events)

command: gh run view 41312478810 --log > /tmp/opencode/ci-040-r2.log; gh run view 41312474722 --log > /tmp/opencode/ci-040-r2-push.log; echo "pull_request: ok=$(grep -cE 'Z ok [0-9]+' /tmp/opencode/ci-040-r2.log) notok=$(grep -cE 'Z not ok [0-9]+' /tmp/opencode/ci-040-r2.log) skip=$(grep -c '# skip' /tmp/opencode/ci-040-r2.log)"; grep -E '1\.\.[0-9]+' /tmp/opencode/ci-040-r2.log | tail -1; echo "push: ok=$(grep -cE 'Z ok [0-9]+' /tmp/opencode/ci-040-r2-push.log) notok=$(grep -cE 'Z not ok [0-9]+' /tmp/opencode/ci-040-r2-push.log) skip=$(grep -c '# skip' /tmp/opencode/ci-040-r2-push.log)"; grep -E '1\.\.[0-9]+' /tmp/opencode/ci-040-r2-push.log | tail -1; for pat in "All finished specs archived" "Done\.$" "selftest: 26 passed, 0 failed" "Scenario traceability check: every scenario traced" "ok 210 AC-040-04-04"; do grep -E "$pat" /tmp/opencode/ci-040-r2.log | tail -1 | sed -E 's/^[^\t]*\t[^\t]*\t[^\x]*Z //'; done
exit: 0
at: 2026-11-01T13:52:04Z

```
pull_request: ok=755 notok=0 skip=0
1..755
push: ok=755 notok=0 skip=0
1..755
All finished specs archived.
Done.
selftest: 26 passed, 0 failed
✔ Scenario traceability check: every scenario traced, every reference resolves.
ok 210 AC-040-04-04: the media agent bats suite is green against agents-optional/
```

Additional verbatim lines from the same logs:

```
Scenario IDs found: 0 live, 488 archived
  [OK] ci/parent.yml
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
```

The `make lint` step ends `Done.`; the YAML step emits `[OK]` for every file in
`.github/`, `ci/`, and `ci/templates/` (last line `[OK] ci/parent.yml`); gate
selftests report `selftest: 26 passed, 0 failed`; the live traceability gate
reports `0 live, 488 archived` and exits 0.

## Evidence: round-1 failing gate — local reproduction at `b5987db`

command: ./scripts/check-specs-archived.sh
exit: 0
at: 2026-11-01T13:52:06Z

```
All finished specs archived.
```

Run in `/home/dbueno/.local/share/opencode/worktree/471827/spec-040` at HEAD
`b5987db` (identical to the PR head). Round 1's exit 1 is gone.

## Evidence: excluded check — `Review PR / Review PR` (environmental)

command: gh run view 41312478978 --log-failed | grep -E "Invalid credential|##\[error\]Process completed"
exit: 0
at: 2026-11-01T13:52:06Z

```
small=false agent=build mode=primary error.error="AI_APICallError: Upstream request failed: Invalid credential"
messageID=msg_197583393001kQIS1ysAVFb7fU error="Upstream request failed: Invalid credential" stack="AI_APICallError: Upstream request failed: Invalid credential\n    at <anonymous> (/$bunfs/root/chunk-22ym6391.js:6:14582)\n    at async <anonymous> (/$bunfs/root/chunk-22ym6391.js:6:12790)\n    at processTicksAndRejections (native:7:39)"
Error: Upstream request failed: Invalid credential
##[error]Process completed with exit code 1.
```

Repo-wide credential failure, not a finding about this PR; excluded from the
verdict, per the round-1 disposition.

## Warnings (review hints — recorded, not pipeline stops)

**W7 — `shellcheck scripts and templates` exits 1 but is `continue-on-error:
true` by repo policy.** Its output shows 208 `SC####` references (info/warning
level, pre-existing across the tree). The only finding in a file this change
touched is `In scripts/bootstrap-actions.sh line 23: SC2153 (info)`, and it is
pre-existing: the merge-base `39fdd21` version of the same file yields the same
finding and the same count (`base_counts: 2 current_counts: 2`). The step still
reports `success` in the step inventory because the workflow sets the policy
deliberately. Not introduced here; no action for this spec.

**W8 — the audit-trail CI step runs vacuously after the archive.** The workflow
loops over `specs/*/30-report.md`; with 040 archived there are zero in-flight
reports on the branch, so the loop body never executes (`errors=0`, no output,
exit 0). This is existing archive-time behavior, not a regression from this
change: the archived one-pager is covered by `check-scenario-traceability.sh`
(`488 archived` IDs, green above). Recorded so a later reader does not mistake
the green step for a re-audit of the archived 040 document.

**W9 — round-1 warnings W1–W6 stand unchanged.** This is a scoped phase-2
re-check: the design-principles, complexity, and spot-check gates were not
re-executed, so their round-1 results (PASS, with W1 `.mjs` gate blind spot,
W2 pre-existing CC=7 `ensureDir`, W3 `--all` coverage wording, W4 heading typo,
W5 orchestration scan gap, W6 hallmark length) carry forward without change.

**No behavioral finding in this round.** Nothing observed at the new head
contradicts a scenario's Given/When/Then or points at the media-agents opt-in
implementation.

## Budget

- Re-verification **attempt 2, phase 2, round 2**: only the previously-failing
  `Self CI` / `Validate` gate was re-run; unchanged gates' round-1 results stand.
- `SPEC_LOOP_COUNT=2`, `SPEC_PHASE1_RETRIES=0`, `SPEC_PHASE2_RETRIES=1`.
- Phase-2 budget after this round: **2 of 3 used**. PASS closes the loop; no
  remediation round is requested.
- Telemetry: one record appended to `runs.jsonl` (`outcome: pass`,
  `gatesFailed: []`).
