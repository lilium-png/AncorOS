#!/bin/bash
set -u
W=/home/builder/work
S="$W/bsnap"
echo "=== snap layout ==="
find "$S" -maxdepth 3 -type d | head -30
echo "=== snapcraft.yaml ==="
sed -n '1,60p' "$S/snap/snapcraft.yaml" 2>/dev/null
echo "=== install-sources in snap ==="
grep -rl --binary-files=without-match 'install-sources' "$S" 2>/dev/null | head -20
echo "=== autoinstall in snap (bin scripts) ==="
grep -rl --binary-files=without-match 'autoinstall' "$S/bin" "$S/meta" 2>/dev/null | head -20
echo "=== snap apps ==="
cat "$S/meta/gui" 2>/dev/null
echo "=== launcher scripts ==="
ls "$S/bin" | head -40
echo "=== done ==="