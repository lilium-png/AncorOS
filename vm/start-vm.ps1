param(
  [int]$MemoryMB = 6144,
  [int]$Cpus = 6
)
$ErrorActionPreference = 'Stop'
$root = 'C:\AncorOS'
$qemu = 'C:\QEMU\qemu-system-x86_64.exe'
$disk = Join-Path $root 'vm\builder.qcow2'
$serial = Join-Path $root 'vm\serial.log'

Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
Start-Sleep -Seconds 2
Remove-Item $serial -ErrorAction SilentlyContinue

$args = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', $MemoryMB,
  '-smp', $Cpus,
  '-drive', "file=$disk,if=virtio,format=qcow2,cache=writeback",
  '-drive', "file=$root\downloads\ubuntu-26.04.1-desktop-amd64.iso,media=cdrom,readonly=on,if=ide",
  '-smbios', 'type=1,serial=ds=nocloud-net;s=http://10.0.2.2:8000/',
  '-device', 'virtio-rng-pci',
  '-netdev', 'user,id=n0,hostfwd=tcp:127.0.0.1:2222-:22',
  '-device', 'virtio-net-pci,netdev=n0',
  '-display', 'none',
  '-serial', "file:$serial",
  '-monitor', 'tcp:127.0.0.1:4444,server,nowait'
)

Start-Process -FilePath $qemu -ArgumentList $args -WindowStyle Hidden | Out-Null
Start-Sleep -Seconds 5
$proc = Get-Process qemu-system-x86_64 -ErrorAction SilentlyContinue
if ($proc) { "qemu pid=$($proc.Id) running" } else { "qemu failed to start" }