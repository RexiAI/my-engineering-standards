# AC-039-03: Tier guard

## AC-039-03-01 — Production refuses explicit lite
Given tier `production`
And argv contains `lite`
When `scripts/resolve-pipeline-mode.sh` runs
Then resolved mode is `full`
And stderr reports lite refused for tier production

## AC-039-03-02 — Production refuses classifier lite
Given tier `production`
And the classifier outputs `lite`
And no mode token
When mode resolution runs
Then resolved mode is `full`

## AC-039-03-03 — Multi-service
Given tier `multi-service`
And argv contains `lite`
When mode resolution runs
Then resolved mode is `full`

## AC-039-03-04 — Undetectable tier refuses lite
Given no detectable tier
And argv contains `lite`
When mode resolution runs
Then resolved mode is `full`

## AC-039-03-05 — MVP permits lite
Given tier `mvp`
And argv contains `lite`
When mode resolution runs
Then resolved mode is `lite`
