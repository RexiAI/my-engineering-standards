# AC-034: Task 7 — `make judgment-status` operator surface

## AC-034-26 — Reports liveness (running with pid and port, or stopped)
Given `scripts/judgment-status.sh` and a mock backend with a tracked PID file
When the script is invoked with the backend running
Then it reports `running` with a pid and a port
And it exits 0 for the liveness portion
Given no tracked process and no healthy endpoint
When the script is invoked
Then it reports `stopped`

## AC-034-27 — Reports payload fitness with small and max-size probes
Given `scripts/judgment-status.sh` and a mock backend that answers a small
choice request and a cap-sized request (12288-byte state)
When the script is invoked
Then it reports both probes passing
And it exits 0

## AC-034-28 — Max-size probe failure is reported, not a crash
Given a mock backend that answers the small probe but fails or errors on the
cap-sized request (a backend healthy on `/v1/models` but not on large payloads)
When `scripts/judgment-status.sh` is invoked
Then it reports the max-size probe as failing
And it exits non-zero
And the status script itself does not crash (it completes with its report)
