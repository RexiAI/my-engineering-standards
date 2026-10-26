# AC-034: Task 1 — fallback-reason taxonomy

## AC-034-01 — Unconfigured wrapper falls back with reason `unconfigured`
Given `JUDGMENT_BACKEND` is unset or empty
And `JUDGMENT_API_URL` is unset or empty
And a valid `--questions` JSON and a non-empty state are supplied
When `scripts/typed-judgment.sh` is invoked
Then the script exits 10
And stderr contains exactly one line matching `typed-judgment: reason=unconfigured`
And no network request is attempted

## AC-034-02 — Unreachable backend falls back with reason `unreachable`
Given `JUDGMENT_BACKEND=local`
And `JUDGMENT_API_URL` points at a port with no listener (connection refused)
And `JUDGMENT_BACKOFF_SECONDS=0`
When `scripts/typed-judgment.sh` is invoked with a valid state and questions
Then the script exits 10
And stderr contains exactly one line matching `typed-judgment: reason=unreachable`

## AC-034-03 — Daily cap exceeded falls back with reason `error`
Given `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` is set
And today's counter file already holds a count at or above `JUDGMENT_DAILY_CAP`
When `scripts/typed-judgment.sh` is invoked with a valid state and questions
Then the script exits 10 without making a network request
And stderr contains exactly one line matching `typed-judgment: reason=error`

## AC-034-04 — Below-threshold confidence falls back with reason `error`
Given `JUDGMENT_BACKEND=local` and `JUDGMENT_API_URL` points at a mock returning
a valid 200 body whose answer confidence is below `JUDGMENT_MIN_CONFIDENCE`
When `scripts/typed-judgment.sh` is invoked
Then the script exits 10
And stderr contains exactly one line matching `typed-judgment: reason=error`

## AC-034-05 — Reason line never leaks the key or an untruncated state
Given `JUDGMENT_API_KEY` is set to a known secret value
And the state payload is larger than the diagnostic truncation window
And the wrapper falls back (any reason)
When `scripts/typed-judgment.sh` is invoked
Then the secret value does not appear anywhere on stdout or stderr
And the full state payload does not appear on stdout or stderr
