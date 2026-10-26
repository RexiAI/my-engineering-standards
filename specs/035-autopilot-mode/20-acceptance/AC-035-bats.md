# AC-035: Bats coverage and traceability

## AC-035-36 — No pipeline agent contains an unconditional ask path
Given the real repo's 9 pipeline agents plus `spec-pipeline.md`
When `scripts/check-stop-and-ask-matrix.sh` runs against the repo root
Then it reports no unconditional-question violation
And it exits 0
