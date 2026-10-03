#!/bin/bash
R=/home/builder/work/mnt/merged
echo "=== top level sizes ==="
sudo du -sh "$R"/* 2>/dev/null | sort -rh | head -14
echo "=== /usr breakdown ==="
sudo du -sh "$R"/usr/* 2>/dev/null | sort -rh | head -12
echo "=== /usr/share breakdown ==="
sudo du -sh "$R"/usr/share/* 2>/dev/null | sort -rh | head -16
echo "=== /var breakdown ==="
sudo du -sh "$R"/var/* 2>/dev/null | sort -rh | head -8
echo "=== snaps ==="
sudo du -sh "$R"/snap "$R"/var/lib/snapd/snaps 2>/dev/null
echo "=== removable candidates ==="
for p in usr/share/doc usr/share/man usr/share/info usr/share/locale usr/share/icons usr/share/themes usr/lib/debug var/cache var/log usr/share/fonts usr/src usr/include; do
  s=$(sudo du -sh "$R/$p" 2>/dev/null | cut -f1)
  echo "$p ${s:-none}"
done
echo "=== single big files ==="
sudo find "$R" -type f -size +200M -printf '%s %p\n' 2>/dev/null | sort -rn | head -15