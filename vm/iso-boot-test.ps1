param(
  [string]$Iso = 'C:\AncorISO\AncorOS-26.04-amd64.iso',
  [string]$ShotDir = 'C:\Project-AncorOS\screenshots',
  [int]$MemoryMB = 5120,
  [int]$Cpus = 6,
  [int]$QmpPort = 4499,
  [int[]]$Marks = @(10, 22, 40, 70, 150, 300, 480, 720),
  [string]$Tag = '',
  [switch]$NoGui,
  [switch]$KillExisting
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $ShotDir | Out-Null

if (-not (Test-Path $Iso)) { "ISO not found: $Iso"; exit 1 }

function Invoke-Qmp {
  param([int]$Port, [string]$Command, [string]$ArgumentsJson)
  $client = New-Object System.Net.Sockets.TcpClient
  $client.Connect('127.0.0.1', $Port)
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

function Convert-PpmToPng {
  param([string]$PpmPath, [string]$PngPath)
  $cs = Get-Content 'C:\AncorOS\vm\ppm-reader.cs.txt' -Raw
  if (-not ('PpmReader' -as [type])) { Add-Type -TypeDefinition $cs -ReferencedAssemblies 'System.Drawing' }
  $r = New-Object PpmReader
  $r.Load($PpmPath)
  $r.SavePng($PngPath)
  return "$($r.Width)x$($r.Height)"
}

if ($KillExisting) {
  Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
  Start-Sleep -Seconds 4
}

$names = @(
  '01-grub-menu',
  '02-grub-theme',
  '03-loading',
  '04-kernel-init',
  '05-live-session',
  '06-desktop',
  '07-desktop-detail',
  '08-final'
)

$serial = Join-Path $ShotDir 'boot-serial.log'
Remove-Item $serial -ErrorAction SilentlyContinue

$qemuArgs = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', $MemoryMB,
  '-smp', $Cpus,
  '-drive', "file=$Iso,media=cdrom,readonly=on,if=ide",
  '-boot', 'order=d',
  '-device', 'virtio-rng-pci',
  '-serial', "file:$serial",
  '-qmp', "tcp:127.0.0.1:$QmpPort,server,nowait"
)
if ($NoGui) { $qemuArgs += '-display'; $qemuArgs += 'none' }
else { $qemuArgs += '-display'; $qemuArgs += 'gtk' }

$proc = Start-Process -FilePath 'C:\QEMU\qemu-system-x86_64.exe' -ArgumentList $qemuArgs -PassThru
"qemu pid=$($proc.Id) gui=$(-not $NoGui) iso=$Iso"
$start = Get-Date
$index = 0
foreach ($mark in $Marks) {
  while (((Get-Date) - $start).TotalSeconds -lt $mark) { Start-Sleep -Seconds 3 }
  $proc.Refresh()
  if ($proc.HasExited) { "qemu exited early at t=${mark}s"; break }
  if ($index -ge $names.Count) { break }
  $name = $names[$index]
  $ppm = Join-Path $ShotDir ($name + '.ppm')
  $png = Join-Path $ShotDir ($name + '.png')
  Remove-Item $ppm,$png -ErrorAction SilentlyContinue
  $file = ($ppm -replace '\\', '/')
  $resp = Invoke-Qmp -Port $QmpPort -Command 'screendump' -ArgumentsJson ('{"filename":"' + $file + '"}')
  Start-Sleep -Seconds 3
  if (Test-Path $ppm) {
    $size = Convert-PpmToPng -PpmPath $ppm -PngPath $png
    $kb = [math]::Round((Get-Item $png).Length / 1KB)
    "t=${mark}s -> $name.png ($size, $kb KB)"
    if (-not $NoGui) { Start-Process $png }
    $index++
  } else {
    "t=${mark}s screendump produced nothing: $resp"
  }
}
"--- qemu still running: $(-not $proc.HasExited) ---"
if (Test-Path $serial) { "--- serial tail ---"; Get-Content $serial -Tail 15 }
"BOOTSTAGES-DONE"