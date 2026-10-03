param(
  [string]$OutDir = 'C:\AncorOS\assets\generated'
)
Add-Type -AssemblyName System.Drawing
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $OutDir 'slides') | Out-Null

function New-Rgb([int]$r, [int]$g, [int]$b) {
  return [System.Drawing.Color]::FromArgb(255, $r, $g, $b)
}

function Fill-Sky {
  param($g, [int]$Width, [int]$Height, $stops)
  $bands = 420
  $bandH = [double]$Height / $bands
  for ($b = 0; $b -lt $bands; $b++) {
    $pos = ($b + 0.5) / $bands
    $acc = $stops[0]
    $nxt = $stops[$stops.Count - 1]
    for ($i = 0; $i -lt ($stops.Count - 1); $i++) {
      if ($pos -ge $stops[$i][0] -and $pos -le $stops[$i + 1][0]) {
        $acc = $stops[$i]
        $nxt = $stops[$i + 1]
        break
      }
    }
    $span = [Math]::Max(0.000001, ($nxt[0] - $acc[0]))
    $t = [Math]::Min(1.0, [Math]::Max(0.0, ($pos - $acc[0]) / $span))
    $e = $t * $t * (3.0 - 2.0 * $t)
    $cr = [int]($acc[1] + ($nxt[1] - $acc[1]) * $e)
    $cg = [int]($acc[2] + ($nxt[2] - $acc[2]) * $e)
    $cb = [int]($acc[3] + ($nxt[3] - $acc[3]) * $e)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, $cr, $cg, $cb))
    $g.FillRectangle($brush, 0, [float]($b * $bandH), $Width, [float]($bandH + 1.5))
    $brush.Dispose()
  }
}

function Add-Glow {
  param($g, [single]$X, [single]$Y, [single]$R, $color, [int]$alpha)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(($X - $R), ($Y - $R), ($R * 2), ($R * 2))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF($X, $Y)
  $br.FocusScales = New-Object System.Drawing.PointF(0, 0)
  $br.CenterColor = [System.Drawing.Color]::FromArgb($alpha, $color.R, $color.G, $color.B)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
  $g.FillPath($br, $path)
  $br.Dispose()
  $path.Dispose()
}

function Add-CloudBlob {
  param($g, [single]$X, [single]$Y, [single]$RX, [single]$RY, $color, [int]$alpha)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddEllipse(($X - $RX), ($Y - $RY), ($RX * 2), ($RY * 2))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF($X, $Y)
  $br.FocusScales = New-Object System.Drawing.PointF(0, 0)
  $br.CenterColor = [System.Drawing.Color]::FromArgb($alpha, $color.R, $color.G, $color.B)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B))
  $g.FillPath($br, $path)
  $br.Dispose()
  $path.Dispose()
}

function Add-Cloud {
  param($g, [int]$Width, [int]$Height, [single]$CX, [single]$CY, [single]$Scale, $color, [int]$Alpha, [int]$Seed)
  $rnd = New-Object System.Random($Seed)
  $puffs = 9 + $rnd.Next(6)
  for ($i = 0; $i -lt $puffs; $i++) {
    $t = $i / [double]($puffs - 1)
    $spread = [Math]::Sin($t * [Math]::PI)
    $px = $CX + ($t - 0.5) * $Scale * 2.2
    $py = $CY - $spread * $Scale * 0.34 + ($rnd.NextDouble() - 0.5) * $Scale * 0.12
    $rx = $Scale * (0.24 + 0.20 * $rnd.NextDouble()) * (0.55 + 0.65 * $spread)
    $ry = $rx * (0.52 + 0.22 * $rnd.NextDouble())
    $a = [int]($Alpha * (0.45 + 0.55 * $spread))
    Add-CloudBlob $g $px $py $rx $ry $color $a
  }
}

function New-WingPath {
  param([single]$len, [single]$h)
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.StartFigure()
  $p.AddBezier(0, 0, (0.10 * $len), (-0.04 * $h), (0.24 * $len), (-0.18 * $h), (0.44 * $len), (-0.30 * $h))
  $p.AddBezier((0.44 * $len), (-0.30 * $h), (0.66 * $len), (-0.42 * $h), (0.86 * $len), (-0.50 * $h), $len, (-0.60 * $h))
  $p.AddBezier($len, (-0.60 * $h), (0.90 * $len), (-0.42 * $h), (0.78 * $len), (-0.24 * $h), (0.66 * $len), (-0.12 * $h))
  $p.AddBezier((0.66 * $len), (-0.12 * $h), (0.54 * $len), (-0.02 * $h), (0.40 * $len), (0.06 * $h), (0.26 * $len), (0.10 * $h))
  $p.AddBezier((0.26 * $len), (0.10 * $h), (0.14 * $len), (0.13 * $h), (0.05 * $len), (0.10 * $h), 0, 0)
  $p.CloseFigure()
  return $p
}

function Add-Wing {
  param(
    $g, [single]$X, [single]$Y, [single]$Len, [single]$Height, [single]$Angle,
    [int]$Dir, $color, [int]$Alpha, [int]$Seed
  )
  $rnd = New-Object System.Random($Seed)
  $state = $g.Save()
  $g.TranslateTransform($X, $Y)
  $g.RotateTransform($Angle)
  if ($Dir -lt 0) { $g.ScaleTransform(-1, 1) }

  $path = New-WingPath $Len $Height

  $glowPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int]($Alpha * 0.10), $color.R, $color.G, $color.B), [float]($Len * 0.012))
  $g.DrawPath($glowPen, $path)
  $glowPen.Dispose()
  $glowPen2 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int]($Alpha * 0.16), $color.R, $color.G, $color.B), [float]($Len * 0.004))
  $g.DrawPath($glowPen2, $path)
  $glowPen2.Dispose()

  $region = New-Object System.Drawing.Region($path)
  $clipState = $g.Save()
  $g.SetClip($region)

  $rect = New-Object System.Drawing.RectangleF(0, (-0.65 * $Height), $Len, (0.85 * $Height))
  $br = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb($Alpha, $color.R, $color.G, $color.B), [System.Drawing.Color]::FromArgb([int]($Alpha * 0.18), $color.R, $color.G, $color.B), 4.0)
  $g.FillPath($br, $path)
  $br.Dispose()

  $ribPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int]($Alpha * 0.20), $color.R, $color.G, $color.B), [float]($Len * 0.0035))
  $ribPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $ribPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  for ($i = 1; $i -le 10; $i++) {
    $t = $i / 11.0
    $sx = 0.05 * $Len + $t * 0.16 * $Len
    $sy = 0.02 * $Height - $t * 0.10 * $Height
    $ex = 0.30 * $Len + $t * 0.66 * $Len
    $ey = (0.07 * $Height) - $t * 0.52 * $Height
    $g.DrawLine($ribPen, [single]$sx, [single]$sy, [single]$ex, [single]$ey)
  }
  $ribPen.Dispose()

  $scallopPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int]($Alpha * 0.13), $color.R, $color.G, $color.B), [float]($Len * 0.003))
  for ($i = 1; $i -le 8; $i++) {
    $t = $i / 9.0
    $cx = 0.26 * $Len + $t * 0.66 * $Len
    $cy = (0.08 * $Height) - $t * 0.54 * $Height
    $r = [float]($Len * (0.045 + 0.030 * (1.0 - $t)))
    $box = New-Object System.Drawing.RectangleF([single]($cx - $r), [single]($cy - $r * 0.7), [single]($r * 2), [single]($r * 1.5))
    $g.DrawArc($scallopPen, $box, 200, 250)
  }
  $scallopPen.Dispose()

  $sheenRect = New-Object System.Drawing.RectangleF -ArgumentList 0, ([single](-0.55 * $Height)), ([single](0.55 * $Len)), ([single](0.78 * $Height))
  $sheen = New-Object System.Drawing.Drawing2D.LinearGradientBrush -ArgumentList $sheenRect, ([System.Drawing.Color]::FromArgb([int]($Alpha * 0.16), $color.R, $color.G, $color.B)), ([System.Drawing.Color]::FromArgb(0, $color.R, $color.G, $color.B)), 70.0
  $g.FillRectangle($sheen, [single](0.05 * $Len), [single](-0.58 * $Height), [single](0.5 * $Len), [single](0.75 * $Height))
  $sheen.Dispose()

  $g.Restore($clipState)
  $region.Dispose()

  $edge = New-Object System.Drawing.Drawing2D.GraphicsPath
  $edge.StartFigure()
  $edge.AddBezier(0, 0, (0.10 * $Len), (-0.04 * $Height), (0.24 * $Len), (-0.18 * $Height), (0.44 * $Len), (-0.30 * $Height))
  $edge.AddBezier((0.44 * $Len), (-0.30 * $Height), (0.66 * $Len), (-0.42 * $Height), (0.86 * $Len), (-0.50 * $Height), $len, (-0.60 * $Height))
  $edgePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb([int]($Alpha * 0.62), $color.R, $color.G, $color.B), [float]($Len * 0.0035))
  $g.DrawPath($edgePen, $edge)
  $edgePen.Dispose()
  $edge.Dispose()

  $path.Dispose()
  $g.Restore($state)
}

function Add-Rays {
  param($g, [single]$X, [single]$Y, [single]$Len, [int]$Count, [int]$Alpha, $color, [int]$Seed, [single]$Spread = 0.7)
  $rnd = New-Object System.Random($Seed)
  for ($i = 0; $i -lt $Count; $i++) {
    $t = 0.0
    if ($Count -gt 1) { $t = $i / ($Count - 1) }
    $angle = (-1.5707963) + (($t - 0.5) * $Spread * 3.14159265)
    $dx = [Math]::Cos($angle)
    $dy = [Math]::Sin($angle)
    $px = -$dy
    $py = $dx
    $half = $Len * (0.008 + 0.030 * $rnd.NextDouble())
    $a = [int]($Alpha * (0.35 + 0.65 * $rnd.NextDouble()))
    $pts = New-Object 'System.Drawing.PointF[]' 3
    $pts[0] = New-Object System.Drawing.PointF -ArgumentList $X, $Y
    $pts[1] = New-Object System.Drawing.PointF -ArgumentList ([single]($X + $dx * $Len + $px * $half)), ([single]($Y + $dy * $Len + $py * $half))
    $pts[2] = New-Object System.Drawing.PointF -ArgumentList ([single]($X + $dx * $Len - $px * $half)), ([single]($Y + $dy * $Len - $py * $half))
    $brush = New-Object System.Drawing.SolidBrush -ArgumentList ([System.Drawing.Color]::FromArgb($a, $color.R, $color.G, $color.B))
    $g.FillPolygon($brush, $pts)
    $brush.Dispose()
  }
}

function Add-Vignette {
  param($g, [int]$Width, [int]$Height, [int]$Alpha)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddRectangle((New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)))
  $br = New-Object System.Drawing.Drawing2D.PathGradientBrush($path)
  $br.CenterPoint = New-Object System.Drawing.PointF(($Width / 2), ($Height / 2))
  $br.FocusScales = New-Object System.Drawing.PointF(0.62, 0.62)
  $br.CenterColor = [System.Drawing.Color]::FromArgb(0, 8, 7, 16)
  $br.SurroundColors = [System.Drawing.Color[]]@([System.Drawing.Color]::FromArgb($Alpha, 8, 7, 16))
  $g.FillRectangle($br, (New-Object System.Drawing.Rectangle(0, 0, $Width, $Height)))
  $br.Dispose()
  $path.Dispose()
}

function New-AngelScene {
  param([string]$Scene, [int]$Width, [int]$Height)
  $bmp = New-Object System.Drawing.Bitmap($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $rnd = New-Object System.Random(($Width * 31) + $Scene.Length)

  $cloudA = New-Rgb 245 236 244
  $cloudB = New-Rgb 214 226 255
  $cloudC = New-Rgb 255 236 226
  $wingA = New-Rgb 255 251 246
  $wingB = New-Rgb 226 232 255

  switch ($Scene) {
    'dawn' {
      Fill-Sky $g $Width $Height @(
        @(0.00, 16, 18, 44), @(0.20, 34, 36, 78), @(0.42, 78, 66, 118),
        @(0.60, 148, 108, 142), @(0.74, 214, 150, 164), @(0.86, 246, 198, 190), @(1.00, 176, 150, 178))
      Add-Glow $g ([single]($Width * 0.5)) ([single]($Height * 0.80)) ([single]($Width * 0.44)) $cloudC 165
      Add-Rays $g ([single]($Width * 0.5)) ([single]($Height * 0.82)) ([single]($Height * 1.15)) 16 30 $cloudA 771
      Add-Cloud $g $Width $Height ([single]($Width * 0.22)) ([single]($Height * 0.70)) ([single]($Width * 0.15)) $cloudB 46 11
      Add-Cloud $g $Width $Height ([single]($Width * 0.80)) ([single]($Height * 0.62)) ([single]($Width * 0.17)) $cloudA 52 12
      Add-Cloud $g $Width $Height ([single]($Width * 0.50)) ([single]($Height * 0.93)) ([single]($Width * 0.22)) $cloudC 58 13
      Add-Wing $g ([single]($Width * 0.50)) ([single]($Height * 0.70)) ([single]($Width * 0.24)) ([single]($Height * 0.34)) -36 1 $wingA 120 23
      Add-Wing $g ([single]($Width * 0.42)) ([single]($Height * 0.62)) ([single]($Width * 0.32)) ([single]($Height * 0.46)) -24 -1 $wingA 200 21
      Add-Wing $g ([single]($Width * 0.58)) ([single]($Height * 0.62)) ([single]($Width * 0.32)) ([single]($Height * 0.46)) -24 1 $wingA 200 22
      Add-Glow $g ([single]($Width * 0.5)) ([single]($Height * 0.55)) ([single]($Width * 0.30)) $wingB 46
    }
    'midnight' {
      Fill-Sky $g $Width $Height @(
        @(0.00, 8, 10, 26), @(0.26, 18, 24, 58), @(0.52, 40, 50, 96),
        @(0.72, 78, 86, 140), @(0.88, 132, 132, 186), @(1.00, 62, 60, 104))
      Add-Glow $g ([single]($Width * 0.74)) ([single]($Height * 0.24)) ([single]($Width * 0.26)) $cloudA 120
      Add-Glow $g ([single]($Width * 0.74)) ([single]($Height * 0.24)) ([single]($Width * 0.07)) (New-Rgb 255 253 248) 190
      Add-Cloud $g $Width $Height ([single]($Width * 0.30)) ([single]($Height * 0.44)) ([single]($Width * 0.16)) $cloudB 40 31
      Add-Cloud $g $Width $Height ([single]($Width * 0.86)) ([single]($Height * 0.56)) ([single]($Width * 0.15)) $cloudA 44 32
      Add-Cloud $g $Width $Height ([single]($Width * 0.12)) ([single]($Height * 0.78)) ([single]($Width * 0.18)) $cloudB 38 33
      Add-Wing $g ([single]($Width * 0.10)) ([single]($Height * 0.70)) ([single]($Width * 0.28)) ([single]($Height * 0.38)) -40 -1 $wingA 110 35
      Add-Wing $g ([single]($Width * 0.13)) ([single]($Height * 0.68)) ([single]($Width * 0.62)) ([single]($Height * 0.58)) -14 1 $wingA 195 34
      Add-Glow $g ([single]($Width * 0.45)) ([single]($Height * 0.55)) ([single]($Width * 0.26)) $wingB 40
    }
    'sunset' {
      Fill-Sky $g $Width $Height @(
        @(0.00, 22, 18, 46), @(0.22, 58, 36, 86), @(0.44, 122, 66, 110),
        @(0.62, 196, 108, 128), @(0.78, 244, 168, 148), @(0.90, 252, 210, 186), @(1.00, 122, 84, 128))
      Add-Glow $g ([single]($Width * 0.5)) ([single]($Height * 0.86)) ([single]($Width * 0.40)) (New-Rgb 255 232 206) 175
      Add-Rays $g ([single]($Width * 0.5)) ([single]($Height * 0.88)) ([single]($Height * 1.25)) 20 34 $cloudC 881
      Add-Cloud $g $Width $Height ([single]($Width * 0.18)) ([single]($Height * 0.58)) ([single]($Width * 0.16)) $cloudA 50 41
      Add-Cloud $g $Width $Height ([single]($Width * 0.84)) ([single]($Height * 0.50)) ([single]($Width * 0.15)) $cloudC 46 42
      Add-Wing $g ([single]($Width * 0.50)) ([single]($Height * 0.46)) ([single]($Width * 0.26)) ([single]($Height * 0.38)) -40 1 $wingA 115 45
      Add-Wing $g ([single]($Width * 0.40)) ([single]($Height * 0.42)) ([single]($Width * 0.34)) ([single]($Height * 0.50)) -26 -1 $wingA 200 43
      Add-Wing $g ([single]($Width * 0.60)) ([single]($Height * 0.42)) ([single]($Width * 0.34)) ([single]($Height * 0.50)) -26 1 $wingA 200 44
      Add-Glow $g ([single]($Width * 0.5)) ([single]($Height * 0.42)) ([single]($Width * 0.28)) $wingB 44
    }
    'cloudsea' {
      Fill-Sky $g $Width $Height @(
        @(0.00, 18, 26, 62), @(0.24, 46, 66, 122), @(0.46, 96, 126, 178),
        @(0.62, 158, 180, 214), @(0.78, 214, 226, 240), @(1.00, 244, 240, 246))
      Add-Glow $g ([single]($Width * 0.52)) ([single]($Height * 0.18)) ([single]($Width * 0.42)) (New-Rgb 255 252 244) 120
      Add-Rays $g ([single]($Width * 0.52)) ([single]($Height * 0.10)) ([single]($Height * 1.3)) 18 26 (New-Rgb 255 250 240) 991
      Add-Cloud $g $Width $Height ([single]($Width * 0.15)) ([single]($Height * 0.30)) ([single]($Width * 0.17)) $cloudA 60 51
      Add-Cloud $g $Width $Height ([single]($Width * 0.86)) ([single]($Height * 0.38)) ([single]($Width * 0.18)) $cloudA 56 52
      Add-Cloud $g $Width $Height ([single]($Width * 0.34)) ([single]($Height * 0.62)) ([single]($Width * 0.20)) $cloudB 64 53
      Add-Cloud $g $Width $Height ([single]($Width * 0.72)) ([single]($Height * 0.72)) ([single]($Width * 0.21)) $cloudA 62 54
      Add-Cloud $g $Width $Height ([single]($Width * 0.50)) ([single]($Height * 0.92)) ([single]($Width * 0.24)) $cloudC 70 55
      Add-Wing $g ([single]($Width * 0.45)) ([single]($Height * 0.38)) ([single]($Width * 0.17)) ([single]($Height * 0.26)) -20 -1 $wingA 160 56
      Add-Wing $g ([single]($Width * 0.55)) ([single]($Height * 0.38)) ([single]($Width * 0.17)) ([single]($Height * 0.26)) -20 1 $wingA 160 57
    }
    'seraph' {
      Fill-Sky $g $Width $Height @(
        @(0.00, 6, 7, 18), @(0.30, 14, 16, 38), @(0.55, 30, 32, 66),
        @(0.74, 58, 56, 104), @(0.88, 104, 96, 148), @(1.00, 40, 36, 70))
      Add-Glow $g ([single]($Width * 0.5)) ([single]($Height * 0.44)) ([single]($Width * 0.36)) (New-Rgb 255 250 240) 190
      Add-Rays $g ([single]($Width * 0.5)) ([single]($Height * 0.44)) ([single]($Height * 1.1)) 26 40 (New-Rgb 255 248 236) 661
      Add-Wing $g ([single]($Width * 0.50)) ([single]($Height * 0.58)) ([single]($Width * 0.28)) ([single]($Height * 0.44)) -42 1 $wingA 130 63
      Add-Wing $g ([single]($Width * 0.41)) ([single]($Height * 0.54)) ([single]($Width * 0.38)) ([single]($Height * 0.66)) -16 -1 $wingA 210 61
      Add-Wing $g ([single]($Width * 0.59)) ([single]($Height * 0.54)) ([single]($Width * 0.38)) ([single]($Height * 0.66)) -16 1 $wingA 210 62
      Add-Glow $g ([single]($Width * 0.5)) ([single]($Height * 0.47)) ([single]($Width * 0.16)) (New-Rgb 255 255 252) 220
      Add-Cloud $g $Width $Height ([single]($Width * 0.12)) ([single]($Height * 0.84)) ([single]($Width * 0.16)) $cloudB 40 63
      Add-Cloud $g $Width $Height ([single]($Width * 0.88)) ([single]($Height * 0.80)) ([single]($Width * 0.16)) $cloudA 42 64
      Add-Cloud $g $Width $Height ([single]($Width * 0.50)) ([single]($Height * 0.97)) ([single]($Width * 0.22)) $cloudC 46 65
    }
  }

  Add-Vignette $g $Width $Height 150
  $g.Dispose()
  return $bmp
}

$scenes = @(
  @{ key = 'dawn'; slug = '1-dawn' },
  @{ key = 'midnight'; slug = '2-midnight' },
  @{ key = 'sunset'; slug = '3-sunset' },
  @{ key = 'cloudsea'; slug = '4-cloudsea' },
  @{ key = 'seraph'; slug = '5-seraph' }
)

foreach ($s in $scenes) {
  $big = New-AngelScene -Scene $s.key -Width 3840 -Height 2160
  $p1 = Join-Path $OutDir ("ancoros-angelcore-" + $s.slug + "-3840x2160.png")
  $big.Save($p1, [System.Drawing.Imaging.ImageFormat]::Png)
  $big.Dispose()
  Write-Output ("written " + $p1)
  $small = New-AngelScene -Scene $s.key -Width 1920 -Height 1080
  $p2 = Join-Path $OutDir ("ancoros-angelcore-" + $s.slug + "-1920x1080.png")
  $small.Save($p2, [System.Drawing.Imaging.ImageFormat]::Png)
  $small.Dispose()
  Write-Output ("written " + $p2)
}

Copy-Item (Join-Path $OutDir 'ancoros-angelcore-2-midnight-1920x1080.png') (Join-Path $OutDir 'ancoros-angelcore-dark-1920x1080.png') -Force
Copy-Item (Join-Path $OutDir 'ancoros-angelcore-2-midnight-3840x2160.png') (Join-Path $OutDir 'ancoros-angelcore-dark-3840x2160.png') -Force
Write-Output "default dark aliases written"

$slideDefs = @(
  @{ file = '01-welcome.png'; scene = 'dawn'; title = 'AncorOS'; sub = 'Ubuntu 26.04 base, GNOME 50, Wayland only' },
  @{ file = '02-angelcore.png'; scene = 'seraph'; title = 'Angelcore'; sub = 'Cloud, light and wings instead of stars' },
  @{ file = '03-whitesur.png'; scene = 'midnight'; title = 'WhiteSur'; sub = 'GTK3, GTK4 and Shell in darker mode' },
  @{ file = '04-preinstalled.png'; scene = 'sunset'; title = 'Preinstalled'; sub = 'Chrome, Telegram, OBS, Steam, VPN clients' },
  @{ file = '05-automation.png'; scene = 'cloudsea'; title = 'Automation'; sub = 'Autoinstall configures the system on first boot' }
)

$slideDir = Join-Path $OutDir 'slides'
foreach ($def in $slideDefs) {
  $w = 448
  $h = 304
  $sky = New-AngelScene -Scene $def.scene -Width $w -Height $h
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($sky, 0, 0, $w, $h)
  $sky.Dispose()
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

  $scrim = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.Rectangle(0, 0, $w, $h)), [System.Drawing.Color]::FromArgb(150, 10, 9, 20), [System.Drawing.Color]::FromArgb(20, 10, 9, 20), 90.0)
  $g.FillRectangle($scrim, 0, 0, $w, $h)
  $scrim.Dispose()

  $titleFont = New-Object System.Drawing.Font('Segoe UI Light', 31, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $subFont = New-Object System.Drawing.Font('Segoe UI', 13, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
  $titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 250, 252))
  $subBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 240, 226, 236))
  $accent = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(215, 255, 232, 240), 2.0)
  $g.DrawLine($accent, 26, 216, 118, 216)
  $g.DrawString($def.title, $titleFont, $titleBrush, 26, 152)
  $g.DrawString($def.sub, $subFont, $subBrush, 26, 230)
  $accent.Dispose()
  $titleBrush.Dispose()
  $subBrush.Dispose()
  $titleFont.Dispose()
  $subFont.Dispose()
  $g.Dispose()
  $path = Join-Path $slideDir $def.file
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output ("written " + $path)
}