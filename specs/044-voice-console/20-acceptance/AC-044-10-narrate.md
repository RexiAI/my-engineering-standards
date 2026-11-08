# AC-044-10: Narrate mode

## AC-044-10-01 — Narrate never captures and never transcribes
Given `--mode narrate --session ses_parent`
And an `arecord` shim on `PATH` that exits 99
When the event stream is consumed
Then the shim is never invoked
And the ledger contains no `prompt-sent` record and no transcript record

## AC-044-10-02 — Budget and parent-only filtering end to end
Given a fixture stream with five assistant sentences for the parent session
And one subtask paragraph for the same session
And `--tts-engine silent --audio-out file:<tmp>/audio --artifacts <tmp>/run`
When the stream ends
Then the ledger has exactly three `spoken` records and one `deferred` record
And `audio/` holds exactly `0001.wav`, `0002.wav`, `0003.wav`
And no ledger `text` contains any word from the subtask paragraph
And every record for this turn has `turn: 1`
And `seq` runs 1..N contiguously

## AC-044-10-03 — The operator can ask for the rest
Given the previous run wrote a `deferred` record for two sentences
When `--input-script` supplies `m`
Then a `resumed` record is written followed by `spoken` records covering both deferred sentences
And two further WAV files are written

## AC-044-10-04 — Requesting more after exhaustion is recorded, not silent
Given every deferred sentence has been spoken
When `--input-script` supplies `m` again
Then one `nothing-more` record is written
And no new WAV file appears

## AC-044-10-05 — Stop cancels the current utterance
Given an utterance is being spoken
When `--input-script` supplies `stop`
Then one `cancelled` record is written for that utterance
And the process keeps running and accepts the next streamed sentence

## AC-044-10-06 — SIGINT exits cleanly, twice forces exit
Given a run in progress
When the process receives `SIGINT`
Then one `cancelled` record is written
And the process exits 0 within 2 s
And when it receives `SIGINT` a second time during the first cancellation
Then it exits 130

## AC-044-10-07 — Non-interactive stdin never blocks
Given stdin is `/dev/null` and `--input-script` is absent
When the event stream ends
Then the process exits 0
And it did not wait on stdin
