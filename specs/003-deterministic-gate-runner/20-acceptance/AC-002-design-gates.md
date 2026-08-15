# AC-002: Design gates make SOLID/DRY/YAGNI/KISS mechanical

## AC-002-01 — `design-checker.sh` implements D1–D11
Given `scripts/gates/design-checker.sh`
When the file is searched for the regex `D[1-9]|D1[0-1]`
Then at least eleven distinct D-gate definitions appear

## AC-002-02 — Defaults match the spec exactly
Given `scripts/gates/design-gates.defaults.json`
When it is read
Then `d1_size_complexity.maxClassLines` equals 300
And `d1_size_complexity.maxMethodLines` equals 30
And `d1_size_complexity.maxCyclomaticComplexity` equals 10
And `d2_single_responsibility.maxConstructorDependencies` equals 5
And `d3_interface_segregation.maxInterfaceMethods` equals 7
And `d5_duplication.minDuplicateBlockLines` equals 5
And `d7_coupling.maxProjectImports` equals 10
And `d11_kiss.warnAtSignals` equals 3
And `d11_kiss.blockAtSignals` equals 5

## AC-002-03 — Design gates are scoped to the diff
Given the design-checker is run with `-BaseRef <base>`
When it computes the changed files set
Then it uses `git diff <base>...HEAD --name-only` (or equivalent)
And pre-existing violations in a touched file are reported as WARN

## AC-002-04 — Newly introduced violations BLOCK
Given a diff that introduces a new oversized class
When the design-checker is run on `-BaseRef <base>`
Then D1 reports BLOCK for the new violation
