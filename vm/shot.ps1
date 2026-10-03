param(
  [int]$QmpPort = 4466,
  [string]$Name = 'live'
)
$client = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $QmpPort)
$stream = $client.GetStream()
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true
$null = $reader.ReadLine()
$writer.WriteLine('{"execute":"qmp_capabilities"}')
$null = $reader.ReadLine()
$file = ('C:/AncorOS/out/' + $Name + '.png')
$writer.WriteLine('{"execute":"screendump","arguments":{"filename":"' + $file + '"}}')
$resp = $reader.ReadLine()
$client.Close()
"qmp: $resp"
Start-Sleep -Seconds 2
$p = 'C:\AncorOS\out\' + $Name + '.png'
if (Test-Path $p) { "png: $p ($([math]::Round((Get-Item $p).Length/1KB)) KB)" } else { 'no png produced' }