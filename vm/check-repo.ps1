param(
  [string]$Root = 'C:\Project-AncorOS',
  [string]$Git  = 'C:\Program Files\Git\bin\git.exe',
  [string]$Log  = 'C:\Project-AncorOS\progress.log'
)
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing
Set-Location $Root

$out = New-Object System.Collections.Generic.List[string]
function Emit([string]$tag, [string]$text) {
  $line = "[$((Get-Date).ToString('HH:mm:ss'))] [$tag] $text"
  $out.Add($line)
}

Emit 'MANIFEST' 'проверка состава assets'
$w = Get-ChildItem 'assets\wallpapers' -File -Filter '*.png'
$s = Get-ChildItem 'assets\generated\slides' -File -Filter '*.png'
$f = Get-ChildItem 'assets\fonts' -File -Filter '*.ttf'
$g = Get-ChildItem 'assets\generated' -File -Filter '*.png'
$r = Get-ChildItem 'assets\repo' -File -Filter '*.png'
Emit 'MANIFEST' "wallpapers=$($w.Count)/10 slides=$($s.Count)/5 fonts=$($f.Count)/5 generated=$($g.Count) repo=$($r.Count)"

$dim = @{}
foreach ($d in ($w + $s)) {
  $i = [System.Drawing.Image]::FromFile($d.FullName)
  $k = "$($i.Width)x$($i.Height)"
  $i.Dispose()
  if (-not $dim.ContainsKey($k)) { $dim[$k] = 0 }
  $dim[$k]++
}
$dimTxt = ($dim.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', '
Emit 'MANIFEST' "разрешения: $dimTxt"

$tiny = @($w + $s | Where-Object { $_.Length -lt 1024 })
Emit 'MANIFEST' "подозрительно малых файлов: $($tiny.Count)"

Emit 'IGNORE' 'проверка .gitignore'
$junk = @(
  'vm/builder.qcow2',
  'downloads/ubuntu-26.04.1-desktop-amd64.iso',
  'out/AncorOS-26.04-amd64.iso',
  'vm/id_ed25519',
  'vm/id_ed25519.pub',
  'AncorISO/AncorOS-26.04-amd64.iso',
  'vm/serial.log',
  'vm/seed-http.log',
  'assets/src/GitHubDesktopSetup-x64.exe',
  'assets/src/Cormorant_Garamond.zip'
)
$ignored = 0
$notIgnored = @()
foreach ($j in $junk) {
  & $Git check-ignore -q $j
  if ($LASTEXITCODE -eq 0) { $ignored++ } else { $notIgnored += $j }
}
Emit 'IGNORE' "проверено $($junk.Count) путей, исключено $ignored"
if ($notIgnored.Count -gt 0) { Emit 'IGNORE' "НЕ исключены: $($notIgnored -join ', ')" }

Emit 'LICENSE' 'проверка лицензии'
$lic = Get-Content 'LICENSE' -Raw
$need = @('MIT License', 'Permission is hereby granted', 'THE SOFTWARE IS PROVIDED', 'WITHOUT WARRANTY OF ANY KIND')
$miss = @($need | Where-Object { -not $lic.Contains($_) })
if ($miss.Count -eq 0) { Emit 'LICENSE' 'MIT, все 4 ключевые фразы на месте' }
else { Emit 'LICENSE' "ОТСУТСТВУЕТ: $($miss -join ', ')" }

Emit 'README' 'проверка ссылок'
$t = [System.IO.File]::ReadAllText('README.md', [System.Text.Encoding]::UTF8)
$paths = @([regex]::Matches($t, '\]\(([^)]+)\)') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '^https?://' } | Sort-Object -Unique)
$broken = @()
foreach ($p in $paths) { if (-not (Test-Path $p)) { $broken += $p } }
Emit 'README' "локальных ссылок $($paths.Count), битых $($broken.Count)"
if ($broken.Count -gt 0) { Emit 'README' "битые: $($broken -join ', ')" }

$ext = @([regex]::Matches($t, 'https://github\.com/[\w./-]+') | ForEach-Object { $_.Value } | Sort-Object -Unique)
foreach ($u in $ext) {
  try {
    $resp = Invoke-WebRequest -Uri $u -Method Head -UseBasicParsing -TimeoutSec 20
    Emit 'README' "$u -> $($resp.StatusCode)"
  } catch {
    Emit 'README' "$u -> ошибка $($_.Exception.Message)"
  }
}

Emit 'GIT' 'состояние репозитория'
$cnt = & $Git count-objects -vH
Emit 'GIT' (($cnt | Where-Object { $_ -match 'count:|size:|in-pack:|packs:' }) -join ' | ')
$tracked = (& $Git ls-files | Measure-Object -Line).Lines
Emit 'GIT' "отслеживается файлов: $tracked"
$dirty = & $Git status --short
if ($dirty) { Emit 'GIT' "незакоммичено: $(($dirty | Measure-Object -Line).Lines) записей" }
else { Emit 'GIT' 'рабочее дерево чистое' }

$out | ForEach-Object { Write-Output $_ }
Add-Content -Path $Log -Value $out -Encoding UTF8
'CHECK-REPO-DONE'