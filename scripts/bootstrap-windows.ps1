# bootstrap-windows.ps1 — one-shot Windows setup for the provider-agnostic
# media agent family and opencode desktop. Run in PowerShell (no admin needed
# for user-scoped installs; winget may prompt once for package agreements).
#
#   powershell -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1
#
# Idempotent: every step checks before installing. No media provider is
# installed or assumed — after this script, edit
# %USERPROFILE%\.config\opencode\media\backends.json and fill in the commands
# your machine provides.

$ErrorActionPreference = "Stop"

function Step($name, $block) {
  Write-Host "`n== $name ==" -ForegroundColor Cyan
  & $block
}

Step "Node.js LTS" {
  if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements
  } else { Write-Host "node present: $(node --version)" }
}

Step "git" {
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements
  } else { Write-Host "git present" }
}

Step "ffmpeg + ffplay" {
  if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    winget install --id Gyan.FFmpeg -e --accept-source-agreements --accept-package-agreements
  } else { Write-Host "ffmpeg present" }
}

Step "renew PATH for this session" {
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("Path","User")
}

Step "Standards repo" {
  $repo = Join-Path $HOME "my-engineering-standards"
  if (-not (Test-Path $repo)) {
    git clone https://github.com/RexiAI/my-engineering-standards.git $repo
  } else { Push-Location $repo; git pull; Pop-Location }
  node (Join-Path $repo "scripts\media\install.mjs")
}

Step "Verify" {
  $repo = Join-Path $HOME "my-engineering-standards"
  node (Join-Path $repo "scripts\media\smoke-media.mjs")
  Write-Host "`nOpen opencode desktop, restart it if it was running. Agents: media-image, media-video, media-voice, media-producer." -ForegroundColor Green
  Write-Host "Then edit $HOME\.config\opencode\media\backends.json — the media agents refuse to run until it names real commands."
}
