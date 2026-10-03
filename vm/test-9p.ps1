$err = "$env:TEMP\qemu9p.txt"
Remove-Item $err -ErrorAction SilentlyContinue
$args = @(
  '-machine', 'q35',
  '-accel', 'tcg',
  '-m', '512',
  '-virtfs', 'local,path=C:\AncorOS\out,security_model=none,mount_tag=hostout',
  '-device', 'virtio-9p-pci,mount_tag=hostout',
  '-display', 'none',
  '-serial', 'none',
  '-monitor', 'none'
)
$p = Start-Process -FilePath 'C:\QEMU\qemu-system-x86_64.exe' -ArgumentList $args -RedirectStandardError $err -PassThru -WindowStyle Hidden
Start-Sleep -Seconds 6
if ($p.HasExited) { "qemu exited: $($p.ExitCode)" } else { "qemu alive -> 9p accepted"; $p.Kill() }
if (Test-Path $err) { "stderr: " + ((Get-Content $err) -join ' | ') }