$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
Set-Location $Root

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  ChatPulse : Staging -> chatpulse-site-deploy.zip"       -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

$ServerEntry = Join-Path $Root ".output/server/index.mjs"
if (-not (Test-Path -LiteralPath $ServerEntry)) {
    throw ".output/server/index.mjs missing. Run 'npm run build' first."
}

$Staging = Join-Path $Root ".deploy-staging"
$ZipPath = Join-Path $Root "chatpulse-site-deploy.zip"
if (Test-Path -LiteralPath $Staging) { Remove-Item -Recurse -Force $Staging }
if (Test-Path -LiteralPath $ZipPath) { Remove-Item -Force $ZipPath }

$dirs = @(
    (Join-Path $Staging "logs"),
    (Join-Path $Staging "data"),
    (Join-Path $Staging "content"),
    (Join-Path (Join-Path $Staging "public") "uploads")
)
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

function Copy-SmartItem($from, $to) {
    if (-not (Test-Path -LiteralPath $from)) {
        Write-Host ("    SKIP : " + $from) -ForegroundColor DarkGray
        return
    }
    $isDir = Test-Path -LiteralPath $from -PathType Container
    if ($isDir) {
        New-Item -ItemType Directory -Force -Path $to | Out-Null
        Copy-Item -Recurse -Force -Path (Join-Path $from "*") -Destination $to
    } else {
        $toDir = Split-Path -Parent $to
        if (-not (Test-Path $toDir)) { New-Item -ItemType Directory -Force -Path $toDir | Out-Null }
        Copy-Item -Force $from -Destination $to
    }
    Write-Host ("    ADD  : " + $from) -ForegroundColor Green
}

Write-Host ""
Write-Host "[1/2] Copying runtime files to .deploy-staging ..." -ForegroundColor Cyan

Copy-SmartItem (Join-Path $Root ".output")             (Join-Path $Staging ".output")
Copy-SmartItem (Join-Path $Root "public")               (Join-Path $Staging "public")
Copy-SmartItem (Join-Path $Root "content/docs")         (Join-Path $Staging "content/docs")
Copy-SmartItem (Join-Path $Root "ecosystem.config.cjs") (Join-Path $Staging "ecosystem.config.cjs")
Copy-SmartItem (Join-Path $Root ".env.example")         (Join-Path $Staging ".env.example")
Copy-SmartItem (Join-Path $Root "_repair-db.cjs")       (Join-Path $Staging "_repair-db.cjs")

$prodEnv = Join-Path $Root ".env.production"
if (Test-Path -LiteralPath $prodEnv) {
    Copy-SmartItem $prodEnv (Join-Path $Staging ".env.production")
} else {
    Write-Host "    NOTE : .env.production not found (server keeps existing one)." -ForegroundColor Yellow
}

$localDb = Join-Path (Join-Path $Root "data") "chatpulse.db"
if (Test-Path -LiteralPath $localDb) {
    $rawLen = (Get-Item -LiteralPath $localDb).Length
    if ($rawLen -ge 1MB) { $szStr = ("{0:N2} MB" -f ($rawLen / 1MB)) } else { $szStr = ("{0:N0} KB" -f ($rawLen / 1KB)) }
    Write-Host ""
    Write-Host ("    WARN : Local chatpulse.db exists (" + $szStr + "). It is intentionally NOT packed" ) -ForegroundColor Yellow
    Write-Host "           so you won't accidentally overwrite the production DB (which already has" -ForegroundColor Yellow
    Write-Host "           the 17 screenshots manually added via admin)."                         -ForegroundColor Yellow
} else {
    Write-Host "    NOTE : Local chatpulse.db not present; keep empty 'data' folder for runtime." -ForegroundColor Gray
}

Write-Host ""
Write-Host "[2/2] Creating chatpulse-site-deploy.zip ..." -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $Staging "*") -DestinationPath $ZipPath -CompressionLevel Optimal
$zipFile = Get-Item -LiteralPath $ZipPath
$zipMb = "{0:N2} MB" -f ($zipFile.Length / 1MB)

Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host ("  DONE:  " + $ZipPath + "  (" + $zipMb + ")")                -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
Write-Host "FILES INSIDE THE ZIP"                                                  -ForegroundColor White
Write-Host "   .output/               SSR + API + new _nuxt chunks. OVERWRITE on server." -ForegroundColor White
Write-Host "   public/                favicon.svg / robots.txt / screenshots. OVERWRITE." -ForegroundColor White
Write-Host "     public/uploads/      SKIP. Server already has 1.jpg..17.jpg uploaded."  -ForegroundColor Yellow
Write-Host "   content/docs/          /api-docs editable MD sources. OVERWRITE."         -ForegroundColor White
Write-Host "   ecosystem.config.cjs   PM2 entry. OVERWRITE if you changed it locally."   -ForegroundColor White
Write-Host "   .env.example           Template. NEVER overwrite server .env.production." -ForegroundColor Yellow
Write-Host "   _repair-db.cjs         DB repair tool. OVERWRITE."                        -ForegroundColor White
Write-Host "   logs/  data/           Empty folders. MERGE (keep server runtime data)."  -ForegroundColor Yellow
Write-Host ""
Write-Host "UPLOAD TO BAOTA (www.im.x123.wang site dir = /www/wwwroot/im-project/im-site):"
Write-Host "   1) Upload chatpulse-site-deploy.zip to /www/wwwroot/im-project/im-site"
Write-Host "   2) Right-click -> Online Extract. Conflicts dialog:"
Write-Host "        Overwrite -> .output/*, public/* but NOT public/uploads/*, content/docs/*, ecosystem.config.cjs, _repair-db.cjs, .env.example"
Write-Host "        Skip      -> public/uploads/* (preserve 1.jpg..17.jpg), data/* (keep SQLite + 17 records), .env.production"
Write-Host "   3) Permissions:"
Write-Host "        chown -R www:www .output public data public/uploads 2>/dev/null"
Write-Host "        chmod -R 755 .output public/uploads data"
Write-Host "   4) Hot reload: pm2 reload chatpulse-site"
Write-Host ""
Write-Host "Verify with hard-refresh (Ctrl+Shift+R). Home CoverFlow = 3 cards (middle 1.12 zoom + blue ring), /uploads/1.jpg -> 200." -ForegroundColor Green
