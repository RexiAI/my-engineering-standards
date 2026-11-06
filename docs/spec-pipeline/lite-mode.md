# Lite mode (shared)

Index: `docs/SPEC_PIPELINE.md §Lite mode`; the rules live there, this file is
the procedure behind them. ADR: `docs/adr/0020-pipeline-lite-mode.md`.

Lite mode is the same pipeline with the stages that only pay for themselves on
a larger change removed. What makes a spec small is measured, not judged: a
human is bad at knowing how much a "small" change will touch, and an agent
asked to self-assess has every incentive to say "small".

## Selection

Three scripts, no agent re-implements any of them.

1. `scripts/lite-trigger.sh [ARG ...]` — prints `lite`, `full`, or `auto` from
   an exact whole argv token (`--lite`, `lite-mode`, and `mylite` do not
   match). Both tokens together is a conflict: exit 2, empty stdout, stderr
   names it.
2. `scripts/classify-spec-size.sh specs/NNN-slug` — prints `lite` or `full` plus
   one `Reason:` line. It reads only `10-tasks.md` and `20-acceptance/` inside
   the spec folder, so the same input is byte-identical output every run.
3. `scripts/resolve-pipeline-mode.sh specs/NNN-slug [ARG ...]` — applies the
   precedence, prints the resolved mode, and appends one entry to
   `specs/NNN-slug/45-decisions.md`.

### The classifier rule

`lite` requires both conditions:

- every file path named in `10-tasks.md` is under `docs/`, under `specs/`, is a
  `*.md` file anywhere, or is exactly one file under `scripts/`; and
- `20-acceptance/*.md` holds at most 5 `## AC-NNN-NN` scenarios.

A path that resolves inside the spec folder counts as `specs/` — `20-acceptance/`
and `45-decisions.md` are the spec's own artifacts. A leading-slash single
segment (`/build`, `/spec`) is a slash command, not a path.

Any other named path (a `commands/` file, a CI template, two scripts under
`scripts/`) makes the spec `full`, as does a missing or unparsable input — the
classifier never guesses in lite's favour.

### Precedence and the tier guard

`tier guard > explicit human token > classifier`. An explicit `full` overrides a
classifier `lite`, and an explicit `lite` overrides a classifier `full`.

The guard runs first: a `production` or `multi-service` repo (the tiers that
add mutation testing and cross-service contract guarantees — see
`docs/CONFORMANCE_TIERS.md`) never resolves to `lite`, and a repo whose
`Conformance tier:` declaration cannot be found never resolves to `lite`
either. A refused `lite` is reported on stderr and recorded as `Chosen: full`
with `Why:` naming the tier. `mvp` follows the precedence above.

The declaration is read from `AGENTS.md` or `AGENTS_*.md` in the spec folder or
any parent directory, and must carry the exact `## Conformance tier: mvp`
heading (or `production` / `multi-service`). A repository that declares no tier
therefore refuses `lite` on every run: until a `Conformance tier:` heading
exists, lite mode is inert here by design — an undeclared repo is treated as
possibly production, never defaulted to `mvp`.

## Stage selection

| Resolved mode | Stages, in order |
|---|---|
| `full` | Specifier → Coder → Refactorer → Verifier → Mutation Runner → PR Opener → Deploy Verifier → Archiver |
| `lite` | Coder → Verifier → `spec-pr-opener` (5b) → `spec-pr-opener` (5d) |

In lite, `spec-refactorer`, `spec-mutation-runner`, `spec-ux`, and
`spec-deployer` are not invoked. A Verifier BLOCK that would have gone back to
`spec-refactorer` under `full` (structural or complexity findings) goes back to
`spec-coder` instead, so the bounded phase-1 loop still applies unchanged.

### Retained gates

Skipping stages never skips a check. In lite the `spec-verifier` still runs:

- the full test suite;
- `scripts/check-no-hardcoded-secrets.sh`;
- `scripts/check-code-principles.sh` (a FAIL blocks);
- scenario traceability.

A FAIL from any of them is a Verifier FAIL: the pipeline stops per the
Stop-and-Ask matrix — there is no PR, no commit, and no push. The remediation
budget is the same in both modes.

## `30-report.md` in lite

The Verifier writes `30-report.md` for a lite run, because the stage that
normally owns the report (the Mutation Runner) is not invoked. It carries:

- `Pipeline mode: lite`;
- one `## <stage>` section per skipped stage, each reading `skipped (lite)` —
  `spec-refactorer`, `spec-mutation-runner`, `spec-ux`, `spec-deployer`;
- the mutation score line reading `skipped (lite)`, so the report's green
  signal is present rather than missing.

The PR Opener accepts that report as green, alongside its unchanged
requirement that the Verifier verdict is PASS.

## Decisions log

Every resolution appends one six-line entry (`Condition:`, `Options:`,
`Chosen:`, `Why:`, `Reversibility:`, `At:`) to
`specs/NNN-slug/45-decisions.md`, the same format and writer as autopilot
(`scripts/autopilot-decisions.sh`). `Chosen:` is `lite` or `full`; `Why:`
names the deciding input — `tier`, `argument`, or `classifier` plus the
classifier's `Reason:` line. A human overrides a logged mode by passing the
opposite token: the new entry is authoritative, the old one untouched.
