# Build Cockpit Flutter web + stamp a fresh cleanup service worker + publish
# to app.octopilothub.com.
#
# From repo (Windows):
#   cd H:\Cockpit\apps\cockpit
#   .\deploy\Deploy-Web.ps1              # build + stamp + scp upload
#   .\deploy\Deploy-Web.ps1 -SkipUpload  # build + stamp only
#   .\deploy\Deploy-Web.ps1 -SkipBuild   # re-stamp + upload existing build/web
#
# One-time on server after first upload:
#   sudo cp /opt/cockpit/apps/cockpit/deploy/nginx-app.conf /etc/nginx/sites-available/cockpit-app
#   sudo ln -sf /etc/nginx/sites-available/cockpit-app /etc/nginx/sites-enabled/cockpit-app
#   sudo nginx -t && sudo systemctl reload nginx
#   sudo certbot --nginx -d app.octopilothub.com
#   # DNS: app.octopilothub.com A 187.124.92.119

param(
    [string]$Flutter = "C:\Users\USER\sdk\flutter\bin\flutter.bat",
    [string]$SshTarget = "root@187.124.92.119",
    [string]$RemoteDir = "/var/www/cockpit",
    [string]$BuildId = (Get-Date -Format "yyyyMMddHHmmss"),
    [switch]$SkipBuild,
    [switch]$SkipUpload,
    # Re-copying nginx-app.conf would wipe Certbot's SSL listen/certs — skip by default.
    [switch]$InstallNginx
)

$ErrorActionPreference = "Stop"

$AppRoot = Split-Path $PSScriptRoot -Parent
$WebDir = Join-Path $AppRoot "build\web"

$DartDefines = @(
    "--dart-define=STUDY_API_BASE_URL=https://api.octopilothub.com",
    "--dart-define=FIREBASE_API_KEY=AIzaSyBcq3ylnbryHAENyn4KkqjuouIl4EBvOkc",
    "--dart-define=FIREBASE_APP_ID=1:712429690306:web:fcc508befb950e84b8ca5b",
    "--dart-define=FIREBASE_PROJECT_ID=octopilot-ai-7b29e",
    "--dart-define=FIREBASE_MESSAGING_SENDER_ID=712429690306",
    "--dart-define=FIREBASE_AUTH_DOMAIN=octopilot-ai-7b29e.firebaseapp.com",
    "--dart-define=FIREBASE_STORAGE_BUCKET=octopilot-ai-7b29e.firebasestorage.app"
)

Push-Location $AppRoot
try {
    if (-not $SkipBuild) {
        if (-not (Test-Path $Flutter)) {
            throw "Flutter not found at $Flutter - pass -Flutter path\to\flutter.bat"
        }
        Write-Host ">> flutter build web --release (build-number=$BuildId)"
        & $Flutter build web --release --build-number=$BuildId @DartDefines
        if ($LASTEXITCODE -ne 0) { throw "flutter build web failed ($LASTEXITCODE)" }
    }
    elseif (-not (Test-Path $WebDir)) {
        throw "No build/web and -SkipBuild set. Run a full build first."
    }

    Write-Host ">> Stamping cleanup SW + cache-bust ($BuildId)"
    & (Join-Path $PSScriptRoot "Stamp-Build.ps1") -BuildId $BuildId -WebDir $WebDir

    if (-not $SkipUpload) {
        # OpenSSH password prompts hang non-interactively; use paramiko SFTP.
        $PublishArgs = @((Join-Path $PSScriptRoot "publish_web.py"), "--web-dir", $WebDir)
        if (-not $InstallNginx) { $PublishArgs += "--skip-nginx" }
        Write-Host ">> Publishing via publish_web.py"
        & py -3 @PublishArgs
        if ($LASTEXITCODE -ne 0) { throw "publish_web.py failed ($LASTEXITCODE)" }
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host ">> Done. Open https://app.octopilothub.com (hard reload once after first deploy)."
Write-Host "   Each deploy ships a new flutter_service_worker.js (build_id=$BuildId) that"
Write-Host "   clears Cache Storage, unregisters, and reloads open tabs - no stale SW cache."
