param(
  [Parameter(Mandatory = $true)][string]$Iso,
  [string]$Label = 'iso',
  [int]$WaitSec = 100,
  [int]$SampleSec = 15
)
$ErrorActionPreference = 'Stop'
Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
Start-Sleep -Seconds 3

$serial = "C:\AncorOS\out\probe-$Label-serial.log"
Remove-Item $serial -ErrorAction SilentlyContinue

$args = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', '2048',
  '-smp', '2',
  '-cdrom', $Iso,
  '-boot', 'order=d',
  '-display', 'none',
  '-serial', "file:$serial"
)
$p = Start-Process -FilePath 'C:\QEMU\qemu-system-x86_64.exe' -ArgumentList $args -WindowStyle Hidden -PassThru
Start-Sleep -Seconds $WaitSec
$p.Refresh()
$t1 = $p.TotalProcessorTime.TotalSeconds
Start-Sleep -Seconds $SampleSec
$p.Refresh()
$t2 = $p.TotalProcessorTime.TotalSeconds
$pct = [math]::Round(100 * ($t2 - $t1) / $SampleSec, 1)
$state = if ($pct -gt 40) { 'BUSY (booting)' } else { 'IDLE (stalled)' }
"$Label : cpu=$pct% -> $state"
$p | ForEach-Object { $_.Kill() }
Start-Sleep -Seconds 2