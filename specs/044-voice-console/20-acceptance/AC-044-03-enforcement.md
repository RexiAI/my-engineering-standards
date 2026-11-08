# AC-044-03: Enforcement at the outbound boundary

## AC-044-03-01 — A blocked action is never sent
Given mode `control` with a fake server recorder
And a `permission.asked` event whose bash command is `git push origin main`
When the bridge decides what to reply
Then the recorder contains zero requests
And the ledger contains one `refused` record with rule `push-main`
And stderr contains `refused: push-main`

## AC-044-03-02 — No flag overrides a never-list refusal
Given the same blocked permission event
When the bridge runs with `--input-script` containing `y`
Then the recorder still contains zero requests
And stderr still contains `refused: push-main`
And `--yes` is rejected as an unknown flag with exit 2

## AC-044-03-03 — One reply path, guard first
Given `scripts/voice/opencode-client.mjs` exports the only reply-sending function
When the source tree is searched for importers of that function
Then `scripts/voice/control.mjs` is the only importer
And in `control.mjs` every call to it is immediately preceded by a `guard.authorize` call

## AC-044-03-04 — Mutating tools need terminal confirmation
Given a `permission.asked` event for a bash command `rm -rf build`
When `guard.authorize` classifies it
Then the result is not blocked and `requiresConfirmation` is true
And the bridge sends nothing until a terminal `y` arrives

## AC-044-03-05 — Read-only tools may be answered by voice
Given a `permission.asked` event for tool `read`
When `guard.authorize` classifies it
Then the result is not blocked and `requiresConfirmation` is false
And a spoken `yes` sends the reply

## AC-044-03-06 — Policy refusal is a distinguishable exit
Given a run whose only remaining action was a blocked one and no further work is pending
When the process exits
Then exit code is 4
And stderr contains `refused: <rule>` with the rule id verbatim
