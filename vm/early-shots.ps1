param(
  [Parameter(Mandatory = $true)][string]$Iso,
  [string]$Label = 'mine',
  [int[]]$Marks = @(12, 30, 60)
)
$ErrorActionPreference = 'Stop'
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

$port = 4477
$args = @(
  '-machine', 'q35',
  '-accel', 'tcg,thread=multi',
  '-cpu', 'max',
  '-m', '2048',
  '-smp', '2',
  '-cdrom', $Iso,
  '-boot', 'order=d',
  '-display', 'none',
  '-serial', 'none',
  '-qmp', "tcp:127.0.0.1:$port,server,nowait"
)
$p = Start-Process -FilePath 'C:\QEMU\qemu-system-x86_64.exe' -ArgumentList $args -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 2
$start = Get-Date
foreach ($m in $Marks) {
  while (((Get-Date) - $start).TotalSeconds -lt $m) { Start-Sleep -Milliseconds 500 }
  $name = "$Label-$m" + 's.ppm'
  $file = ('C:/AncorOS/out/' + $name) -replace '\\', '/'
  $null = Invoke-Qmp -Port $port -Command 'screendump' -Args ('{"filename":"' + $file + '"}')
  "captured $name"
}
$p | ForEach-Object { $_.Kill() }
Start-Sleep -Seconds 2
"done $Label"