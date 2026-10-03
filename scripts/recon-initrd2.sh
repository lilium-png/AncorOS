#!/bin/bash
set -u
W=/home/builder/work/initrd
echo "=== etc/casper.conf ==="
cat "$W/etc/casper.conf" 2>/dev/null
echo
echo "=== conf/conf.d/default-layer.conf ==="
cat "$W/conf/conf.d/default-layer.conf" 2>/dev/null
echo
echo "=== conf/conf.d listing ==="
ls "$W/conf/conf.d" 2>/dev/null
echo
echo "=== conf listing ==="
ls "$W/conf" 2>/dev/null
echo
echo "=== grep install-sources ==="
grep -rn --binary-files=without-match 'install-sources' "$W" 2>/dev/null | head -20
echo
echo "=== grep squashfs in scripts ==="
grep -rn --binary-files=without-match 'squashfs' "$W/scripts" 2>/dev/null | head -30
echo
echo "=== usr/lib/dracut modules ==="
ls "$W/usr/lib/dracut" 2>/dev/null
ls "$W/usr/lib/dracut/modules.d" 2>/dev/null
echo "=== done ==="