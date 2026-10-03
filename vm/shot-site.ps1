param(
  [string]$Url = 'http://127.0.0.1:8080/',
  [string]$Out = 'C:\Project-AncorOS\screenshots\site-download.png',
  [string]$Browser = 'C:\Program Files\Google\Chrome\Application\chrome.exe',
  [int]$Scrolls = 14
)
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$cs = @"
using System;
using System.Runtime.InteropServices;
public class W2 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
}
"@
Add-Type -TypeDefinition $cs

if (-not (Test-Path $Browser)) { "browser not found: $Browser"; exit 1 }

$before = @(Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -ExpandProperty Id)
Start-Process $Browser -ArgumentList '--new-window',$Url | Out-Null
Start-Sleep -Seconds 9

$p = Get-Process chrome -ErrorAction SilentlyContinue |
     Where-Object { $_.MainWindowHandle -ne 0 -and ($before -notcontains $_.Id) } |
     Select-Object -First 1
if (-not $p) { $p = Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1 }
if (-not $p) { 'no chrome window found'; exit 1 }

[W2]::ShowWindow($p.MainWindowHandle, 3) | Out-Null
[W2]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Seconds 3

$ws = New-Object -ComObject WScript.Shell
for ($i = 0; $i -lt $Scrolls; $i++) {
  $ws.SendKeys('{PGDN}')
  Start-Sleep -Milliseconds 450
}
Start-Sleep -Seconds 3

$vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object System.Drawing.Bitmap($vs.Width, $vs.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vs.Left, $vs.Top, 0, 0, $bmp.Size)
$g.Dispose()
New-Item -ItemType Directory -Force -Path (Split-Path $Out -Parent) | Out-Null
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"saved $Out  $([math]::Round((Get-Item $Out).Length/1KB)) KB"
Start-Process $Out