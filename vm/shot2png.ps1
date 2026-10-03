param(
  [string]$ShotDir = 'C:\Project-AncorOS\screenshots',
  [string]$PpmName = '01-boot.ppm',
  [string]$PngName = '01-boot.png',
  [switch]$Open
)
$ppm = Join-Path $ShotDir $PpmName
$png = Join-Path $ShotDir $PngName
if (-not (Test-Path $ppm)) { "no such ppm: $ppm"; exit 1 }
& powershell -NoProfile -ExecutionPolicy Bypass -File 'C:\AncorOS\vm\ppm2png.ps1' -Ppm $ppm -Png $png
if (Test-Path $png) {
  "converted $PngName"
  if ($Open) { Start-Process $png }
}