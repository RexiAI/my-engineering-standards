# AC-044-09: Playback and cancellation

## AC-044-09-01 — File sink numbers sequentially
Given `--audio-out file:<tmp>/audio` and an empty directory
When three utterances are played
Then three files exist named `0001.wav`, `0002.wav`, `0003.wav`
And each is a valid WAV

## AC-044-09-02 — Existing files are never overwritten
Given `<tmp>/audio/0001.wav` already exists
When one utterance is played to the same directory
Then the pre-existing `0001.wav` is byte-identical to before
And a new `0002.wav` exists

## AC-044-09-03 — File mode spawns no child process
Given `--audio-out file:<tmp>/audio`
And an `ffplay` shim on `PATH` that exits 99
When an utterance is played
Then playback reports success
And the shim was never invoked

## AC-044-09-04 — Device mode plays through ffplay
Given `--audio-out device`
When an utterance is played
Then one `ffplay -nodisp -autoexit -loglevel quiet <path>` process is spawned per file

## AC-044-09-05 — Missing ffplay is a dependency exit
Given `--audio-out device` on a machine with no `ffplay` on `PATH`
When playback starts
Then exit code is 3
And stderr names `ffplay`

## AC-044-09-06 — Cancellation stops playback promptly
Given a playing utterance in device mode held open by a stub player
When `cancel()` is called
Then it returns `{cancelled:true}`
And the player process has exited within 500 ms
And if it had not exited, it is killed after 1 s

## AC-044-09-07 — A new utterance supersedes the old one
Given one utterance playing
When a second utterance starts
Then the first reports `cancelled` with reason `superseded`
And playback depth never exceeds one
