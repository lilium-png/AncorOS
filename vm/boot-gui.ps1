param(
  [string]$Iso = 'C:\AncorOS\out\AncorOS-26.04-amd64.iso',
  [int]$MemoryMB = 5120,
  [int]$Cpus = 6,
  [int]$QmpPort = 4488,
  [switch]$Sdl
)
$ErrorActionPreference = 'Stop'
$qemu = 'C:\QEMU\qemu-system-x86_64.exe'
$outDir = 'C:\AncorOS\out'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$serial = Join-Path $outDir 'gui-serial.log'
Remove-Item $serial -ErrorAction SilentlyContinue

$display = if ($Sdl) { 'sdl' } else { 'gtk' }

$args = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', $MemoryMB,
  '-smp', $Cpus,
  '-drive', "file=$Iso,media=cdrom,readonly=on,if=ide",
  '-boot', 'order=d',
  '-device', 'virtio-rng-pci',
  '-display', $display,
  '-serial', "file:$serial",
  '-qmp', "tcp:127.0.0.1:$QmpPort,server,nowait"
)

"launching: qemu-system-x86_64.exe $($args -join ' ')"
$proc = Start-Process -FilePath $qemu -ArgumentList $args -PassThru
"qemu window pid=$($proc.Id) display=$display"
"QMP port $QmpPort for screenshots"
"close the window to stop the test"