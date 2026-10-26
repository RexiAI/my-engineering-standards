# AC-034: Task 3 — fail-open preflight script

## AC-034-12 — Healthy local backend is recorded, exit 0
Given `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` points at a mock that
returns a usable answer to a small choice request
When `scripts/judgment-preflight.sh` is invoked
Then the script exits 0
And stdout contains exactly one line containing `healthy`
And the probe was made through `scripts/typed-judgment.sh` (one request recorded)

## AC-034-13 — Backend down prints exactly one warning and exits 0
Given `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` points at a port with no listener
When `scripts/judgment-preflight.sh` is invoked
Then the script exits 0
And stderr contains exactly one warning line
And that line contains `make judgment-up`
And that line contains `continuing without`
And that line contains the fallback reason `unreachable`

## AC-034-14 — Unset or hosted-unconfigured is silent
Given `JUDGMENT_BACKEND` is unset or empty
When `scripts/judgment-preflight.sh` is invoked
Then the script exits 0
And it prints nothing to stdout or stderr
And no probe call is made
Given `JUDGMENT_BACKEND=hosted` and `JUDGMENT_API_URL` unset
When `scripts/judgment-preflight.sh` is invoked
Then the script exits 0 and prints nothing

## AC-034-15 — `--require-judgment` turns a failed probe into a hard exit
Given `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` points at a port with no listener
When `scripts/judgment-preflight.sh --require-judgment` is invoked
Then the script exits non-zero
And stderr contains the warning line
Given `JUDGMENT_REQUIRED=1` (flag absent)
When `scripts/judgment-preflight.sh` is invoked against the same dead backend
Then the script exits non-zero

## AC-034-16 — Probe result is cached; a second run within TTL does not re-probe
Given `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` points at a live mock
When `scripts/judgment-preflight.sh` is invoked once
Then a cache file is written under the configured cache directory with the outcome
When `scripts/judgment-preflight.sh` is invoked again within the TTL
Then no second probe request is recorded (the cached outcome is reused)
And the script still exits 0
