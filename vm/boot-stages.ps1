param(
  [string]$Iso = 'C:\AncorISO\AncorOS-26.04-amd64.iso',
  [string]$ShotDir = 'C:\Project-AncorOS\screenshots',
  [int]$MemoryMB = 5120,
  [int]$Cpus = 6,
  [int]$QmpPort = 4499,
  [int[]]$Marks = @(20, 60, 120, 240, 420, 600)
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null

Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
Start-Sleep -Seconds 3

function Invoke-Qmp {
  param([int]$Port, [string]$Command, [string]$ArgumentsJson)
  $client = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $Port)
  $stream = $client.GetStream()
  $reader = New-Object System.IO.StreamReader($stream)
  $writer = New-Object System.IO.StreamWriter($stream)
  $writer.AutoFlush = $true
  $null = $reader.ReadLine()
  $writer.WriteLine('{"execute":"qmp_capabilities"}')
  $null = $reader.ReadLine()
  if ($ArgumentsJson) { $writer.WriteLine('{"execute":"' + $Command + '","arguments":' + $ArgumentsJson + '}') }
  else { $writer.WriteLine('{"execute":"' + $Command + '"}') }
  $resp = $reader.ReadLine()
  $client.Close()
  return $resp
}

$names = @('01-boot', '02-kernel', '03-initramfs', '04-live-session', '05-session-2', '06-final')
$serial = Join-Path $ShotDir 'boot-serial.log'
Remove-Item $serial -ErrorAction SilentlyContinue

$args = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', $MemoryMB,
  '-smp', $Cpus,
  '-drive', "file=$Iso,media=cdrom,readonly=on,if=ide",
  '-boot', 'order=d',
  '-device', 'virtio-rng-pci',
  '-display', 'none',
  '-serial', "file:$serial",
  '-qmp', "tcp:127.0.0.1:$QmpPort,server,nowait"
)
$proc = Start-Process -FilePath 'C:\QEMU\qemu-system-x86_64.exe' -ArgumentList $args -WindowStyle Hidden -PassThru
"qemu boot-test pid=$($proc.Id)"
$start = Get-Date
$index = 0
foreach ($mark in $Marks) {
  while (((Get-Date) - $start).TotalSeconds -lt $mark) { Start-Sleep -Seconds 5 }
  if ($proc.HasExited) { "qemu exited early"; break }
  $name = $names[$index]
  $ppm = Join-Path $ShotDir ($name + '.ppm')
  $file = ($ppm -replace '\\', '/')
  $null = Invoke-Qmp -Port $QmpPort -Command 'screendump' -ArgumentsJson ('{"filename":"' + $file + '"}')
  Start-Sleep -Seconds 2
  $proc.Refresh()
  $cpu = [math]::Round(100 * $proc.TotalProcessorTime.TotalSeconds / [math]::Max(1, ((Get-Date) - $start).TotalSeconds), 0)
  if (Test-Path $ppm) {
    $t1 = $proc.TotalProcessorTime.TotalSeconds
    Start-Sleep -Seconds 12
    $proc.Refresh()
    $busy = [math]::Round(100 * ($proc.TotalProcessorTime.TotalSeconds - $t1) / 12, 1)
    "t=${mark}s captured $name.ppm  cpu_now=${busy}% avg=${cpu}%"
    $index++
  } else {
    "t=${mark}s screendump returned no file"
  }
}
"--- serial tail ---"
if (Test-Path $serial) { Get-Content $serial -Tail 12 }
"BOOTSTAGES-DONE"