# ============================================================================
#  ChatPulse · Production Pack (Windows PowerShell)
#  Result: chatpulse-site-deploy.tar.gz  →  upload to 宝塔 server
#  Contains: ONLY runtime files (no source / no node_modules / no docs src)
#  Size: ~13 MB vs full repo 500 MB+
# ============================================================================
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
Set-Location $Root

Write-Host ''
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host '  ChatPulse : Build + Minify + Package' -ForegroundColor Cyan
Write-Host '========================================================' -ForegroundColor Cyan
Write-Host ''

# 1) Pre-sync docs -> im-site/content/docs (mirrors repo ../docs/*.md)
Write-Host '[0/4] Syncing repo docs -> im-site/content/docs ...' -ForegroundColor Cyan
node -e @'
const { execSync } = require("node:child_process");
try {
  // Trigger sync by importing the DB util (the sync function runs on getDb)
  const { syncDocsDirToContent } = require("./server/utils/db");
  syncDocsDirToContent();
  console.log("   -> docs sync OK");
} catch (e) {
  console.log("   WARN: docs sync skipped (" + e.message + "). Continue packing anyway.");
}
'@
if ($LASTEXITCODE -ne 0) {
    Write-Host '   WARN: docs sync non-zero exit; continue.' -ForegroundColor Yellow
}

# 2) build
Write-Host ''
Write-Host '[1/4] Building ...' -ForegroundColor Cyan
npm run build
if ($LASTEXITCODE -ne 0) { throw 'npm run build failed' }

# 3) Stage
$Staging = Join-Path $Root '.deploy-staging'
$Package = Join-Path $Root 'chatpulse-site-deploy.tar.gz'
Write-Host ''
Write-Host '[2/4] Staging deploy files to .deploy-staging ...' -ForegroundColor Cyan
if (Test-Path $Staging) { Remove-Item -Recurse -Force $Staging }
foreach ($d in @($Staging, (Join-Path $Staging 'logs'), (Join-Path $Staging 'data'), (Join-Path $Staging 'content'), (Join-Path (Join-Path $Staging 'public') 'uploads'))) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

function Copy-SmartItem($from, $to) {
    if (-not (Test-Path -LiteralPath $from)) {
        Write-Host ('    SKIP (not exist):  ' + $from) -ForegroundColor DarkGray
        return
    }
    $isDir = Test-Path -LiteralPath $from -PathType Container
    if ($isDir) {
        New-Item -ItemType Directory -Force -Path $to | Out-Null
        Copy-Item -Recurse -Force -Path (Join-Path $from '*') -Destination $to
    } else {
        $toDir = Split-Path -Parent $to
        if (-not (Test-Path $toDir)) { New-Item -ItemType Directory -Force -Path $toDir | Out-Null }
        Copy-Item -Force $from -Destination $to
    }
    Write-Host ('    ADD : ' + $from) -ForegroundColor Green
}

Copy-SmartItem (Join-Path $Root '.output')            (Join-Path $Staging '.output')
Copy-SmartItem (Join-Path $Root 'public')              (Join-Path $Staging 'public')
$contentSrc = Join-Path $Root 'content' | Join-Path -ChildPath 'docs'
$contentDst = Join-Path $Staging 'content' | Join-Path -ChildPath 'docs'
Copy-SmartItem $contentSrc $contentDst
Copy-SmartItem (Join-Path $Root 'ecosystem.config.cjs') (Join-Path $Staging 'ecosystem.config.cjs')
Copy-SmartItem (Join-Path $Root '.env.example')        (Join-Path $Staging '.env.example')
$hasProdEnv = Test-Path (Join-Path $Root '.env.production')
if ($hasProdEnv) {
    Copy-SmartItem (Join-Path $Root '.env.production') (Join-Path $Staging '.env.production')
} else {
    Write-Host '    NOTE: .env.production not found. Copy from .env.example on server.' -ForegroundColor Yellow
}
Copy-SmartItem (Join-Path $Root '_repair-db.cjs')      (Join-Path $Staging '_repair-db.cjs')

# Optional: include local data/ folder (SQLite DB chatpulse.db + any runtime uploads that ended up there)
# so server doesn't need to run DB init scripts on FIRST deploy.
$DataSrc = Join-Path $Root 'data'
$DataDst = Join-Path $Staging 'data'
if (Test-Path -LiteralPath $DataSrc -PathType Container) {
    $DbPath = Join-Path $DataSrc 'chatpulse.db'
    if (Test-Path -LiteralPath $DbPath) {
        Copy-SmartItem $DataSrc $DataDst
        $rawLen = (Get-Item -LiteralPath $DbPath).Length
        if ($rawLen -ge 1MB) { $szStr = ('{0:N2} MB' -f ($rawLen / 1MB)) } else { $szStr = ('{0:N0} KB' -f ($rawLen / 1KB)) }
        Write-Host ('    -> Local chatpulse.db included (' + $szStr + '). Server needs NO DB init step on first run.') -ForegroundColor Green
    } else {
        Write-Host '    data/ exists but no chatpulse.db yet; keep empty folder (server creates it on first request).' -ForegroundColor Yellow
    }
} else {
    Write-Host '    data/ missing locally; keep empty folder for runtime.' -ForegroundColor Gray
}

Write-Host ''
Write-Host '  Included contents:' -ForegroundColor White
Write-Host '   - .output/               SSR build + API routes (20 MB)' -ForegroundColor White
Write-Host '   - public/                 favicon / robots / uploads' -ForegroundColor White
Write-Host '   - content/docs/          Markdown sources (/api-docs edit)' -ForegroundColor White
Write-Host '   - logs/ data/            empty folders (runtime)' -ForegroundColor White
Write-Host '   - ecosystem.config.cjs   PM2 entry' -ForegroundColor White
Write-Host '   - .env.example           Env template' -ForegroundColor White
Write-Host '   - .env.production        (if present, copied directly)' -ForegroundColor White
Write-Host '   - _repair-db.cjs         DB repair utility (run once on server)' -ForegroundColor White

# 4) Package with tar
Write-Host ''
Write-Host '[3/4] Creating chatpulse-site-deploy.tar.gz ...' -ForegroundColor Cyan
if (Test-Path $Package) { Remove-Item -Force $Package }
Push-Location $Staging
$FilesToPack = @('.output','public','content','ecosystem.config.cjs','.env.example','_repair-db.cjs','logs','data')
if ($hasProdEnv) { $FilesToPack += '.env.production' }
& tar.exe -czf $Package @FilesToPack
Pop-Location
if (-not (Test-Path $Package)) { throw 'tar failed: package file not created' }

# 5) Report
Write-Host ''
Write-Host '[4/4] Report' -ForegroundColor Cyan
function Format-Size([double]$s) {
    if ($s -ge 1GB) { return ('{0:N2} GB' -f ($s / 1GB)) }
    if ($s -ge 1MB) { return ('{0:N2} MB' -f ($s / 1MB)) }
    return ('{0:N1} KB' -f ($s / 1KB))
}
$zipSize = (Get-Item $Package).Length
try {
    $srcSize = (Get-ChildItem -Path $Root -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
} catch { $srcSize = 0 }

Write-Host ('  Package size   : ' + (Format-Size $zipSize)) -ForegroundColor Green
if ($srcSize -gt 0) {
    Write-Host ('  Repo size      : ' + (Format-Size $srcSize) + '  (including node_modules)') -ForegroundColor DarkGray
    $ratio = [int]($srcSize / [Math]::Max(1, $zipSize))
    Write-Host ('  Compression    :  x' + $ratio + ' smaller') -ForegroundColor Green
}
Write-Host ('  Package path   : ' + $Package) -ForegroundColor Green

Write-Host ''
Write-Host '--------------------------------------------------' -ForegroundColor Yellow
Write-Host '  NEXT STEPS ON BAOTA SERVER' -ForegroundColor Yellow
Write-Host '--------------------------------------------------' -ForegroundColor Yellow
Write-Host '  1. Upload chatpulse-site-deploy.tar.gz  ->  /www/wwwroot/chatpulse-site'
Write-Host '  2. Extract: cd /www/wwwroot/chatpulse-site && tar -xzf chatpulse-site-deploy.tar.gz'
Write-Host '  3. Env:     cp .env.example .env.production  &&  vim .env.production'
Write-Host '                 (set SITE_URL=https://yourdomain.com)'
Write-Host '  (Optional schema upgrade only) node _repair-db.cjs'
Write-Host '       -> NOT needed for first deploy: local chatpulse.db (with admin/admin123,'
Write-Host '          pricing, AI configs, articles) is already included in the package.'
Write-Host '       -> Run this ONLY after a future code upgrade that adds new tables/columns.'
Write-Host '  4. Install PROD deps with native addons compiled on Linux:'
Write-Host '        cd .output/server && npm install --omit=dev --no-audit --no-fund'
Write-Host '     ^  Windows .node files cannot run on Linux; must install on server'
Write-Host '  5. PM2:     cd ../..  &&  pm2 start ecosystem.config.cjs  &&  pm2 save'
Write-Host '  6. Baota panel: create site (static root=public) -> reverse proxy to'
Write-Host '     http://127.0.0.1:3000 ; apply SSL (LetsEncrypt); force HTTPS.'
Write-Host '--------------------------------------------------' -ForegroundColor Yellow
Write-Host ''
