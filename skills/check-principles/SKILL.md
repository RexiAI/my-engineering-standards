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
```

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
