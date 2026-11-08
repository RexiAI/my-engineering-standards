# AC-044-04: Pocket TTS worker

## AC-044-04-01 — Self-check works without optional packages
Given a machine with no PyTorch and no Pocket TTS installed
When `python3 scripts/voice/tts-worker.py --self-check` runs
Then exit code is 0
And stdout parses as one JSON object with keys `python`, `pocket_tts`, `torch`, `sample_rate`
And `pocket_tts` and `torch` are booleans
And no network request is made and no weights are downloaded

## AC-044-04-02 — Silent engine writes a valid WAV
Given `--engine silent` and `--sample-rate 24000`
When the worker receives `{"id":"u1","text":"Hello there.","out":"<tmp>/u1.wav"}`
Then `<tmp>/u1.wav` exists
And its header declares RIFF/WAVE, 1 channel, 16-bit samples, and sample rate 24000
And it contains at least one audio frame

## AC-044-04-03 — Event order for a request
Given a valid request line
When the worker synthesises it
Then stdout emits `{"id":"u1","event":"start"}` first
And at least one `{"event":"chunk","bytes":N}` line follows
And the last line for that id is `{"event":"done","path":...,"durationMs":...,"sampleRate":...,"cancelled":false}`
And the worker stays alive waiting for the next request

## AC-044-04-04 — Bad request does not kill the worker
Given a request line with an empty `text`
When the worker processes it
Then it emits `{"event":"error","code":"bad-request","message":...}` for that id
And a subsequent valid request still produces a `done` event

## AC-044-04-05 — Cancel request stops the utterance
Given a long request `u1` in progress
When the worker receives `{"event":"cancel","id":"u1"}`
Then it emits `done` for `u1` with `cancelled:true`
And no further `chunk` line for `u1` appears within 500 ms
And the worker remains alive

## AC-044-04-06 — SIGINT cancels and exits cleanly
Given a long request in progress
When the worker receives `SIGINT`
Then it emits `done` with `cancelled:true` for the in-flight id
And it exits 0 within 2 s

## AC-044-04-07 — Missing Pocket TTS runtime is a dependency exit
Given `--engine pocket-tts` on a machine where the package is not importable
When the worker receives a request
Then it emits `{"event":"error","code":"missing-runtime"}`
And it exits 3

## AC-044-04-08 — Duration arithmetic is exact
Given a completed request written at `--sample-rate 24000`
When `durationMs` and the WAV frame count are compared
Then `durationMs` equals `frames * 1000 / 24000` within 1 ms

## AC-044-04-09 — The worker is file-only
Given the worker source
When it is searched for `sounddevice`, `pyaudio`, or a playback subprocess
Then none is present
And the only path the worker writes is the `out` value it was given
