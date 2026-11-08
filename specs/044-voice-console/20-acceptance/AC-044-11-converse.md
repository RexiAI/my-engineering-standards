# AC-044-11: Converse mode

## AC-044-11-01 — Two utterances become two prompts and two replies
Given `--mode converse --session ses_parent` with a file-based capture of two utterances
And a transcript file with two non-blank lines
And a fake server that replies `Still running.`
When the run completes
Then the recorder holds exactly two prompt requests in utterance order
And each carries the verbatim transcript line
And the ledger has exactly two `spoken` records with the reply text

## AC-044-11-02 — Turns increment and stay contiguous
Given the same two-utterance run
When the ledger is read
Then the first turn's records carry `turn: 1` and the second turn's carry `turn: 2`
And the records of each turn are contiguous in `seq`

## AC-044-11-03 — Empty transcript sends nothing
Given a transcript line that is blank after trimming
When the run reaches that utterance
Then one `skipped-utterance` record is written
And the recorder still holds one prompt

## AC-044-11-04 — Reply budget applies, and more resumes it
Given a fake server reply of four sentences
When the turn completes
Then three `spoken` records and one `deferred` record are written
And `--input-script` supplying `m` speaks the fourth sentence

## AC-044-11-05 — A missing session is created with the concierge agent
Given `--mode converse` with no `--session`
And no `--agent`
When the first prompt is sent
Then the client creates a session with agent `voice-concierge`
And the first `prompt-sent` record's `detail` carries the returned session id

## AC-044-11-06 — Device capture without a device fails loudly
Given `--mode converse --audio-in device` on a host with no capture device
When the run starts
Then exit code is 3
And stderr names `arecord`
