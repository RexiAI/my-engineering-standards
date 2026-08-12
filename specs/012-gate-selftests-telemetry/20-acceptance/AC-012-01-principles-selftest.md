# AC-012-01: check-code-principles.sh selftest exercises every gate with the right severity

## AC-012-01-01 — Cyclomatic complexity >6 fires as a FAIL (AC-001)
Given a scratch dir containing a Java file with a method whose body has 7 `if` statements (verified CC=8)
When `check-code-principles.selftest.sh` runs its `cc-bad` fixture with `--gates complexity`
Then the checker output contains a line matching `Cyclomatic complexity >6`
And the line is a FAIL (exit code 1)
And the selftest reports this fixture as passing

## AC-012-01-02 — A complexity value of 6 does not fire (negative control)
Given a scratch dir containing a Java file with a method whose body has 5 `if` statements (verified CC=6)
When `check-code-principles.selftest.sh` runs its `cc-clean` control
Then the checker exits 0 with no `Cyclomatic complexity` finding
And the selftest reports this control as passing

## AC-012-01-03 — KISS method-body-length and parameter-count fire as WARNs
Given a scratch dir containing a Java method with a 22-line body and no conditionals
And another scratch dir containing a Java method with 7 parameters
When the selftest runs its `kiss-lines` and `kiss-params` fixtures with `--gates complexity`
Then `kiss-lines` produces a `Method body >20 lines` line marked WARN and exits 0
And `kiss-params` produces a `Method with >6 parameters` line marked WARN and exits 0
And each WARN fixture exits 1 when the checker is additionally run with `--warn-as-error` (proving WARN, not FAIL)

## AC-012-01-04 — DRY duplicate block fires as a WARN; similar-but-different does not
Given a scratch dir with the same 4-line block in two files (`dry-bad`)
And another scratch dir with two 4-line blocks that differ in one statement each (`dry-clean`)
When the selftest runs both fixtures with `--gates dry`
Then `dry-bad` produces a `Possible duplication` line marked WARN and exits 0 (exit 1 with `--warn-as-error`)
And `dry-clean` exits 0 with no duplication finding

## AC-012-01-05 — YAGNI single-implementation interface fires as a FAIL; empty body as a WARN
Given a scratch dir containing an interface and exactly one class implementing it (`yagni-single-impl`)
And another scratch dir containing a method whose body is `{ }` (`yagni-empty-body`)
When the selftest runs both fixtures with `--gates yagni`
Then `yagni-single-impl` produces a line containing `has exactly one implementation` marked FAIL and exits 1
And `yagni-empty-body` produces an `Empty method body` line marked WARN and exits 0

## AC-012-01-06 — SOLID sub-checks fire with their severities (SRP/OCP/LSP/ISP WARN, DIP FAIL)
Given five scratch fixtures: a 16-method file (srp), a 4-case switch (ocp), a file with 3 `instanceof` (lsp), a 7-method interface (isp), and a `domain/` file importing a `repository.*` package (dip)
When the selftest runs all five with `--gates solid`
Then srp, ocp, lsp, and isp each produce their WARN line (`SRP: possible god file`, `OCP: type-dispatch switch`, `LSP:`, `ISP: fat interface`) and exit 0
And dip produces `DIP: domain/engine code imports` marked FAIL and exits 1
And none of the srp/ocp fixtures additionally produce an `Empty method body` WARN (fixtures avoid empty bodies)

## AC-012-01-07 — Property-test gate fires as a FAIL at production tier when the framework is missing, and passes when present
Given a scratch dir with a Go source file and no `testing/quick` usage (`prop-bad`)
And another scratch dir with a Go `_test.go` using `testing/quick` (`prop-clean`)
When the selftest runs both with `--gates property-tests --tier production`
Then `prop-bad` produces `Property tests (go): no testing/quick` marked FAIL and exits 1
And `prop-clean` exits 0 with no property-tests finding

## AC-012-01-08 — A clean tree passes the full run (no false positives across gates)
Given a scratch dir containing a small well-formed Java file with no violations
When the selftest runs its `clean-tree` control with no `--gates` at default tier
Then the checker exits 0 with no FAIL or WARN lines

## AC-012-01-09 — A missing `--gates` flag is reported loudly, not mis-run
Given a checker that does not yet support `--gates` (spec 007 not merged), so `--gates` errors with `Unknown option` / exit 2
When `check-code-principles.selftest.sh` starts
Then it prints a message that spec 007's `--gates` flag is required
And it exits non-zero

## AC-012-01-10 — Selftest passes only when every fixture and control asserts correctly
Given `scripts/check-code-principles.selftest.sh` exists and is run against a checker where all gates behave as specified
When the selftest completes
Then it exits 0
And on any single assertion failure it prints the failing fixture name, the actual checker output, and the expected assertion, and exits 1
