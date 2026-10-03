#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
echo "=== finalrd package ==="
grep -E '^Package: (finalrd|cubic|live-installer)' -A3 "$R/var/lib/dpkg/status" | head -20
echo "=== finalrd files ==="
ls "$R/usr/lib/finalrd" 2>/dev/null | head -20
find "$R/usr/share/finalrd" -maxdepth 2 2>/dev/null | head -40
echo "=== installer binaries / desktop entries ==="
find "$R/usr/bin" "$R/usr/sbin" -maxdepth 1 -name '*install*' -o -maxdepth 1 -name 'finalrd*' 2>/dev/null | head -20
ls "$R/usr/share/applications" | head -40
echo "=== coreutils / rust-coreutils in merged tree ==="
for p in coreutils rust-coreutils; do
  v=$(awk -v pkg="$p" '$1=="Package:" && $2==pkg {f=1} f&&$1=="Version:"{print $2; exit}' "$R/var/lib/dpkg/status")
  echo "$p ${v:-ABSENT}"
done
ls -la "$R/usr/bin/gnu-ls" 2>/dev/null || echo "no gnu-ls"
echo "=== cloud-init presence ==="
awk -v pkg=cloud-init '$1=="Package:" && $2==pkg {f=1} f&&$1=="Version:"{print "cloud-init " $2; exit}' "$R/var/lib/dpkg/status"
ls "$R/etc/cloud/cloud.cfg.d/" 2>/dev/null | head -20
echo "=== datasource config ==="
grep -rn 'datasource_list' "$R/etc/cloud/" 2>/dev/null | head -10
echo "=== autoinstall references in tree ==="
grep -rl --binary-files=without-match 'autoinstall' "$R/etc" "$R/usr/lib/finalrd" "$R/usr/share/finalrd" 2>/dev/null | head -20
echo "=== slides / slideshow in tree ==="
find "$R/usr/share" -maxdepth 2 -iname '*slide*' 2>/dev/null | head -20
echo "=== branding assets ==="
find "$R/usr/share/finalrd" -iname '*brand*' -o -iname '*.html' 2>/dev/null | head -20
echo "=== snaps preinstalled ==="
ls "$R/snap" 2>/dev/null | head -20
ls "$R/var/lib/snapd/snaps" 2>/dev/null | head -20
echo "=== wallpaper dir ==="
ls "$R/usr/share/backgrounds" | head -20
echo "=== fonts available ==="
ls "$R/usr/share/fonts/truetype" | head -30
echo "=== ptyxis desktop file ==="
ls "$R/usr/share/applications" | grep -i ptyxis
echo "=== done ==="