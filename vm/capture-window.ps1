param(
  [string]$Out = 'C:\Project-AncorOS\screenshots\06-installer.png',
  [string]$ProcName = 'qemu-system-x86_64'
)
Add-Type -AssemblyName System.Drawing
$cs = @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;
public class WCap {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
  public static Bitmap Capture(IntPtr h) {
    RECT r;
    GetWindowRect(h, out r);
    int w = r.Right - r.Left, ht = r.Bottom - r.Top;
    if (w <= 0 || ht <= 0) return null;
    Bitmap bmp = new Bitmap(w, ht, System.Drawing.Imaging.PixelFormat.Format24bppRgb);
    using (Graphics g = Graphics.FromImage(bmp)) {
      IntPtr hdc = g.GetHdc();
      PrintWindow(h, hdc, 2);
      g.ReleaseHdc(hdc);
    }
    return bmp;
  }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies "System.Drawing"
$p = Get-Process $ProcName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $p) { "process $ProcName not found"; exit 1 }
[WCap]::ShowWindow($p.MainWindowHandle, 3) | Out-Null
[WCap]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
Start-Sleep -Seconds 2
$bmp = [WCap]::Capture($p.MainWindowHandle)
if (-not $bmp) { 'capture failed'; exit 1 }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
"captured $Out  $($bmp.Width)x$($bmp.Height)  $([math]::Round((Get-Item $Out).Length/1KB)) KB"
$bmp.Dispose()
Start-Process $Out