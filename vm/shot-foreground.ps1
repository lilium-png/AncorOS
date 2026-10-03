param(
  [string]$Out = 'C:\Project-AncorOS\screenshots\site-download.png',
  [string]$Browser = 'chrome',
  [int]$Scrolls = 16,
  [int]$TopmostOffDelayMs = 1500
)
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
$cs = @"
using System;
using System.Runtime.InteropServices;
public class W3 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  public const uint SWP_NOMOVE = 0x0002;
  public const uint SWP_NOSIZE = 0x0001;
  public const uint SWP_SHOWWINDOW = 0x0040;
}
"@
Add-Type -TypeDefinition $cs

$p = Get-Process $Browser -ErrorAction SilentlyContinue |
     Where-Object { $_.MainWindowHandle -ne 0 } |
     Sort-Object StartTime -Descending | Select-Object -First 1
if (-not $p) { "no $Browser window"; exit 1 }
"window: pid=$($p.Id) hwnd=$($p.MainWindowHandle) title='$($p.MainWindowTitle)'"

$TOPMOST = [IntPtr](-1)
$NOTOPMOST = [IntPtr](-2)
[W3]::ShowWindow($p.MainWindowHandle, 3) | Out-Null
[W3]::SetWindowPos($p.MainWindowHandle, $TOPMOST, 0, 0, 0, 0, [W3]::SWP_NOMOVE -bor [W3]::SWP_NOSIZE -bor [W3]::SWP_SHOWWINDOW) | Out-Null
[W3]::BringWindowToTop($p.MainWindowHandle) | Out-Null
[W3]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Seconds 2
"foreground now: $([W3]::GetForegroundWindow()) target: $($p.MainWindowHandle)"

$ws = New-Object -ComObject WScript.Shell
for ($i = 0; $i -lt $Scrolls; $i++) {
  $ws.SendKeys('{PGDN}')
  Start-Sleep -Milliseconds 400
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
[W3]::SetWindowPos($p.MainWindowHandle, $NOTOPMOST, 0, 0, 0, 0, [W3]::SWP_NOMOVE -bor [W3]::SWP_NOSIZE) | Out-Null
"saved $Out  $([math]::Round((Get-Item $Out).Length/1KB)) KB"
Start-Process $Out