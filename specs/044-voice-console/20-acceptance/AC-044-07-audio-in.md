# AC-044-07: Capture and voice-activity endpointing

## AC-044-07-01 — Two utterances from two tones
Given a 16 kHz mono s16le WAV of `tone(500) + silence(900) + tone(500) + silence(900)`
When `--audio-in file:<fixture>` runs
Then exactly two utterances are emitted
And each utterance length is within one frame of 500 ms

## AC-044-07-02 — Silence produces no utterance
Given a WAV of `silence(1000) + tone(500) + silence(2000)`
When capture runs
Then exactly one utterance is emitted
And no utterance is emitted before the first supra-threshold sample

## AC-044-07-03 — Short blips are dropped
Given a WAV of `tone(100) + silence(900)`
When capture runs with `--min-utterance-ms 300`
Then zero utterances are emitted

## AC-044-07-04 — Long speech is force-split
Given continuous tone of 3500 ms and `--max-utterance-ms 1000`
When capture runs
Then four utterances are emitted
And none is shorter than `--min-utterance-ms`

## AC-044-07-05 — Device mode uses arecord
Given `--audio-in device`
When capture starts
Then a child process is spawned with `arecord -f S16_LE -r 16000 -c 1 -t raw`
And its stdout is fed through the same endpointing path as file mode

## AC-044-07-06 — Missing arecord is a dependency exit
Given `--audio-in device` on a machine with no `arecord` on `PATH`
When capture starts
Then exit code is 3
And stderr names `arecord`
And no ledger record is written

## AC-044-07-07 — File mode spawns nothing
Given `--audio-in file:<fixture>` and an `arecord` shim on `PATH` that exits 99
When capture runs
Then it completes successfully
And the shim was never invoked

## AC-044-07-08 — Fixtures are deterministic
Given `scripts/tests/voice-fixtures.mjs`
When the same `toneMs`, `silenceMs`, and `wav` arguments are used twice
Then both outputs are byte-identical
