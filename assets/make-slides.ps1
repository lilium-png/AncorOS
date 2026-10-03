param(
  [string]$SrcDir = 'C:\AncorOS\assets\src',
  [string]$SlidesDir = 'C:\AncorOS\assets\generated\slides',
  [string]$WallDir = 'C:\AncorOS\assets\wallpapers'
)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $SlidesDir | Out-Null
New-Item -ItemType Directory -Force -Path $WallDir | Out-Null

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
                if (v < 0.0) v = 0.0;
                if (v > 1.0) v = 1.0;
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
$serifBlack = New-Object System.Drawing.Text.PrivateFontCollection
$serifBlack.AddFontFile('C:\AncorOS\assets\fonts\PirataOne-Regular.ttf')
$serifTitle = $serif.Families[0]
$blackTitle = $serifBlack.Families[0]

$scenes = @(
  @{ src = 'file.png'; slug = '01-welcome'; title = 'AncorOS'; sub = 'Ubuntu 26.04 base, GNOME 50, Wayland only'; cropTop = 0.215; cropBottom = 0.0 },
  @{ src = 'file-_1_.png'; slug = '02-angelcore'; title = 'Angelcore'; sub = 'Wings, light and quiet marble'; cropTop = 0.0; cropBottom = 0.0 },
  @{ src = 'file-_2_.png'; slug = '03-whitesur'; title = 'WhiteSur'; sub = 'GTK3, GTK4 and Shell in darker mode'; cropTop = 0.0; cropBottom = 0.0 },
  @{ src = 'file-_3_.png'; slug = '04-preinstalled'; title = 'Preinstalled'; sub = 'Chrome, Telegram, OBS, Steam, VPN clients'; cropTop = 0.0; cropBottom = 0.0 },
  @{ src = 'file-_4_.png'; slug = '05-automation'; title = 'Automation'; sub = 'Autoinstall configures the system on first boot'; cropTop = 0.0; cropBottom = 0.14 }
)

function Get-SourceRect {
  param($Image, [int]$W, [int]$H, [double]$cropTop, [double]$cropBottom)
  $cropY = [int]($Image.Height * $cropTop)
  $cropH = $Image.Height - $cropY - [int]($Image.Height * $cropBottom)
  if ($cropH -lt 8) { $cropH = 8 }
  $aspect = $W / $H
  $sw = $Image.Width
  $sh = $cropH
  if (($sw / $sh) -gt $aspect) {
    $sw = [int]($sh * $aspect)
  } else {
    $sh = [int]($sw / $aspect)
  }
  $sx = [int](($Image.Width - $sw) / 2)
  $sy = $cropY + [int](($cropH - $sh) / 2)
  if ($sw -lt 4) { $sw = 4 }
  if ($sh -lt 4) { $sh = 4 }
  return (New-Object System.Drawing.Rectangle -ArgumentList $sx, $sy, $sw, $sh)
}

function New-DarkMatrix {
  $m = New-Object System.Drawing.Imaging.ColorMatrix
  $lumR = 0.299
  $lumG = 0.587
  $lumB = 0.114
  $k = 1.32
  $offset = -0.105
  $m.Matrix00 = [single]($lumR * 0.70 * $k)
  $m.Matrix01 = [single]($lumG * 0.70 * $k)
  $m.Matrix02 = [single]($lumB * 0.70 * $k)
  $m.Matrix03 = 0
  $m.Matrix04 = [single]$offset
  $m.Matrix10 = [single]($lumR * 0.86 * $k)
  $m.Matrix11 = [single]($lumG * 0.86 * $k)
  $m.Matrix12 = [single]($lumB * 0.86 * $k)
  $m.Matrix13 = 0
  $m.Matrix14 = [single]($offset * 0.9)
  $m.Matrix20 = [single]($lumR * 1.00 * $k)
  $m.Matrix21 = [single]($lumG * 1.00 * $k)
  $m.Matrix22 = [single]($lumB * 1.00 * $k)
  $m.Matrix23 = 0
  $m.Matrix24 = [single]($offset * 0.6)
  $m.Matrix33 = 1
  $m.Matrix44 = 1
  return $m
}

function Add-ColdGlow {
  param($g, [int]$W, [int]$H, [single]$fx, [single]$fy, [single]$radius, [int]$alpha)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(($fx - $radius), ($fy - $radius), ($radius * 2), ($radius * 2))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF($fx, $fy)
  $br.FocusScales = New-Object System.Drawing.PointF(0, 0)
  $br.CenterColor = [System.Drawing.Color]::FromArgb($alpha, 216, 234, 255)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, 186, 214, 255))
  $g.FillPath($br, $path)
  $br.Dispose()
  $path.Dispose()
}

function Add-Vignette {
  param($g, [int]$W, [int]$H, [int]$alpha)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddRectangle((New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF(($W / 2), ($H / 2))
  $br.FocusScales = New-Object System.Drawing.PointF(0.66, 0.66)
  $br.CenterColor = [System.Drawing.Color]::FromArgb(0, 4, 6, 14)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb($alpha, 4, 6, 14))
  $g.FillRectangle($br, (New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H))
  $br.Dispose()
  $path.Dispose()
}

function New-GradedBase {
  param($img, [int]$W, [int]$H, [double]$cropTop, [double]$cropBottom, [bool]$grade)
  $stage = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
  $gs = [System.Drawing.Graphics]::FromImage($stage)
  $gs.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $gs.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $gs.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $src = Get-SourceRect $img $W $H $cropTop $cropBottom
  $dst = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H
  $gs.DrawImage($img, $dst, $src, [System.Drawing.GraphicsUnit]::Pixel)
  $gs.Dispose()
  if ($grade) {
    [AncorGrade]::ApplyDark($stage, 0.34, 1.26, 0.85, 1.20, 0.72, 0.88, 1.00, $true)
  }
  return $stage
}

foreach ($s in $scenes) {
  $path = Join-Path $SrcDir $s.src
  if (-not (Test-Path $path)) { "MISSING SOURCE $($s.src)"; continue }
  $img = [System.Drawing.Image]::FromFile($path)

  foreach ($spec in @(@{ w = 448; h = 304; kind = 'slide' }, @{ w = 1920; h = 1080; kind = 'wall-small' }, @{ w = 3840; h = 2160; kind = 'wall-big' })) {
    $W = $spec.w
    $H = $spec.h
    $isSlide = ($spec.kind -eq 'slide')
    $base = New-GradedBase $img $W $H $s.cropTop $s.cropBottom $true

    $bmp = New-Object System.Drawing.Bitmap -ArgumentList $W, $H
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $full = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H
    $g.DrawImage($base, $full, $full, [System.Drawing.GraphicsUnit]::Pixel)
    $base.Dispose()

    if ($isSlide) {
      $scrimRect = New-Object System.Drawing.Rectangle -ArgumentList 0, 0, $W, $H
      $scrim = New-Object System.Drawing.Drawing2D.LinearGradientBrush($scrimRect, [System.Drawing.Color]::FromArgb(140, 6, 6, 14), [System.Drawing.Color]::FromArgb(18, 6, 6, 14), 90.0)
      $g.FillRectangle($scrim, $scrimRect)
      $scrim.Dispose()
      Add-Vignette $g $W $H 115
      $eyebrowFont = New-Object System.Drawing.Font($blackTitle, 12.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
      $titleFont = New-Object System.Drawing.Font($serifTitle, 40.0, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
      $subFont = New-Object System.Drawing.Font($serifTitle, 15.0, [System.Drawing.FontStyle]::Italic, [System.Drawing.GraphicsUnit]::Pixel)
      $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(250, 251, 249, 253))
      $soft = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(215, 220, 228, 246))
      $accent = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(140, 214, 232, 255), 1.0)
      $g.DrawLine($accent, 26, 214, 92, 214)
      $g.DrawString('ANCOROS', $eyebrowFont, $soft, 26, 138)
      $g.DrawString($s.title, $titleFont, $white, 26, 156)
      $g.DrawString($s.sub, $subFont, $soft, 26, 234)
      $accent.Dispose()
      $white.Dispose()
      $soft.Dispose()
      $eyebrowFont.Dispose()
      $titleFont.Dispose()
      $subFont.Dispose()
    } else {
      Add-ColdGlow $g $W $H ([single]($W * 0.5)) ([single]($H * 0.40)) ([single]($W * 0.28)) 60
      Add-Vignette $g $W $H 135
    }

    $g.Dispose()
    if ($isSlide) {
      $out = Join-Path $SlidesDir ($s.slug + '.png')
    } else {
      $suffix = if ($W -eq 3840) { '3840x2160' } else { '1920x1080' }
      $out = Join-Path $WallDir ('ancoros-angelcore-' + $s.slug + '-' + $suffix + '.png')
    }
    $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    "written $out"
  }
  $img.Dispose()
}

"--- results ---"
Get-ChildItem $SlidesDir -Filter '*.png' | ForEach-Object {
  $im = [System.Drawing.Image]::FromFile($_.FullName)
  "{0} -> {1}x{2} {3:N0} KB" -f $_.Name, $im.Width, $im.Height, ($_.Length / 1KB)
  $im.Dispose()
}
Get-ChildItem $WallDir -Filter '*.png' | ForEach-Object {
  $im = [System.Drawing.Image]::FromFile($_.FullName)
  "{0} -> {1}x{2} {3:N0} KB" -f $_.Name, $im.Width, $im.Height, ($_.Length / 1KB)
  $im.Dispose()
}