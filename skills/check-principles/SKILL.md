---
name: check-principles
description: Run the design-principles audit (KISS, DRY, YAGNI, SOLID, cyclomatic complexity, property tests) against any Java, Go, or JS/TS code in the repo. Use when a user says "check the code principles", "does this violate SOLID/DRY/KISS/YAGNI", "audit design principles", or when the spec-verifier must independently confirm the Refactorer's complexity/duplication/property-test claims.
license: See repo root
allowed-tools: Bash(.standards/scripts/check-code-principles.sh:*) Bash(./.standards/scripts/check-code-principles.sh:*)
---

# When to use

When the repo's code should be checked against the design principles in
`docs/CODING_CONVENTIONS.md §Design Principles` and `docs/ARCHITECTURE.md` —
complexity, duplication, premature abstraction, SOLID violations, and
property-test coverage. The spec pipeline's Verifier stage runs this as an
independent re-check of the Refactorer's claims; run it standalone any time
someone wants a design audit without waiting for the pipeline.

# Invocation

Run from the repo root (child repos use the submodule path):

```bash
# Audit the whole repo, auto-detecting the conformance tier
./.standards/scripts/check-code-principles.sh

# Audit a specific directory with an explicit tier
./.standards/scripts/check-code-principles.sh path/to/service --tier production

# Treat every WARN as a failure (strict gate)
./.standards/scripts/check-code-principles.sh --warn-as-error

# Blame scoping: judge only the change against the diff vs <ref>
./.standards/scripts/check-code-principles.sh -BaseRef <base-ref>

# Restrict which gates may emit FAIL (see severity table below)
./.standards/scripts/check-code-principles.sh --blocking complexity,property-tests,dry
```

# Severity and blocking set

The script runs five gate categories: `complexity` (cyclomatic CC + KISS size
findings), `dry`, `yagni`, `solid` (SRP/OCP/LSP/ISP/DIP as one unit), and
`property-tests`. Only the gates in the **blocking set** may emit FAIL; every
other gate is warn-only — a judgment call that never blocks, with or without
`-BaseRef`.

| Gate | Default severity | Notes |
|---|---|---|
| complexity | **FAIL** (blocking) | CC>6 and KISS size findings. Blame-scoped with `-BaseRef` |
| property-tests | **FAIL** at `production`+ tier (blocking) | Presence check — never blame-scoped |
| dry | WARN | Judgment |
| yagni | WARN | Judgment (single-implementation interfaces are no longer FAIL) |
| solid | WARN | Judgment (DIP is no longer FAIL) |

Default blocking set: `complexity,property-tests` (the objective gates).
Override with `--blocking <comma-list>` or the `PRINCIPLES_BLOCKING_GATES`
environment variable — flag wins over env over default; an unknown gate name or
an empty value exits 2. With `-BaseRef <ref>`, only files present in the diff
are evaluated: a blocking-gate finding whose line range overlaps an added line
is FAIL, pre-existing debt in a touched file is WARN, and findings in untouched
files are not reported.

# What the script does

Runs the same heuristics on every language present (Java, Go, JS/TS, React
Native), so it works with no per-project linter configuration:

| Principle | What it flags |
|---|---|
| Cyclomatic complexity | Methods with >6 decision points (mirrors the ≤6 rule) |
| KISS | Bodies >20 lines, >6 parameters, deep nesting |
| DRY | Identical 4-line blocks appearing in 2+ places |
| YAGNI | Interfaces with exactly one implementation, empty method bodies |
| SOLID | SRP (god file), OCP (large switch/else-if chains), LSP (instanceof dispatch), ISP (fat interfaces), DIP (domain→infrastructure imports) |
| Property tests | Missing jqwik / testing.quick / fast-check at `production` tier and above |

# What it is not

A proof. It is a heuristic gate that catches the common shapes the principles
forbid and points at exact file:line evidence. Real linters (PMD,
golangci-lint, eslint) remain the authoritative complexity gate; the language
skill files (`language-specific/<lang>/SKILL.md`) list those commands.

# Exit codes

- `0` — no FAILs (WARNs are review hints unless `--warn-as-error`)
- `1` — at least one FAIL, or a WARN with `--warn-as-error`
