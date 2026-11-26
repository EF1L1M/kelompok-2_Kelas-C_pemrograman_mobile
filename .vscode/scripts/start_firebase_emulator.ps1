$ErrorActionPreference = "Stop"

$workDir = (Get-Location).Path
$npmGlobal = Join-Path $env:APPDATA "npm"
if ((Test-Path $npmGlobal) -and ($env:PATH -notlike "*$npmGlobal*")) {
  $env:PATH = "$npmGlobal;$env:PATH"
}

# 1. Bersihkan sisa proses emulator lama agar port bebas
$ports = @(4400, 9099, 8080, 4000, 4500, 9150)
$stalePids = Get-NetTCPConnection -LocalPort $ports -State Listen -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  Where-Object { $_ -and $_ -ne 0 }

if ($stalePids) {
  Write-Host "Membersihkan proses Firebase Emulator sebelumnya..."
  Stop-Process -Id $stalePids -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 600
}

# 2. Siapkan argumen emulator (muat .emulator-data jika ada)
$exportDir = Join-Path $workDir ".emulator-data"
$cmdText = "firebase emulators:start --only auth,firestore --project demo-bagitigakan"
if (Test-Path (Join-Path $exportDir "firebase-export-metadata.json")) {
  $cmdText += " --import `"$exportDir`""
}

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  $cmdText = "npx --yes firebase-tools " + $cmdText.Substring("firebase ".Length)
}

# 3. Jalankan Firebase Emulator secara terpisah di background (window hidden)
$outLog = Join-Path $workDir "firebase-emulator-stdout.log"
$errLog = Join-Path $workDir "firebase-emulator-stderr.log"

Write-Host "Menyalakan Firebase Emulator (Auth :9099, Firestore :8080, UI :4000)..."
Start-Process -FilePath "cmd.exe" `
  -ArgumentList "/c $cmdText" `
  -WorkingDirectory $workDir `
  -WindowStyle Hidden `
  -RedirectStandardOutput $outLog `
  -RedirectStandardError $errLog | Out-Null

# 4. Tunggu hingga Hub (4400), Auth (9099), dan Firestore (8080) benar-benar siap
$deadline = (Get-Date).AddSeconds(40)
$ready = $false

while ((Get-Date) -lt $deadline) {
  Start-Sleep -Milliseconds 500
  try {
    $hub = Invoke-RestMethod -Uri "http://127.0.0.1:4400/emulators" -TimeoutSec 2 -ErrorAction Stop
    if ($null -ne $hub.auth -and $null -ne $hub.firestore) {
      $authListening = Get-NetTCPConnection -LocalPort 9099 -State Listen -ErrorAction SilentlyContinue
      $fsListening = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
      if ($authListening -and $fsListening) {
        $ready = $true
        break
      }
    }
  } catch {
    # Belum siap, lanjut polling
  }
}

if (-not $ready) {
  Write-Error "Firebase Emulator gagal siap dalam 40 detik. Cek firebase-emulator-stderr.log atau firebase-debug.log."
  exit 1
}

Write-Host "Firebase Emulator SIAP! UI: http://127.0.0.1:4000/"
exit 0
