param(
  [string]$SrcDir = 'C:\AncorOS\assets\src',
  [string]$Out = 'C:\AncorOS\assets\src-sheet.png'
)
Add-Type -AssemblyName System.Drawing
$files = Get-ChildItem $SrcDir -File | Sort-Object Name
foreach ($f in $files) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  "{0} -> {1}x{2}" -f $f.Name, $img.Width, $img.Height
  $img.Dispose()
}
$cellW = 560
$cellH = 420
$cols = 3
$rows = [Math]::Ceiling($files.Count / $cols)
$sheet = New-Object System.Drawing.Bitmap(($cellW * $cols), (($cellH + 26) * $rows))
$g = [System.Drawing.Graphics]::FromImage($sheet)
$g.Clear([System.Drawing.Color]::FromArgb(20, 20, 24))
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = New-Object System.Drawing.Font('Segoe UI', 14)
$brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$i = 0
foreach ($f in $files) {
  $col = $i % $cols
  $row = [Math]::Floor($i / $cols)
  $x = $col * $cellW
  $y = $row * ($cellH + 26)
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  $scale = [Math]::Min($cellW / $img.Width, $cellH / $img.Height)
  $w = [int]($img.Width * $scale)
  $h = [int]($img.Height * $scale)
  $g.DrawImage($img, ($x + [int](($cellW - $w) / 2)), ($y + [int](($cellH - $h) / 2)), $w, $h)
  $img.Dispose()
  $g.DrawString($f.Name, $font, $brush, ($x + 6), ($y + $cellH + 4))
  $i++
}
$g.Dispose()
$sheet.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$sheet.Dispose()
"sheet: $Out"