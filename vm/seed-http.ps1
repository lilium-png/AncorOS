param(
  [string]$Root = 'C:\AncorOS\vm\cidata',
  [int]$Port = 8000
)
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
while ($true) {
  $client = $listener.AcceptTcpClient()
  $stream = $client.GetStream()
  $reader = New-Object System.IO.StreamReader($stream)
  $requestLine = $reader.ReadLine()
  while (($line = $reader.ReadLine()) -ne '') { }
  $parts = $requestLine -split ' '
  $path = $parts[1]
  if ($path -like '/*') { $path = $path }
  $file = Join-Path $Root ($path.TrimStart('/'))
  if (Test-Path -LiteralPath $file -PathType Leaf) {
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $header = "HTTP/1.1 200 OK`r`nContent-Type: text/plain`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($hb, 0, $hb.Length)
    $stream.Write($bytes, 0, $bytes.Length)
  } else {
    $body = [System.Text.Encoding]::UTF8.GetBytes("not found: $path")
    $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n"
    $hb = [System.Text.Encoding]::ASCII.GetBytes($header)
    $stream.Write($hb, 0, $hb.Length)
    $stream.Write($body, 0, $body.Length)
  }
  $stream.Flush()
  $client.Close()
}