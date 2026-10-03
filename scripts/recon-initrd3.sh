#!/bin/bash
set -u
W=/home/builder/work/initrd
echo "=== grep LAYERFS ==="
grep -rn --binary-files=without-match 'LAYERFS' "$W" 2>/dev/null | head -20
echo
echo "=== grep overlay (non-module files) ==="
grep -rln --binary-files=without-match 'overlay' "$W/scripts" "$W/lib" "$W/usr/lib" "$W/bin" "$W/sbin" 2>/dev/null | head -20
echo
echo "=== scripts listing ==="
ls -R "$W/scripts" 2>/dev/null | head -60
echo "=== conf/modules ==="
cat "$W/conf/modules" 2>/dev/null | head -60
echo "=== done ==="