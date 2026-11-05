# AC-039-07: Documentation and ADR

## AC-039-07-01 — ADR exists and is indexed
Given the change is applied
When `docs/adr/` is listed
Then a file matching `docs/adr/*-pipeline-lite-mode.md` exists with status `Proposed`
And `docs/adr/README.md` links it

## AC-039-07-02 — SPEC_PIPELINE documents lite mode
Given the change is applied
When `docs/SPEC_PIPELINE.md` is read
Then a `## Lite mode` section exists
And it names `scripts/lite-trigger.sh`, `scripts/classify-spec-size.sh`, `scripts/resolve-pipeline-mode.sh`, the tier refusal, skipped stages, retained gates, `45-decisions.md`, and links the ADR

## AC-039-07-03 — Standards checks pass
Given the change is applied
When `scripts/check-orchestration.sh` and `scripts/check-skills.sh` run
Then both exit 0
