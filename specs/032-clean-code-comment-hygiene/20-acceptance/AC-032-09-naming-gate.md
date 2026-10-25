# AC-032-09: The naming gate reports five advisory heuristics

_Fixture note: unless a scenario states otherwise, every line under test sits at line 6 or later, so the first-five-lines allowlist (AC-032-07-01) does not mask the finding._

## AC-032-09-01 — Single-character identifiers fire, loop counters do not
Given a Java file containing `int x = 1;`, `int j = 2;`, and two `for (int i = ...; ...; i++)` / `for (int k = ...; ...; k++)` loops
When `bash scripts/check-code-principles.sh --gates naming <dir>` runs
Then the output contains exactly one `Naming: single-character identifier` finding
And it names the line declaring `x`
And the run exits 0

## AC-032-09-02 — Noise words fire at word boundaries only
Given a Java file declaring `class UserManager`, `class Data`, and `class Managerial`
When `--gates naming` runs
Then the output contains two `Naming: noise word in type name` findings
And it names `UserManager` and `Data`
And it does not name `Managerial`

## AC-032-09-03 — Encoded identifiers fire, ordinary camelCase does not
Given a Java file declaring `String strName`, `int iCount`, and `int index`
When `--gates naming` runs
Then the output contains two `Naming: encoded identifier` findings
And it names `strName` and `iCount`
And it does not name `index`

## AC-032-09-04 — Boolean flag parameters fire, other booleans do not
Given a Java file with `void save(boolean hasAccess)` and `void load(boolean access)`
And a TypeScript file with `function save(hasAccess: boolean): void {}`
When `--gates naming` runs
Then the output contains two `Naming: boolean flag parameter` findings
And neither names `access`

## AC-032-09-05 — More than three parameters fires at four, not at three
Given a Java file with `void three(int a, int b, int c)` and `void four(int a, int b, int c, int d)`
When `--gates naming` runs
Then the output contains exactly one `Naming: more than three parameters` finding
And it names `four`

## AC-032-09-06 — Naming never emits FAIL and never scans shell
Given the fixture from AC-032-09-01
When `--gates naming --blocking naming` runs with `STRICT_CLEAN_CODE=1`
Then every `Naming:` finding is prefixed `WARN`
And the output contains no `FAIL` prefix on any `Naming:` finding
And the run exits 0
And a shell file containing `x=1` and `y=2` produces no `Naming:` finding under `--gates naming`
