#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
echo "=== who reads install-sources.yaml ==="
grep -rl --binary-files=without-match 'install-sources' "$R/usr/lib" "$R/usr/share" "$R/etc" 2>/dev/null | head -20
echo "=== preinstalled_langs references ==="
grep -rl --binary-files=without-match 'preinstalled_langs' "$R/usr/lib" "$R/usr/share" "$R/etc" 2>/dev/null | head -20
echo "=== language layer handling (search for no-languages / .ru.squashfs) ==="
grep -rn --binary-files=without-match 'no-languages' "$R/usr/lib" "$R/usr/share" "$R/etc" 2>/dev/null | head -10
echo "=== autoinstall references ==="
grep -rl --binary-files=without-match 'autoinstall' "$R/usr/lib" "$R/usr/share" "$R/etc" 2>/dev/null | head -20
echo "=== finalrd strings sample ==="
strings "$R/usr/bin/finalrd" 2>/dev/null | grep -Ei 'sources|locale|lang|casper|media' | head -40
echo "=== finalrd size/type ==="
ls -la "$R/usr/bin/finalrd"
echo "=== ubuntu-desktop-bootstrap snap info ==="
ls -la "$R/var/lib/snapd/snaps/ubuntu-desktop-bootstrap_665.snap" 2>/dev/null
mkdir -p "$W/bsnap"
sudo unsquashfs -d "$W/bsnap" -q "$R/var/lib/snapd/snaps/ubuntu-desktop-bootstrap_665.snap" > /dev/null 2>&1 && echo "bsnap extracted" || echo "bsnap extract failed"
find "$W/bsnap" -maxdepth 4 | head -40
echo "=== done ==="