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
declared, and `docs/SPEC_PIPELINE.md §Conformance tiers` lists the Architect's mutation
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
