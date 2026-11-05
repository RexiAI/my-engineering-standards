# AC-039-04: Mode resolution and decision logging

## AC-039-04-01 — Classifier decides when no token
Given tier `mvp`, no mode token, classifier `lite`
When `scripts/resolve-pipeline-mode.sh` runs
Then resolved mode is `lite`
And `45-decisions.md` gains one entry with `Chosen: lite` and `Why:` naming `classifier`

## AC-039-04-02 — Human full overrides classifier lite
Given tier `mvp`, argv `full`, classifier `lite`
When mode resolution runs
Then resolved mode is `full`
And the entry's `Why:` names `argument`

## AC-039-04-03 — Human lite overrides classifier full
Given tier `mvp`, argv `lite`, classifier `full`
When mode resolution runs
Then resolved mode is `lite`
And the entry's `Why:` names `argument`

## AC-039-04-04 — Tier refusal is logged
Given tier `production`, argv `lite`
When mode resolution runs
Then the entry has `Chosen: full` and `Why:` names `tier`

## AC-039-04-05 — Entry format and append-only
Given `45-decisions.md` already contains one entry
When mode resolution runs
Then the file contains two entries
And the first entry is byte-identical to before
And the new entry has the six labelled lines `Condition:`, `Options:`, `Chosen:`, `Why:`, `Reversibility:`, `At:`
And `At:` matches `YYYY-MM-DDTHH:MM:SSZ`

## AC-039-04-06 — Writes stay in spec folder
Given a clean git tree
When mode resolution runs
Then `git status --porcelain` lists only paths under `specs/NNN-slug/`
