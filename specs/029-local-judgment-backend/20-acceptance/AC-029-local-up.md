# AC-029: judgment-local-up.sh

## AC-029-30 — Up starts server and prints env lines
Given the winning recipe is configured in `scripts/judgment-local-up.sh` (command, port, health endpoint from spike report)
And no server is currently running
When `scripts/judgment-local-up.sh up` is invoked
Then the server process starts
And the health endpoint is polled until it responds or timeout (default 120s)
And on success, the script prints `JUDGMENT_BACKEND=local`, `JUDGMENT_API_URL=http://localhost:<port>/v1/systemone`, and any other required `JUDGMENT_*` lines
And the exit code is 0

## AC-029-31 — Up is idempotent when server already running
Given the local server is already running and healthy
When `scripts/judgment-local-up.sh up` is invoked
Then no duplicate process is started
And the script prints the env lines
And the exit code is 0

## AC-029-32 — Down stops the server
Given the local server is running (PID file exists)
When `scripts/judgment-local-up.sh down` is invoked
Then all server processes are stopped
And the PID file is removed
And the exit code is 0

## AC-029-33 — Down is idempotent when server not running
Given no local server is running (no PID file)
When `scripts/judgment-local-up.sh down` is invoked
Then the exit code is 0
And stderr or stdout reports "not running"

## AC-029-34 — Status reports running or stopped
Given the local server is running
When `scripts/judgment-local-up.sh status` is invoked
Then stdout contains "running" with PID and port
And the exit code is 0

Given the local server is not running
When `scripts/judgment-local-up.sh status` is invoked
Then stdout contains "stopped"
And the exit code is 0

## AC-029-35 — Health times out when server unresponsive
Given `JUDGMENT_LOCAL_TIMEOUT_SECONDS=2`
And no server is listening on the configured port
When `scripts/judgment-local-up.sh health` is invoked
Then the exit code is non-zero
And stderr reports the timeout

## AC-029-36 — Script refuses to run as root
Given the current user is root (UID 0)
When `scripts/judgment-local-up.sh up` is invoked
Then the exit code is non-zero
And stderr contains a diagnostic refusing to run as root

## AC-029-37 — Logs and PID files in gitignored directory
Given `scripts/judgment-local-up.sh` is invoked with `up`
When the server starts
Then log files are written to `.cache/judgment-local/` (or configured gitignored dir)
And PID files are written to the same gitignored directory
And `.gitignore` covers the directory
And no files are created in the repo tree outside `.cache/`

## AC-029-38 — Makefile targets exist
Given the repo's `Makefile`
When `make judgment-up` is invoked
Then it invokes `scripts/judgment-local-up.sh up`
When `make judgment-down` is invoked
Then it invokes `scripts/judgment-local-up.sh down`
