param(
  [string]$Iso = 'C:\AncorOS\out\AncorOS-26.04-amd64.iso',
  [int]$MemoryMB = 4096,
  [int]$Cpus = 4,
  [int]$QmpPort = 4466,
  [int]$WaitMinutes = 45,
  [int[]]$ShotMinutes = @(4, 8, 14, 22, 32, 44)
)
$ErrorActionPreference = 'Stop'
$qemu = 'C:\QEMU\qemu-system-x86_64.exe'
$outDir = 'C:\AncorOS\out'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$serial = Join-Path $outDir 'boot-serial.log'

Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -lt (Get-Date).AddMinutes(-2) } | ForEach-Object { $_.Kill() }
Start-Sleep -Seconds 2
Remove-Item $serial -ErrorAction SilentlyContinue

$args = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', $MemoryMB,
  '-smp', $Cpus,
  '-drive', "file=$Iso,media=cdrom,readonly=on,if=ide",
  '-device', 'virtio-rng-pci',
  '-display', 'none',
  '-serial', "file:$serial",
  '-qmp', "tcp:127.0.0.1:$QmpPort,server,nowait"
)
$proc = Start-Process -FilePath $qemu -ArgumentList $args -WindowStyle Hidden -PassThru
"qemu boot-test started pid=$($proc.Id)"

function Invoke-Qmp {
  param([string]$Command, [string]$ArgumentsJson)
  $client = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $QmpPort)
  $stream = $client.GetStream()
  $reader = New-Object System.IO.StreamReader($stream)
  $writer = New-Object System.IO.StreamWriter($stream)
  $writer.AutoFlush = $true
  $null = $reader.ReadLine()
  $writer.WriteLine('{"execute":"qmp_capabilities"}')
  $null = $reader.ReadLine()
  if ($ArgumentsJson) {
    $writer.WriteLine('{"execute":"' + $Command + '","arguments":' + $ArgumentsJson + '}')
  } else {
    $writer.WriteLine('{"execute":"' + $Command + '"}')
  }
  $resp = $reader.ReadLine()
  $client.Close()
  return $resp
}

$next = 0
$start = Get-Date
while (((Get-Date) - $start).TotalMinutes -lt $WaitMinutes) {
  Start-Sleep -Seconds 45
  $elapsed = [int]((Get-Date) - $start).TotalMinutes
  if ($next -lt $ShotMinutes.Count -and $elapsed -ge $ShotMinutes[$next]) {
    $name = 'boot-' + $ShotMinutes[$next] + 'm.ppm'
    $file = (Join-Path $outDir $name) -replace '\\', '/'
    $null = Invoke-Qmp 'screendump' ('{"filename":"' + $file + '"}')
    Start-Sleep -Seconds 2
    $ok = Test-Path (Join-Path $outDir $name)
    "t=$elapsed min : screendump $name -> $(if($ok){'ok'}else{'empty'})"
    $next++
  }
  if ($next -ge $ShotMinutes.Count) { break }
}
"--- serial tail ---"
if (Test-Path $serial) { Get-Content $serial -Tail 20 }
Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
"BOOTTEST-DONE"