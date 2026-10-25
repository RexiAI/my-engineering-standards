# AC-032-02: The gate catalog registers nine gates

## AC-032-02-01 — The three new names are accepted by --gates and --blocking
Given a throwaway source directory containing one trivial `Thing.java` file
When `bash scripts/check-code-principles.sh --gates comments <dir>` runs
And `bash scripts/check-code-principles.sh --gates naming <dir>` runs
And `bash scripts/check-code-principles.sh --gates null-discipline <dir>` runs
And `bash scripts/check-code-principles.sh --gates comments,naming,null-discipline <dir>` runs
And `bash scripts/check-code-principles.sh --blocking comments <dir>` runs
Then each run exits 0
And no run writes `unknown gate` or `Unknown option` to stderr

## AC-032-02-02 — Unknown and empty gate values still exit 2 and list all nine
Given a throwaway source directory
When `--gates bogus`, `--gates ""`, `--blocking bogus`, and `--blocking ""` are each run
Then each run exits 2
And the `--gates bogus` stderr contains `(valid: complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline)`
And the `--blocking bogus` stderr contains `unknown gate name in blocking set: 'bogus'`
And it contains `valid gates: complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline`
And the empty-value messages each list all nine names

## AC-032-02-03 — A default run selects nine gates, a scoped run says so in the summary
Given a throwaway source directory containing one trivial `Thing.java` file
When the script runs with `--json` and no `--gates`
Then the output parses as JSON
And its `gates` array equals `["complexity","dry","yagni","solid","component-per-file","property-tests","comments","naming","null-discipline"]`
And when the script runs without `--json` and without `--gates`, its output contains no `(gates:` substring
And when it runs with `--gates comments,naming`, its output contains `(gates: comments,naming)`

## AC-032-02-04 — Help text documents the three gates, the allowlist, and the strict switch
Given `scripts/check-code-principles.sh`
When its header comment block and usage block are read
Then they contain `comments`, `naming`, `null-discipline`, and `STRICT_CLEAN_CODE`
And they document the commented-out-code and restating-comment rules as blocking-class
And they document the TODO/FIXME, section-divider, and attribution rules as advisory
And they document the allowlist categories (first five lines, `shellcheck`, `noqa`, `type: ignore`, `pragma`, `ponytail:`, `standards:allow-`, licence markers, URLs, public-API doc blocks)
And they state that `naming` and `null-discipline` never emit FAIL
And the header still contains `Default blocking set: complexity,property-tests`
And the script contains `> 6` and no `--threshold` or `--complexity <n>` override option

## AC-032-02-05 — Each new gate has its own dispatch block
Given a throwaway source directory containing one trivial `Thing.java` file
When the script runs with `--gates comments,naming,null-discipline`
Then its output contains the section headings `--- Comments ---`, `--- Naming ---`, and `--- Null discipline ---`
And it contains at least one `PASS` line for each of the three gates
And no complexity, DRY, YAGNI, SOLID, component-per-file, or property-tests section heading appears
