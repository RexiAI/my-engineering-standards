# AC-033: Deploy — --with-deploy kamal|dokku|ssh|vercel

## AC-033-35 — VPS tools forward to init-ci --deploy-tool
Given `bootstrap.sh --with-deploy kamal` (or `dokku`, or `ssh`)
When the script runs
Then `init-ci.sh` is invoked with `--deploy-tool kamal` (or `dokku`, or `ssh` respectively)

## AC-033-36 — `--with-deploy vercel` wires the Vercel lane
Given a frontend repo
When `bootstrap.sh --with-deploy vercel` runs
Then the Vercel production-verify lane is wired per OQ-9

## AC-033-37 — missing or unknown deploy tool is refused
Given `bootstrap.sh --with-deploy` with a missing or unrecognized tool
When the script runs
Then the run is refused with a named reason
And the exit code is non-zero
