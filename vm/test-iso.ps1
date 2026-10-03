param(
  [string]$Iso = 'C:\AncorOS\out\AncorOS-26.04-amd64.iso',
  [int]$MemoryMB = 4096,
  [int]$Cpus = 4,
  [int]$QmpPort = 4455,
  [int]$SshPort = 2230,
  [int]$WaitMinutes = 60
)
$ErrorActionPreference = 'Stop'
$qemu = 'C:\QEMU\qemu-system-x86_64.exe'
$outDir = 'C:\AncorOS\out'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$serial = Join-Path $outDir 'test-serial.log'

Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
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
  '-netdev', "user,id=n0,hostfwd=tcp:127.0.0.1:$SshPort-:22",
  '-device', 'virtio-net-pci,netdev=n0',
  '-display', 'none',
  '-serial', "file:$serial",
  '-qmp', "tcp:127.0.0.1:$QmpPort,server,nowait"
)
$proc = Start-Process -FilePath $qemu -ArgumentList $args -WindowStyle Hidden -PassThru
"qemu started pid=$($proc.Id) iso=$Iso"

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

function Save-Shot {
  param([string]$Name)
  $file = (Join-Path $outDir $Name) -replace '\\', '/'
  $resp = Invoke-Qmp 'screendump' ('{"filename":"' + $file + '"}')
  Start-Sleep -Seconds 2
  $path = Join-Path $outDir $Name
  if (Test-Path $path) {
    "shot $Name -> $([math]::Round((Get-Item $path).Length/1KB)) KB ; qmp=$resp"
  } else {
    "shot $Name FAILED ; qmp=$resp"
  }
}

$deadline = (Get-Date).AddMinutes($WaitMinutes)
$shots = @(3, 6, 10, 15, 22, 30, 40, 55)
$next = 0
while ((Get-Date) -lt $deadline) {
  Start-Sleep -Seconds 60
  $elapsed = [int]((Get-Date) - $proc.StartTime).TotalMinutes
  $tail = ''
  if (Test-Path $serial) {
    $tail = (Get-Content $serial -Tail 1 -ErrorAction SilentlyContinue)
  }
  if ($next -lt $shots.Count -and $elapsed -ge $shots[$next]) {
    Save-Shot ('shot-' + $shots[$next] + 'min.ppm')
    $next++
  }
  if ($elapsed -ge $shots[$shots.Count - 1]) { break }
}
"--- serial tail ---"
if (Test-Path $serial) { Get-Content $serial -Tail 25 }
"--- shots ---"
Get-ChildItem $outDir -Filter '*.ppm' | Select-Object Name, @{n='KB'; e={ [math]::Round($_.Length/1KB) } } | Format-Table -AutoSize
"TEST-BOOT-DONE"