param(
  [Parameter(Mandatory = $true)][string]$Cmd,
  [int]$TimeoutSec = 3600
)
$ssh = 'C:\Windows\System32\OpenSSH\ssh.exe'
$key = 'C:\AncorOS\vm\id_ed25519'
$args = @(
  '-i', $key,
  '-p', '2222',
  '-o', 'StrictHostKeyChecking=no',
  '-o', 'UserKnownHostsFile=NUL',
  '-o', 'LogLevel=ERROR',
  '-o', 'ServerAliveInterval=30',
  'builder@127.0.0.1',
  $Cmd
)
$out = Join-Path $env:TEMP ("ancoros_ssh_" + [Guid]::NewGuid().ToString('N') + ".log")
$err = $out + '.err'
$p = Start-Process -FilePath $ssh -ArgumentList $args -RedirectStandardOutput $out -RedirectStandardError $err -NoNewWindow -PassThru
if (-not $p.WaitForExit($TimeoutSec * 1000)) {
  $p.Kill()
  Write-Output "TIMEOUT after $TimeoutSec s"
  Get-Content $out -ErrorAction SilentlyContinue
  Get-Content $err -ErrorAction SilentlyContinue
  exit 124
}
Get-Content $out -ErrorAction SilentlyContinue
$e = Get-Content $err -ErrorAction SilentlyContinue
if ($e) { Write-Output "--- stderr ---"; $e }
Write-Output "--- exit: $($p.ExitCode) ---"
Remove-Item $out, $err -ErrorAction SilentlyContinue