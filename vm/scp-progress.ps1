param(
  [string]$Target = 'C:\AncorISO\AncorOS-26.04-amd64.iso',
  [long]$Total = 7229509632,
  [string]$Log = 'C:\Project-AncorOS\progress.log',
  [int]$IntervalSec = 30
)
$ErrorActionPreference = 'SilentlyContinue'

function Stamp { (Get-Date).ToString('HH:mm:ss') }

function Log-Line {
  param([string]$Tag, [string]$Text)
  $line = "[$(Stamp)] [$Tag] $Text"
  Add-Content -Path $Log -Value $line -Encoding UTF8
  Write-Output $line
}

Log-Line 'SCP' "старт мониторинга, цель $Total байт, интервал ${IntervalSec}s" | Out-Null

$lastSize = 0
$lastTime = Get-Date
while ($true) {
  Start-Sleep -Seconds $IntervalSec
  if (-not (Test-Path $Target)) { continue }
  $size = (Get-Item $Target).Length
  $now = Get-Date
  $dt = ($now - $lastTime).TotalSeconds
  if ($dt -le 0) { continue }
  $rate = ($size - $lastSize) / $dt
  $lastSize = $size
  $lastTime = $now

  $pct = [math]::Round(100 * $size / $Total, 1)
  $mbDone = [math]::Round($size / 1MB, 0)
  $mbTotal = [math]::Round($Total / 1MB, 0)
  $mbLeft = [math]::Round(($Total - $size) / 1MB, 0)
  $speed = [math]::Round($rate / 1MB, 1)
  $eta = if ($rate -gt 1024) { [math]::Round(($Total - $size) / $rate / 60, 1) } else { 0 }

  if ($size -ge $Total) {
    Log-Line 'SCP' "100.0% — $mbDone / $mbTotal МБ — передача завершена" | Out-Null
    Log-Line 'SCP' "средняя скорость за интервал $speed МБ/с" | Out-Null
    break
  }

  $etaTxt = if ($eta -gt 0) { "осталось ~$eta мин" } else { 'осталось неизвестно' }
  Log-Line 'SCP' "$mbDone / $mbTotal МБ ($pct%) — $speed МБ/с — $etaTxt — осталось $mbLeft МБ" | Out-Null
}

Log-Line 'SCP' 'мониторинг остановлен' | Out-Null
'MONITOR-DONE'