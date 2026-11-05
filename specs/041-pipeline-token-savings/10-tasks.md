# 10-tasks — 041-pipeline-token-savings

## The ask (verbatim summary)

Cut token spend without weakening gates. Four findings from a read-only audit
(2026-10-30):

1. `docs/CODING_CONVENTIONS.md` is 26 KB; `agents/spec-coder.md:63` and
   `agents/spec-refactorer.md:39` point at the whole file → point at the relevant
   sections only.
2. No output filtering: agents paste full `make test` / lint / principles logs
   into context. Add a helper (e.g. `scripts/agent-test-summary.sh`) that prints
   only failures plus a one-line summary; the full log still goes to
   `25-verification.md` evidence.
3. Redundant full-suite runs: coder, refactorer, verifier and mutation-runner each
   run `make test`. Keep the verifier's run as the gate; allow reuse when the diff
   hash is unchanged.
4. `model.local.env.example` sets effort `xhigh` for mechanical stages (deployer,
   pr-opener, pipeline); the mutation-runner uses a premium model. Reduce.

Each item must end **implemented or explicitly rejected with a recorded reason**,
with a measured before/after (bytes an agent must read per stage). **No gate may be
removed or weakened.** `AGENTS.md` rules for evidence files are unchanged.

## Grounded context (re-measured 2026-11-01)

All numbers below are `wc -c` bytes, reproducible with the command shown.

```
wc -c docs/CODING_CONVENTIONS.md                       # 26287  (357 lines)
sed -n   '3,25p'   docs/CODING_CONVENTIONS.md | wc -c  #  2277  ## Naming + ## File Organization
sed -n  '26,140p'  docs/CODING_CONVENTIONS.md | wc -c  #  8053  ## Design Principles (+ KISS/DRY/YAGNI/SOLID/…)
sed -n '141,189p'  docs/CODING_CONVENTIONS.md | wc -c  #  1333  ## Error Handling Philosophy
sed -n '190,263p'  docs/CODING_CONVENTIONS.md | wc -c  # 10124  ## Formatting  (NOT referenced after this spec)
sed -n '264,282p'  docs/CODING_CONVENTIONS.md | wc -c  #  1096  ## Logging
sed -n '283,331p'  docs/CODING_CONVENTIONS.md | wc -c  #  2060  ## Exception Handling
sed -n '332,349p'  docs/CODING_CONVENTIONS.md | wc -c  #   312  ## Imports Ordering
```

- `docs/CODING_CONVENTIONS.md` top-level (`^## `) headings are unique, so a
  `§<Heading>` anchor resolves to exactly one line. Level-3 headings are **not**
  unique (`### Java`, `### Go`, `### JavaScript` each appear twice), so anchors are
  resolved against `^## ` only.
- `AGENTS.md:17` already uses the anchor form
  (`docs/CODING_CONVENTIONS.md §Design Principles`) — the style this spec extends.
- Cyclomatic ≤6 (the Refactorer's trigger) sits at `docs/CODING_CONVENTIONS.md:134`,
  inside `## Design Principles` — so the refactorer needs that one section and
  nothing else.
- `scripts/check-audit-trail.sh` requires, per evidence block: `## Evidence: <name>`
  + `command:` + `exit:` + `at:` (`YYYY-MM-DDTHH:MM:SSZ`) + non-empty body. It
  strips only those three marker lines from the body; an extra `Test-run hash:` line
  inside a block is preserved and tolerated (it becomes part of the raw output).
- Its five check names are `scenario traceability`, `full test suite`,
  `complexity gate`, `design-principles gate`, `scenario-to-behavior spot check`.
- The project test command in this repo is `make test` → `make test-scripts` →
  `bats --tap scripts/tests/*.bats`.
- **Item 4's premise is factually wrong, and this is verified, not assumed.**
  `config/model.local.env.example` contains **no** `effort` key
  (`grep -c effort config/model.local.env.example` → `0`); it sets model ids only.
  `effort: xhigh` is set at `opencode.json:43` and `opencode.json:50`, inside the
  **provider** `models.<id>.options` blocks — so it applies to every stage that
  uses those model ids, not to "mechanical stages".
- Per-agent effort **is** expressible at the config layer. Verified on
  `opencode v2.2.5` with a throwaway project config and `opencode debug config`:
  `agent.<name>.options: { "effort": "low" }` resolves to
  `agent.<name>.request.body.effort = "low"`, while an agent without `options`
  resolves to no `request.body` key. The probe was discarded; nothing in this repo
  changed. This makes a per-stage effort lever *possible* — it does not make it a
  shipped default (see D4).
- Hashes at the audit baseline (**superseded**; AC-041-49 pins the base-tree
  values re-measured below, not these):

```
sha256  config/model.local.env.example  bc8757100c140cfebe0746ef20fc493167640b6e7a2feaed1d622cd103f2d164
sha256  opencode.json                   35f92ff16954c7cd8eaecf98d67ea6eba931b9912ef2caea5e417204aa448db3
```

Re-measured at the stacked base (`4dbf164`, the spec/038 tip this spec branches
from): `config/model.local.env.example` is
`194765aea7d621ba6014a38bc7503e7ca1df3b29e081edbb0e094b9a36a2e62f` and
`opencode.json` is `49ecd5edc66d3de16a9227fa0eb32d6cf2baf808fd50c19bcd15715832008ce3`.
Spec 037 rewrote both files after the values above were taken; the invariant
AC-041-49 pins is that *this* spec changes neither, so the acceptance test pins
the base tree's bytes.

## Preconditions

- **P1 — 037 landed.** `docs/spec-pipeline/` exists and
  `docs/spec-pipeline/model-config.md` is present (Task 6 appends a section to it).
  `/build` for 041 must not start until `docs/changes/037-*.md` exists on the base
  branch. STOP and report otherwise — do not create `docs/spec-pipeline/` yourself.
- **P2 — 038 landed.** `scripts/check-agent-line-cap.sh` exists and caps
  `agents/spec-*.md` at 120 lines. Every agent edit in Tasks 3 and 5 must keep that
  gate green; `/build` for 041 must not start until `docs/changes/038-*.md` exists.
- **Why not parallel:** 037 and 038 both rewrite `agents/spec-*.md`, `AGENTS.md`
  and `docs/`. 041 edits the same files. Sequential, not concurrent.
- **Non-overlap (do not duplicate 037/038 work):** 037 owns the per-stage docs and
  the `§`-anchor resolution for `docs/SPEC_PIPELINE.md` / `docs/spec-pipeline/*.md`
  inside `scripts/check-orchestration.sh`. 038 owns the agent line cap. 041 adds
  (a) a **separate** `CODING_CONVENTIONS.md`-scoped reference checker with a
  `--cost` mode, (b) a test-log filter helper, (c) a test-run hash/reuse helper,
  (d) a guidance section in `docs/spec-pipeline/model-config.md`.

## Recorded decisions (defaults applied; also the input to Task 7's audit record)

- **D1 — section references, not whole file.** Coder keeps `§Naming`,
  `§File Organization`, `§Design Principles`, `§Error Handling Philosophy`,
  `§Logging`, `§Exception Handling`, `§Imports Ordering`. Refactorer keeps
  `§Design Principles` only.
- **D1b — `§Formatting` is dropped from the coder's set.** Reason: the coder's own
  instruction names "structure, naming, error handling, and logging" and never
  formatting; every stack in this repo has a machine formatter that owns formatting
  deterministically (Spotless, Prettier, `gofmt`, `ruff format`) and runs in CI. No
  gate checks prose formatting. Flagged as this spec's one judgement call (Q4).
- **D1c — `agents/pr-review.md:69` carries the same bare whole-file reference and is
  deliberately NOT fixed here** (outside the informal spec's scope, and outside the
  `agents/spec-*.md` glob the new checker scans). Recorded as a follow-up, not a
  silent omission (Q1).
- **D2 — helper, not a new evidence channel.** `scripts/agent-test-summary.sh`
  captures the complete log to a caller-named path, prints only signal lines + one
  `SUMMARY:` line, and exits with the wrapped command's status verbatim. `--read`
  formats an existing log and exits 0 on a readable log (a formatter is not a
  gate); it exits 2 only when the file cannot be read.
- **D2b — the full log reaches the evidence file without entering context.** The
  stage appends a trailing `## Raw log: <check>` section to `25-verification.md` with
  a shell redirect (`printf …; cat "$LOG"`), so the full log lands verbatim at zero
  context cost. The `## Evidence: <check>` block body carries the `SUMMARY:` line +
  signal lines + `full log: §Raw log: <check>` — the audit contract's
  "representative excerpt for very long output" rule. Not a new spec-folder artifact
  (the audit contract forbids those). The helper's log path must live outside
  `specs/`; it refuses a path under `specs/` (exit 2).
- **D2c — only test-suite output is ever filtered.** The design-principles gate's
  contract requires every FAIL/WARN line verbatim, and the complexity linters report
  findings in tool-specific shapes (`cyclop`, PMD, ESLint `complexity`) that the
  helper's signal pattern would silently drop — so both lanes stay raw, invoked
  directly. Item 2 applies to test-runner output only, where every supported runner
  names failures with `FAIL` / `ERROR` / `not ok`. This is how "no gate weakened" is
  honoured rather than assumed.
- **D3 — reuse is limited to the mutation-runner's final suite run.** The Verifier
  keeps its own full run, unconditionally — it is the gate. The Coder's and
  Refactorer's suite runs happen *before* any recorded run exists, so there is
  nothing to reuse from; they stay (author feedback, not gates) and are shrunk by
  D2 instead. Reuse is granted only on an exact hash match, so the failure mode is a
  redundant run, never a skipped one.
- **D4 — model/effort stays documented, not shipped.** Changing a model id saves
  little context while adding a tracked, vendor-coupled default that
  `docs/spec-pipeline/model-config.md` and `AGENTS.md` both rule out, and the
  provider-level `effort` cannot be narrowed per stage from `config/model.local.env.example`
  at all. Guidance is documented; shipped defaults stay byte-identical (AC-041-49).
  The literal "reduce `xhigh`" ask is **rejected as stated** because its premise is
  false (Grounded context) and is re-recorded as an actionable per-machine lever.

## Measured before/after (baseline 2026-11-01)

| # | Informal item | Baseline command or fixture | Before | After | Delta | Status |
|---|---|---|---|---|---|---|
| 1 | `CODING_CONVENTIONS.md` read per stage | `scripts/check-doc-section-refs.sh --cost` | coder 26,287 B; refactorer 26,287 B (52,574 B per `/build`) | coder 15,131 B; refactorer 8,053 B (23,184 B per `/build`) | −42.4% / −69.4% per stage; −29,390 B (−55.9%) per `/build` | implemented (Task 1) |
| 2 | Test-lane log bytes in agent context, per suite run | AC-041-14 fixture (500 signal lines) and AC-041-15 fixture (5 lines of 2,048 B) | the whole log pasted into context, unbounded (AC-041-14 fixture: 500 signal lines printed in full) | ≤50 signal lines + 1 `SUMMARY:` line, signal block ≤8,192 B (AC-041-14: 50 lines; AC-041-15: 3 of 5 long lines) | −90% signal lines at the line cap, and a hard 8,192 B ceiling instead of an unbounded dump | implemented (Tasks 2-3) |
| 3 | Full-suite invocations after structural work, per `/build` | `scripts/test-run-reuse.sh --check specs/NNN-slug/25-verification.md` (exit 0 = reuse, exit 1 = re-run) | 2 (Verifier + Mutation Runner) | 1 when the worktree hash is unchanged; 2 when the runner added tests | −1 full suite run on the no-new-tests path | implemented (Tasks 4-5) |
| 4 | Effort/model for mechanical stages | `grep -c effort config/model.local.env.example` → 0; `grep -n effort opencode.json` → provider blocks only | `xhigh` on the provider model (all stages); no guidance text | no shipped change; 1 guidance section, 0 B added to any stage agent's read set | 0 B stage cost; operator lever documented | rejected as stated — the `xhigh` premise is false (the example has no `effort` key; it is provider-level) — documented instead (Task 6) |

Cumulative stage-read cost for the two affected stages: **52,574 B → 23,184 B**
(−55.9%), before counting item 2's cap or item 3's saved run.

### Gate results at hand-off

Every gate named in this record was green at the stage-2 hand-off, with the exit
code observed on this tree. Re-run the same commands to reproduce:

```
make test                                                    exit 0
scripts/check-doc-section-refs.sh                            exit 0
scripts/check-agent-line-cap.sh                              exit 0
scripts/check-orchestration.sh                               exit 0
scripts/check-skills.sh                                      exit 0
scripts/check-scenario-traceability.sh                       exit 0
scripts/check-code-principles.sh                             exit 0
scripts/check-specs-archived.sh                              exit 0
scripts/measure-stage-read-cost.sh                           exit 0
```

## Tasks

### Task 1 — Section-scoped `CODING_CONVENTIONS.md` references (AC-041-01…08)

- `agents/spec-coder.md` line 63's reference becomes exactly
  `docs/CODING_CONVENTIONS.md §Naming, §File Organization, §Design Principles, §Error Handling Philosophy, §Logging, §Exception Handling, §Imports Ordering`
  — one reference, no bare path.
- `agents/spec-refactorer.md` line 39's reference becomes exactly
  `docs/CODING_CONVENTIONS.md §Design Principles`.
- The surrounding sentences are otherwise unchanged: no instruction is dropped or
  reworded, and no requirement leaves the agent's read set except `§Formatting`
  (D1b) and `§CI Job Orchestration` (never referenced).
- New `scripts/check-doc-section-refs.sh` (bash, `set -euo pipefail`, header usage
  block with exit codes and a standards reference, per repo script conventions):
  - Scans `agents/spec-*.md` and `commands/*.md` for `docs/CODING_CONVENTIONS.md`.
  - Every such reference must carry at least one `§<Heading>` anchor on the same
    line; a reference with no anchor is a violation (`bare-reference`).
  - Every anchored heading must match exactly one `^## <Heading>$` line in
    `docs/CODING_CONVENTIONS.md`; zero matches (`section-missing`) or more than one
    (`section-ambiguous`) is a violation.
  - Exit 0 = clean, printing one `[OK] <path>` line per file in scope (whether or
    not it carries a reference); 1 = ≥1 violation, printing
    `path:line: reason: detail`; 2 = tooling failure (doc missing, `agents/`
    missing) — never a silent PASS.
  - `--cost` mode: for each file in scope carrying at least one reference, prints
    one line
    `cost <path> sections=<n> bytes=<b> file_bytes=<t> ratio=<r>` where `bytes` is
    the sum of the referenced sections' byte ranges (heading line through the line
    before the next `^## ` heading, or EOF), `t` is `wc -c` of the whole doc, and
    `r` is `bytes/t` to 2 decimals. A section referenced twice by one file counts
    once. `--cost` exits 0 on success and 2 on the same tooling failures; it never
    exits 1 — a measurement tool, not a threshold.
- `scripts/tests/ac-041-doc-section-refs.bats` carries the AC-041-01…08 IDs.
- Wired into `.github/workflows/self-ci.yml` as its own step, and named in
  `AGENTS.md §General Rules` on the line that already lists
  `check-orchestration.sh` / `check-skills.sh` (one sentence, no restructure).
- Cyclomatic ≤6 per function; `scripts/check-code-principles.sh` exits 0.

### Task 2 — `scripts/agent-test-summary.sh` (AC-041-09…20)

- Usage: `scripts/agent-test-summary.sh --run <log-path> -- <command…>` and
  `scripts/agent-test-summary.sh --read <log-path>`; `-h|--help` prints the header.
- Single named constants, no flags for them (fixed interface):
  `MAX_SIGNAL_LINES=50`, `MAX_OUTPUT_BYTES=8192`, `SIGNAL_RE`, `ZERO_RE`.
- `SIGNAL_RE` matches failure/error/warning lines across the repo's stacks: `FAIL`,
  `FAILED`, `ERROR`, `WARN`, `error:`, `AssertionError`, `panic:`, `Traceback`,
  `✗`, `✘`, `not ok`. `ZERO_RE` suppresses a matched line that only reports a zero
  count (`failures=0`, `Failures: 0`, `0 failed`, `0 errors`) — a clean run prints
  no signal lines.
- Printing rule: signal lines print verbatim in log order while **both** caps hold
  (printed count < `MAX_SIGNAL_LINES`; accumulated printed bytes, line + newline,
  ≤ `MAX_OUTPUT_BYTES`). The first line that would break either cap stops printing;
  it and every later signal line are omitted and counted.
- Truncation line (only when lines were omitted), exactly:
  `TRUNCATED: <n> more signal lines omitted; full log: <log-path>`.
- Summary line, always the last line of stdout, exactly:
  `SUMMARY: mode=<run|read> exit=<code|-> signal=<n> log_lines=<m> log=<path>`
  where `<n>` is printed + omitted signal lines (the true total) and `<m>` is the
  log's line count.
- `--run` writes the wrapped command's combined stdout+stderr to `<log-path>`
  complete (never truncated, never rewritten), prints nothing else, and exits with
  the wrapped command's status **verbatim** (0, 1, 42, 127 — no remapping). A
  missing command exits 127 like the shell would.
- `--run` refuses a `<log-path>` under any `specs/` directory: prints
  `agent-test-summary: refusing to write a log inside specs/` to stderr and exits 2
  **before** running the command.
- `--read` writes nothing, exits 0 on a readable log (even one full of failures — a
  formatter is not a gate), exits 2 on an unreadable/missing path with nothing on
  stdout.
- No arguments / unknown argument / `--run` without `--`: exit 2, usage on stderr.
- `scripts/tests/ac-041-agent-test-summary.bats` carries the AC-041-09…20 IDs.

### Task 3 — Wire the stages to the summary helper (AC-041-21…26)

- Applies to test-suite runs only: `spec-verifier` (full test suite),
  `spec-mutation-runner` (final suite run and any suite re-run), `spec-coder`
  (per-task suite), `spec-refactorer` (suite after each extraction).
- Each of those four stages documents the same shape, in exactly one place per stage
  (the agent file, or the 037 stage doc with a one-line pointer from the agent —
  never both):
  - run: `scripts/agent-test-summary.sh --run "${TMPDIR:-/tmp}/pipeline/<slug>-<stage>-<check>.log" -- <real command>`
  - the agent reads only stdout (signal lines + `SUMMARY:`), never the log file;
  - the full log is appended to the evidence artifact with a redirect, not by
    reading it:
    `{ printf '## Raw log: <check>\n\ncommand: %s\nexit: %s\nat: %s\n\n' "$CMD" "$XC" "$AT"; cat "$LOG"; } >> specs/NNN-slug/25-verification.md`
  - the `## Evidence: <check>` block body is the `SUMMARY:` line + printed signal
    lines + `full log: §Raw log: <check>`.
- `command:` in the evidence block contains the real command verbatim after `--`,
  so the audit trail still names what actually ran; `exit:` is the helper's exit
  status (the wrapped command's, unchanged).
- The design-principles gate and the complexity linters are **not** routed through
  the helper; both are invoked directly and their output stays raw (D2c).
- Every agent file stays ≤120 lines; `scripts/check-agent-line-cap.sh` exits 0 and
  `scripts/check-orchestration.sh` resolves every new `scripts/...` reference.

### Task 4 — `scripts/test-run-reuse.sh` (AC-041-27…37)

- Usage: `scripts/test-run-reuse.sh --print-hash` and
  `scripts/test-run-reuse.sh --check <path/to/25-verification.md>`; `-h|--help`.
- Hash definition (documented in the header, implementable exactly): sha256,
  lowercase hex, exactly 64 characters, one line on stdout, over the
  newline-joined, in this order:
  1. `git rev-parse HEAD`, or the literal `NO-HEAD` when the repo has no commit;
  2. the raw `git status --porcelain=v1 -z -uall` output (staged, unstaged, and
     untracked, including untracked files inside new directories);
  3. for each path in that status output, `git hash-object -- <path>`, or the
     literal `DELETED` for a path that no longer exists.
  Rationale (header comment): `git diff` alone misses untracked files, and the
  Mutation Runner's new tests are exactly untracked files.
- `--check` reads the `## Evidence: full test suite` block (same block-extraction
  shape as `scripts/check-audit-trail.sh`: `## Evidence:` heading to the next
  `## Evidence:` or EOF) and decides:
  - block absent → `RERUN no-evidence-block`, exit 1
  - `exit:` absent or not `0` → `RERUN exit-nonzero`, exit 1
  - no `Test-run hash:` line in the block → `RERUN hash-missing`, exit 1
  - recorded hash ≠ recomputed hash → `RERUN hash-mismatch`, exit 1
  - otherwise → `REUSE <hash>`, exit 0
  `--check` never writes and never runs a test.
- Exit 2: usage error, unreadable verification file, or not a git work tree (no
  hash printed in that case).
- `--check` does **not** judge the overall verdict — the mutation-runner's existing
  precondition (Verifier PASS before running) stays authoritative, which keeps the
  decision mechanical and the gate unchanged.
- `scripts/tests/ac-041-test-run-reuse.bats` carries the AC-041-27…37 IDs, using
  scratch git repos (same pattern as `scripts/tests/archive-spec.bats`).

### Task 5 — Verifier records the hash; Mutation Runner reuses the run (AC-041-38…44)

- Verifier: in the `## Evidence: full test suite` block, immediately after the `at:`
  line, record `Test-run hash: <64-hex>` from
  `scripts/test-run-reuse.sh --print-hash`, computed **after** the suite run. If a
  hash taken before the run differs, add the finding line
  `tree-changed-during-run` naming both hashes; the post-run hash is the recorded
  one. `scripts/check-audit-trail.sh <slug>` still exits 0 on the resulting folder
  (the extra line lives in block body it tolerates).
- The Mutation Runner's "Full suite, one final time" section becomes a decision,
  keeping its existing precondition and report obligations:
  1. Mutation testing itself always runs — reuse never applies to it.
  2. After mutation work, run `scripts/test-run-reuse.sh --check specs/NNN-slug/25-verification.md`.
  3. Exit 0 → reuse. `30-report.md`'s final-test-status row carries `command:`,
     `exit: 0` and `at:` **verbatim from the Verifier's block** (the run did happen,
     then), plus one extra line
     `reused-from: 25-verification.md §Evidence: full test suite (test-run hash <hex>)`.
     No test command is executed.
  4. Exit 1 → run the suite via `scripts/agent-test-summary.sh`, then record its own
     `command:` / `exit:` / `at:` plus the post-run `Test-run hash:` (same
     tree-changed-during-run rule as the Verifier).
  5. Either branch states the fail-safe direction: a hash mismatch only ever costs a
     redundant run.
- The Verifier never calls `--check`; its procedure says the suite runs itself, every
  time — that is the gate.
- `30-report.md`'s evidence rows stay audit-trail compliant in both branches:
  `scripts/check-audit-trail.sh <slug>` exits 0 for a fixture report using the reuse
  form.
- Every touched agent file stays ≤120 lines; `check-agent-line-cap.sh` and
  `check-orchestration.sh` exit 0.

### Task 6 — Mechanical-stage model/effort guidance (AC-041-45…49)

- Append exactly one section, `## Mechanical-stage model and effort guidance`, to
  `docs/spec-pipeline/model-config.md` (created by 037). Existing content is not
  rewritten or moved.
- The section has a table with one row per mechanical stage: `spec-deployer`,
  `spec-pr-opener`, `spec-mutation-runner`, `spec-pipeline` (orchestrator). Each row
  states the work shape (deterministic waits, `git`/`gh` invocations, record
  assembly, report formatting), the capability class that work needs (smallest model
  that reliably follows a multi-step procedure), and the effort setting to prefer.
- The section records the finding in substance: `effort: xhigh` is set on the
  **provider model** options (in `opencode.json`, provider `models.<id>.options`),
  so it applies to every stage using those model ids; `config/model.local.env.example`
  sets model ids only and contains no `effort` key.
- The section records the **verified** per-agent lever, with the command and the
  observed shape, and no model ids: `agent.<name>.options: { "effort": "…" }`
  resolves into `agent.<name>.request.body.effort` (verified with
  `opencode debug config` on `opencode v2.2.5`), while an agent without `options`
  resolves to no `request.body` key.
- The section records **D4**: shipped defaults are deliberately unchanged (a tracked
  per-stage model id is vendor coupling, and provider-level `effort` cannot be
  narrowed per stage); the supported per-machine route is `config/model.local.env`
  plus a restart, no commit.
- The section contains **no** model id and **no** provider id — use
  `<provider>/<model-id>` placeholders. Checkable: no occurrence of `qwen`,
  `bailian`, `anthropic`, `deepseek`, `glm`, and no `[a-z0-9-]+/[a-z0-9.-]+` token
  other than the placeholder.
- Nothing else changes for item 4: `config/model.local.env.example` and
  `opencode.json` keep their base-tree sha256 — the invariant AC-041-49 pins
  is "unchanged by this spec", asserted as a `git diff` against the base
  commit plus the base tree's literals.

### Task 7 — Token-savings audit record (AC-041-50…54)

- `10-tasks.md §Measured before/after` keeps one row per informal item with the
  reproducing command (or fixture definition) for the baseline, the before value, the
  after value, the delta, and the status — `implemented`, or `rejected: <reason>`.
  (This file is embedded verbatim in `docs/changes/041-pipeline-token-savings.md` by
  `scripts/archive-spec.sh`, so the record survives archiving; no new spec-folder
  artifact is created.)
- Every gate named in the record is green at hand-off, each with its exit code:
  `make test`, `scripts/check-doc-section-refs.sh`,
  `scripts/check-agent-line-cap.sh`, `scripts/check-orchestration.sh`,
  `scripts/check-skills.sh`, `scripts/check-scenario-traceability.sh`,
  `scripts/check-code-principles.sh`.
- Gate scripts stay byte-identical to the base commit — proven with
  `git diff --quiet <base-commit> -- <script>` for `scripts/check-audit-trail.sh`,
  `scripts/check-scenario-traceability.sh`, `scripts/check-code-principles.sh`,
  `scripts/check-agent-line-cap.sh`. No threshold value changes in any file
  (complexity 6, mutation ≥80%, agent cap 120, the five audit-trail checks).
- The design-principles gate's every-FAIL/WARN requirement is unchanged, and neither
  that lane nor the complexity linters are routed through the filter (D2c).
- The record names the three rejected/flagged items explicitly with reasons: item
  4's `xhigh` premise (false, Grounded context), the coder/refactorer suite runs (not
  reusable, D3), and `agents/pr-review.md:69` (out of scope, D1c).

## Out of scope / flagged, not fixed

- `agents/pr-review.md:69` — same bare whole-file reference (D1c). Proposed
  follow-up: one-line change to `docs/CODING_CONVENTIONS.md §Design Principles`.
- `docs/spec-pipeline/*` restructuring (037) and agent line-cap extraction (038) —
  assumed landed, not re-done here.
- Reducing the Coder's/Refactorer's own suite runs — they precede the gate, nothing
  to reuse (D3).
- Changing any gate threshold, model id, or provider block.

## Open questions (need a human answer before `/build`)

- **Q1 — `pr-review.md`.** Fix its bare reference in this spec (one line, same
  failure mode), or leave it as the recorded follow-up in D1c? **Default applied:
  leave it.** Confirm.
- **Q2 — per-agent `options`.** The config layer accepts per-agent `effort`
  (verified; Grounded context). Ship it as a tracked default for the four mechanical
  agents, or keep documenting it per-machine? **Default applied: document only
  (D4)** — a shipped `options.effort` for a named agent is still a tracked default
  that a child repo inherits without choosing it. Confirm.
- **Q3 — evidence size.** The full log lands in `25-verification.md` as a trailing
  `## Raw log: <check>` section (D2b), so the artifact can reach a few hundred KB.
  Accept, or cap the raw-log section and rely on the path? **Default applied: append
  the full log** (the informal asks for the full log in the evidence file). Confirm.
- **Q4 — `§Formatting` dropped from the coder (D1b).** Accept, or keep it and point
  at the per-language subsection (`### <lang>` under `## Formatting`) at the cost of
  +10,124 B? **Default applied: dropped.**

## Human review decisions (2026-11-05)

Approved at review gate — defaults accepted:
- Q1: `agents/pr-review.md:69` bare whole-file reference is OUT of scope (recorded follow-up).
- Q2: do NOT ship per-agent `options.effort`; document per-machine guidance only.
- Q3: accept the `## Raw log:` appendix in `25-verification.md` uncapped (evidence fidelity wins).
- Q4: drop `§Formatting` from the coder's must-read set (keep the measured saving).

## Remediation notes (post-Verifier round 1, 2026-11-05)

Round 1 of the Verifier (`25-verification.md`) raised three findings. Disposition:

- **(a) B1 / B2 — owned by the Coder, fixation in round 1.** B1 (the log filter's
  false positives) and B2 (the reuse path unreachable as specified) are behavioral
  defects in stage-2 code, not spec text. The Coder fixes them in round 1 under the
  Phase 1 remediation budget (max 3, `docs/SPEC_PIPELINE.md §Remediation budget`);
  the Verifier then re-verifies only the failing gates. No task text is changed by
  them, and no gate threshold moves.
- **(b) `docs/changes/038-trim-agent-prompts.md` — repoint retained and justified.**
  `docs/changes/038-trim-agent-prompts.md` repoint is retained and justified: 037's
  AC-037-03-01 requires archived docs not to cite pre-split paths; verified by
  `bats scripts/tests/ac-037-references.bats`.
- **(c) B3 / B3b — spec text fixed in this round (Specifier).** AC-041-49 now pins
  the base tree's current literals (`194765…` / `49ecd5…` at `4dbf164`) and states
  the invariant as "unchanged by this spec", not a fixed historical literal;
  AC-041-48 now permits exactly the two config paths AC-041-49 requires and bans
  only model/provider identifier tokens (plus any other slash-form token). The two
  scenarios are no longer mutually unsatisfiable.
