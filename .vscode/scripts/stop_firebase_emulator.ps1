$ErrorActionPreference = "SilentlyContinue"

# 1. Simpan snapshot data Auth & Firestore ke .emulator-data sebelum mematikan emulator
$exportDir = Join-Path (Get-Location) ".emulator-data"
try {
  $body = @{ path = $exportDir } | ConvertTo-Json -Compress
  Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:4400/_admin/export" `
    -Body $body `
    -ContentType "application/json" `
    -TimeoutSec 3 | Out-Null
  Write-Host "Data Firebase Emulator tersimpan ke .emulator-data."
} catch {
  # Abaikan jika emulator sudah mati atau belum sempat siap
}

# 2. Matikan seluruh proses emulator (Node.js Auth/UI & Java Firestore) berdasarkan port
$ports = @(4400, 9099, 8080, 4000, 4500, 9150)
$pids = Get-NetTCPConnection -LocalPort $ports -State Listen -ErrorAction SilentlyContinue |
  Select-Object -ExpandProperty OwningProcess -Unique |
  Where-Object { $_ -and $_ -ne 0 }

if ($pids) {
  Stop-Process -Id $pids -Force -ErrorAction SilentlyContinue
  Write-Host "Firebase Emulator berhasil dimatikan (PID: $($pids -join ', '))."
} else {
  Write-Host "Firebase Emulator sudah tidak berjalan."
}
