# bootstrap-windows.ps1 — one-shot Windows setup for the media agent family
# and opencode desktop. Run in PowerShell (no admin needed for user-scoped
# installs; winget may prompt once for package agreements).
#
#   powershell -ExecutionPolicy Bypass -File .\bootstrap-windows.ps1
#
# Idempotent: every step checks before installing.

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

Step "Bailian CLI (bl)" {
  npm list -g bailian-cli --depth=0 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) { npm install -g bailian-cli }
  bl --version
}

Step "Bailian skills" {
  bl skill init
}

Step "Bailian login" {
  $status = bl auth status 2>&1 | Out-String
  if ($status -notmatch "API key") {
    $key = Read-Host "Paste Bailian API key (Token-Plan sk-sp-... or standard sk-...)"
    bl auth login --api-key $key
    # Persist for opencode/voice-chat without putting it in any repo file:
    [System.Environment]::SetEnvironmentVariable("OPENCODE_API_KEY", $key, "User")
    if ($key -notmatch "^sk-sp-") {
      [System.Environment]::SetEnvironmentVariable("BAILIAN_API_KEY", $key, "User")
      [System.Environment]::SetEnvironmentVariable("DASHSCOPE_API_KEY", $key, "User")
    }
    Write-Host "Env vars set at user scope; restart your shell/opencode to pick them up."
  } else { Write-Host "already authenticated" }
}

Step "Standards repo" {
  $repo = Join-Path $HOME "my-engineering-standards"
  if (-not (Test-Path $repo)) {
    git clone https://github.com/RexiAI/my-engineering-standards.git $repo
  } else { Push-Location $repo; git pull; Pop-Location }
  node (Join-Path $repo "scripts\media\install.mjs")
}

Step "Verify" {
  node (Join-Path $repo "scripts\media\smoke-media.mjs")
  Write-Host "`nOpen opencode desktop, restart it if it was running. Agents: media-image, media-video, media-voice, media-producer." -ForegroundColor Green
  Write-Host "Realtime voice (voice-chat.mjs) additionally needs a STANDARD DashScope sk- key — Token-Plan sk-sp- keys are rejected by the WebSocket endpoint."
}
