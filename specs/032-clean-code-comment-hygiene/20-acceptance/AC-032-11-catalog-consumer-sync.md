# AC-032-11: Every catalog consumer agrees on the nine gates

## AC-032-11-01 — Gate consistency passes with nine gates
Given `scripts/check-code-principles.sh` registers nine gates
When `bash scripts/check-gate-consistency.sh` runs
Then it exits 0
And its output contains `Canonical gate list (from check-code-principles.sh): complexity,dry,yagni,solid,component-per-file,property-tests,comments,naming,null-discipline`
And its output contains `Check 4: gate count = 9 (expected 9)`
And its output contains `PASS — 9 gates`
And its output contains no `FAIL —`

## AC-032-11-02 — The blame suite reflects that naming is now a gate
Given `scripts/tests/check-code-principles-blame.sh`
When the suite runs
Then it exits 0
And no output line begins with `FAIL`
And the source no longer contains the assertion string `unknown gate name in blocking set: 'naming'`
And the source still asserts that `test-delta` is unknown via `unknown gate name in blocking set: 'test-delta'`
And the source cites spec 032 in the AC-011-03-07 section comment and in the header list
And the source contains the nine-name expected list `complexity, dry, yagni, solid, component-per-file, property-tests, comments, naming, null-discipline`
And the AC-011-03-01 header-literal and AC-011-03-08 skill-literal assertions still pass unchanged

## AC-032-11-03 — CODING_CONVENTIONS documents the new gates
Given `docs/CODING_CONVENTIONS.md`
When the `## Design Principles` section is read
Then it contains a block naming `comments`, `naming`, and `null-discipline`
And it states that all three are WARN by default
And it names `STRICT_CLEAN_CODE=1` as the opt-in blocking switch
And it links `docs/adr/0011-clean-code-comment-gates.md`
And the existing bullet `Comment the why, not the what` is still present verbatim

## AC-032-11-04 — The check-principles skill lists all nine gates
Given `skills/check-principles/SKILL.md`
When it is read
Then it contains `comments`, `naming`, `null-discipline`, and `STRICT_CLEAN_CODE`
And it no longer claims `five gate categories`
And its severity table has a row beginning `| comments |`, `| naming |`, and `| null-discipline |`
And it still contains `complexity,property-tests`, `warn-only`, `-BaseRef`, and `--blocking`
