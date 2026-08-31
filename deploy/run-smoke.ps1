# Start Infra + API + Run Recharge/Withdraw Smoke
# Usage (PowerShell 5+):
#   powershell -NoProfile -ExecutionPolicy Bypass -File D:\im-project\deploy\run-smoke.ps1
#
$ErrorActionPreference = 'Continue'
$deployDir = 'D:\im-project\deploy'
$svrDir    = 'D:\im-project\im-server'

function Wait-DockerReady($maxSeconds=180) {
  $t = [DateTime]::Now.AddSeconds($maxSeconds)
  while ([DateTime]::Now -lt $t) {
    $out = & docker info 2>&1
    if ($LASTEXITCODE -eq 0) { return $true }
    Start-Sleep 2
  }
  return $false
}

function Wait-Port($h, $port, $maxSeconds=120) {
  $t = [DateTime]::Now.AddSeconds($maxSeconds)
  while ([DateTime]::Now -lt $t) {
    $c = New-Object Net.Sockets.TcpClient
    try {
      $ar = $c.BeginConnect($h,$port,$null,$null)
      if ($ar.AsyncWaitHandle.WaitOne(400,$false) -and $c.Connected) { $c.Close(); return $true }
    } catch {}
    $c.Close()
    Start-Sleep 1
  }
  return $false
}

function Fatal($msg) { Write-Host ('FATAL: ' + $msg) -ForegroundColor Red; throw $msg }

# 1
Write-Host '[1/6] Wait Docker daemon ...' -ForegroundColor Cyan
if (-not (Wait-DockerReady 180)) { throw 'Docker daemon not ready in 180s' }
Write-Host 'Docker daemon UP' -ForegroundColor Green

# 2
Write-Host '[2/6] docker compose up infra' -ForegroundColor Cyan
Set-Location $deployDir
& docker compose up -d mysql redis mongodb minio 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { Fatal ('docker compose up exit=' + $LASTEXITCODE) }

# 3
Write-Host '[3/6] Wait 4 ports (127.0.0.1 3306/6379/27017/9000)' -ForegroundColor Cyan
foreach ($p in @(3306,6379,27017,9000)) {
  if (-not (Wait-Port '127.0.0.1' $p 240)) { Fatal ('port ' + $p + ' not open in 240s') }
  Write-Host ('port ' + $p + ' OPEN') -ForegroundColor Green
}
Start-Sleep 8

# 4
Write-Host '[4/6] go build api and start on :8080' -ForegroundColor Cyan
Set-Location $svrDir
Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
  Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Milliseconds 500
foreach ($f in @('api.exe','api_stdout.log','api_stderr.log','smoke.exe')) {
  if (Test-Path $f) { Remove-Item $f -Force -ErrorAction SilentlyContinue }
}
& go build -o api.exe ./cmd/api 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { Fatal 'go build api.exe FAILED' }
$proc = Start-Process -FilePath .\api.exe -WorkingDirectory $svrDir `
  -RedirectStandardOutput api_stdout.log -RedirectStandardError api_stderr.log -NoNewWindow -PassThru
Write-Host ('api PID=' + $proc.Id)
if (-not (Wait-Port '127.0.0.1' 8080 120)) {
  Write-Host '--- api_stdout.log ---'
  Get-Content api_stdout.log -Tail 50 -ErrorAction SilentlyContinue | Out-Host
  Write-Host '--- api_stderr.log ---'
  Get-Content api_stderr.log -Tail 30 -ErrorAction SilentlyContinue | Out-Host
  Fatal 'API :8080 not ready in 120s'
}
Write-Host 'API :8080 UP' -ForegroundColor Green
Start-Sleep 4

# 5
Write-Host '[5/6] build & run smoke.exe' -ForegroundColor Cyan
& go build -o smoke.exe ./cmd/smoke-recharge-withdraw 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) { Fatal 'go build smoke.exe FAILED' }
& .\smoke.exe 2>&1 | ForEach-Object { Write-Host $_ }
$smokeExit = $LASTEXITCODE

# 6
Write-Host '[6/6] stop api.exe'
Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

if ($smokeExit -eq 0) {
  Write-Host 'SMOKE PASSED' -ForegroundColor Green
  exit 0
} else {
  Write-Host ('SMOKE FAILED exit=' + $smokeExit) -ForegroundColor Red
  exit $smokeExit
}
