# AC-031: Pipeline documentation rewrite

## AC-031-11 — Stage table lists 5a through 5d
Given `docs/SPEC_PIPELINE.md` has been updated
When the stage table is read
Then it contains four rows for stages 5a (Mutation Runner), 5b (PR Opener, no longer archives), 5c (Deploy Verifier, spec-deployer), and 5d (Archiver, spec-pr-opener)

## AC-031-12 — Artifact layout includes 40-deploy.md
Given `docs/SPEC_PIPELINE.md` has been updated
When the artifact layout section is read
Then it lists `40-deploy.md` with a description of its purpose (deploy evidence: URL, build status, health check, E2E verdict)

## AC-031-13 — Definition of done requires 40-deploy.md
Given `docs/SPEC_PIPELINE.md` has been updated
When the definition of done section is read
Then it includes a numbered item requiring `40-deploy.md` present with a verdict or a recorded skip reason

## AC-031-14 — Commit-and-push carve-out names 5d
Given `docs/SPEC_PIPELINE.md` has been updated
When the commit-and-push carve-out section is read
Then it explicitly names stage 5d alongside 5b as permitted to commit and push on the `spec/NNN-slug` branch

## AC-031-15 — Pipeline-finishes sentence rewritten
Given `docs/SPEC_PIPELINE.md` has been updated
When the sentence previously at line 233 is read
Then it names stage 5d (the Archiver) as the final act, not stage 5b

## AC-031-16 — Phase ordering is explicit
Given `docs/SPEC_PIPELINE.md` has been updated
When the remediation-budget or phase-ordering section is read
Then it states that phase-3 deploy verification runs only after phase-2 post-PR CI is green, and the two phases must not race
