param(
  [Parameter(Mandatory = $true)][string]$Local,
  [string]$Remote = "/home/builder"
)
$scp = 'C:\Windows\System32\OpenSSH\scp.exe'
$args = @(
  '-i', 'C:\AncorOS\vm\id_ed25519',
  '-P', '2222',
  '-r',
  '-o', 'StrictHostKeyChecking=no',
  '-o', 'UserKnownHostsFile=NUL',
  '-o', 'LogLevel=ERROR',
  $Local,
  "builder@127.0.0.1:$Remote"
)
& $scp @args
"scp exit: $LASTEXITCODE"