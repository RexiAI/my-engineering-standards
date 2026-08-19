# load-env.ps1 — PowerShell twin of scripts/load-env.sh. Same behavior
# contract:
#   - if config/agent.local.env exists: read it and export every KEY=value it
#     defines (comments and blanks skipped, CRLF tolerated);
#   - never clobber a variable already set in the environment — a pre-existing
#     value wins, so a machine-level override survives;
#   - if the real file is missing but config/agent.local.env.example exists:
#     fail loudly, naming the missing path and the copy-fill step, exit 1;
#   - if both files are missing: no-op, exit 0.
#
# Not executed in CI (the self-ci ubuntu-latest image has no PowerShell) — its
# acceptance is existence plus this documented parity contract; keep it in sync
# with load-env.sh by hand.
#
# Usage:
#   .\scripts\load-env.ps1 [REPO_ROOT]
# REPO_ROOT defaults to the repo root (parent of the scripts/ directory).
#
# Exit codes:
#   0 — loaded (or nothing to load)
#   1 — real file missing while the example exists
param(
  [string]$Root = ""
)
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Root) { $Root = Split-Path -Parent $scriptDir }

$real = Join-Path $Root 'config\agent.local.env'
$example = Join-Path $Root 'config\agent.local.env.example'

if (Test-Path -LiteralPath $real) {
  Get-Content -LiteralPath $real | ForEach-Object {
    if ($_ -match '^\s*(#|$)') { return }
    if ($_ -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      $name = $matches[1]
      $value = $matches[2]
      if (-not [Environment]::GetEnvironmentVariable($name, 'Process')) {
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
      }
    }
  }
  exit 0
}

if (Test-Path -LiteralPath $example) {
  Write-Error "ERROR: $real not found, but $example exists. Copy it and fill in real values:`n  cp config/agent.local.env.example config/agent.local.env"
  exit 1
}

exit 0
