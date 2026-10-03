param(
  [string]$SrcDir = 'C:\AncorOS\assets\src',
  [string]$OutDir = 'C:\AncorOS\assets\repo'
)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$code = @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class AncorGrade
{
    public static void ApplyDark(Bitmap bmp, double pivot, double contrast, double gamma, double gain, double tr, double tg, double tb, bool negative)
    {
        Rectangle r = new Rectangle(0, 0, bmp.Width, bmp.Height);
        BitmapData d = bmp.LockBits(r, ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = d.Stride;
        int bytes = Math.Abs(stride) * bmp.Height;
        byte[] buf = new byte[bytes];
        Marshal.Copy(d.Scan0, buf, 0, bytes);
        const double lumR = 0.299;
        const double lumG = 0.587;
        const double lumB = 0.114;
        for (int y = 0; y < bmp.Height; y++)
        {
            int row = stride >= 0 ? y * stride : (bmp.Height - 1 - y) * Math.Abs(stride);
            for (int x = 0; x < bmp.Width; x++)
            {
                int i = row + x * 4;
                double lum = (lumR * buf[i + 2] + lumG * buf[i + 1] + lumB * buf[i]) / 255.0;
                double v = negative ? (1.0 - lum) : lum;
                v = Math.Pow(v, gamma);
                v = (v - pivot) * contrast + pivot;
                v = v * gain;
                if (v < 0.0) { v = 0.0; }
                if (v > 1.0) { v = 1.0; }
                buf[i] = (byte)(v * tb * 255.0);
                buf[i + 1] = (byte)(v * tg * 255.0);
                buf[i + 2] = (byte)(v * tr * 255.0);
            }
        }
        Marshal.Copy(buf, 0, d.Scan0, bytes);
        bmp.UnlockBits(d);
    }
}
'@
Add-Type -TypeDefinition $code -ReferencedAssemblies 'System.Drawing'

$serif = New-Object System.Drawing.Text.PrivateFontCollection
$serif.AddFontFile('C:\AncorOS\assets\fonts\CormorantGaramond-wght.ttf')
$black = New-Object System.Drawing.Text.PrivateFontCollection
$black.AddFontFile('C:\AncorOS\assets\fonts\PirataOne-Regular.ttf')
$serifFam = $serif.Families[0]
$blackFam = $black.Families[0]

function Get-Rect {
  param($Image, [int]$W, [int]$H, [double]$cropTop, [double]$cropBottom)
  $cropY = [int]($Image.Height * $cropTop)
  $cropH = $Image.Height - $cropY - [int]($Image.Height * $cropBottom)
  if ($cropH -lt 8) { $cropH = 8 }
  $aspect = $W / $H
  $sw = $Image.Width
  $sh = $cropH
  if (($sw / $sh) -gt $aspect) { $sw = [int]($sh * $aspect) } else { $sh = [int]($sw / $aspect) }
  if ($sw -lt 4) { $sw = 4 }
  if ($sh -lt 4) { $sh = 4 }
  return (New-Object System.Drawing.Rectangle -ArgumentList ([int](($Image.Width - $sw) / 2)), ($cropY + [int](($cropH - $sh) / 2)), $sw, $sh)
}

function New-Base {
  param($img, [int]$W, [int]$H, [double]$cropTop, [double]$cropBottom, [bool]$grade)
  $stage = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
  $gs = [System.Drawing.Graphics]::FromImage($stage)
  $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gs.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $gs.DrawImage($img, (New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H), (Get-Rect $img $W $H $cropTop $cropBottom), [System.Drawing.GraphicsUnit]::Pixel)
  $gs.Dispose()
  if ($grade) { [AncorGrade]::ApplyDark($stage, 0.34, 1.26, 0.85, 1.20, 0.72, 0.88, 1.00, $true) }
  return $stage
}

function Add-Vignette {
  param($g, [int]$W, [int]$H, [int]$alpha)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddRectangle((New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF(($W / 2), ($H / 2))
  $br.FocusScales = New-Object System.Drawing.PointF(0.68, 0.68)
  $br.CenterColor = [System.Drawing.Color]::FromArgb(0, 5, 5, 14)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb($alpha, 5, 5, 14))
  $g.FillRectangle($br, (New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H))
  $br.Dispose()
  $path.Dispose()
}

function Add-Glow {
  param($g, [single]$x, [single]$y, [single]$r, [int]$a)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(($x - $r), ($y - $r), ($r * 2), ($r * 2))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF($x, $y)
  $br.FocusScales = New-Object System.Drawing.PointF(0, 0)
  $br.CenterColor = [System.Drawing.Color]::FromArgb($a, 214, 202, 255)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 180, 160, 255))
  $g.FillPath($br, $path)
  $br.Dispose()
  $path.Dispose()
}

$map = @(
  @{ src = 'file-_1_.png'; top = 0.0; bottom = 0.0 },
  @{ src = 'file-_2_.png'; top = 0.0; bottom = 0.0 },
  @{ src = 'file-_3_.png'; top = 0.0; bottom = 0.0 },
  @{ src = 'file.png'; top = 0.215; bottom = 0.0 },
  @{ src = 'file-_4_.png'; top = 0.0; bottom = 0.14 },
  @{ src = 'file-_5_.png'; top = 0.0; bottom = 0.14 }
)

$bannerImg = [System.Drawing.Image]::FromFile((Join-Path $SrcDir 'file-_1_.png'))
$bw = 1600
$bh = 500
$bannerBase = New-Base $bannerImg $bw $bh 0.0 0.0 $true
$banner = New-Object System.Drawing.Bitmap -ArgumentList $bw, $bh
$bg = [System.Drawing.Graphics]::FromImage($banner)
$bg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$bg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$bg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$full = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $bw, $bh
$bg.DrawImage($bannerBase, $full, $full, [System.Drawing.GraphicsUnit]::Pixel)
$bannerBase.Dispose()
Add-Glow $bg ([single]($bw * 0.30)) ([single]($bh * 0.46)) ([single]($bw * 0.34)) 54
$shade = New-Object System.Drawing.Drawing2D.LinearGradientBrush($full, [System.Drawing.Color]::FromArgb(205, 10, 9, 20), [System.Drawing.Color]::FromArgb(35, 10, 9, 20), 0.0)
$bg.FillRectangle($shade, $full)
$shade.Dispose()
Add-Vignette $bg $bw $bh 120
$titleFont = New-Object System.Drawing.Font($serifFam, 76.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$subFont = New-Object System.Drawing.Font($serifFam, 27.0, [System.Drawing.FontStyle]::Italic, [System.Drawing.GraphicsUnit]::Pixel)
$eyebrowFont = New-Object System.Drawing.Font($blackFam, 19.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(252, 250, 247, 253))
$soft = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(224, 226, 216, 246))
$accentPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190, 184, 160, 255), 1.6)
$bg.DrawString('ANCOROS', $eyebrowFont, $soft, 62, 118)
$bg.DrawString('AncorOS', $titleFont, $white, 58, 140)
$bg.DrawString('Эфирный Linux для тёмных', $subFont, $soft, 62, 250)
$bg.DrawLine($accentPen, 62, 232, 168, 232)
$bg.DrawString('Ubuntu 26.04 LTS  ·  GNOME 50  ·  Wayland only  ·  Angelcore', $subFont, $soft, 62, 300)
$accentPen.Dispose(); $white.Dispose(); $soft.Dispose()
$titleFont.Dispose(); $subFont.Dispose(); $eyebrowFont.Dispose()
$bg.Dispose()
$banner.Save((Join-Path $OutDir 'banner.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$banner.Dispose()
$bannerImg.Dispose()
"written banner.png"

$thumbW = 480
$thumbH = 320
$cols = 3
$rows = 2
$sheet = New-Object System.Drawing.Bitmap -ArgumentList ($thumbW * $cols), ($thumbH * $rows)
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear([System.Drawing.Color]::FromArgb(10, 9, 16))
$sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$i = 0
foreach ($m in $map) {
  $p = Join-Path $SrcDir $m.src
  if (-not (Test-Path $p)) { continue }
  $im = [System.Drawing.Image]::FromFile($p)
  $base = New-Base $im $thumbW $thumbH $m.top $m.bottom $true
  $cell = New-Object System.Drawing.Rectangle -ArgumentList (($i % $cols) * $thumbW), ([math]::Floor($i / $cols) * $thumbH), $thumbW, $thumbH
  $sg.DrawImage($base, $cell, $cell, [System.Drawing.GraphicsUnit]::Pixel)
  $base.Dispose()
  $im.Dispose()
  $i++
}
$sg.Dispose()
$sheet.Save((Join-Path $OutDir 'gallery.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
"written gallery.png"

$logoW = 512
$logoH = 512
$logoImg = [System.Drawing.Image]::FromFile((Join-Path $SrcDir 'file-_2_.png'))
$logoBase = New-Base $logoImg $logoW $logoH 0.0 0.0 $true
$logo = New-Object System.Drawing.Bitmap -ArgumentList $logoW, $logoH
$lg = [System.Drawing.Graphics]::FromImage($logo)
$lg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$lg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$lgFull = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $logoW, $logoH
$lg.DrawImage($logoBase, $lgFull, $lgFull, [System.Drawing.GraphicsUnit]::Pixel)
$logoBase.Dispose()
Add-Vignette $lg $logoW $logoH 170
$logoFont = New-Object System.Drawing.Font($serifFam, 92.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$logoBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(250, 252, 250, 253))
$shadow = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120, 0, 0, 0))
$logoText = 'AncorOS'
$size = $lg.MeasureString($logoText, $logoFont)
$lx = [single](($logoW - $size.Width) / 2)
$ly = [single]($logoH - $size.Height - 74)
$lg.DrawString($logoText, $logoFont, $shadow, ($lx + 2), ($ly + 3))
$lg.DrawString($logoText, $logoFont, $logoBrush, $lx, $ly)
$logoFont.Dispose(); $logoBrush.Dispose(); $shadow.Dispose()
$lg.Dispose()
$logo.Save((Join-Path $OutDir 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$logo.Dispose()
$logoImg.Dispose()
"written logo.png"

Get-ChildItem $OutDir -Filter '*.png' | ForEach-Object {
  $im = [System.Drawing.Image]::FromFile($_.FullName)
  "{0} -> {1}x{2} {3:N0} KB" -f $_.Name, $im.Width, $im.Height, ($_.Length / 1KB)
  $im.Dispose()
}