#!/bin/bash
set -u
LOG=/home/builder/work/layerfs3.log
exec > >(tee -a "$LOG") 2>&1

rm -rf /tmp/irx
mkdir -p /tmp/irx
cd /tmp/irx || exit 1
lsinitramfs /tmp/initrd/initrd > /dev/null 2>&1
echo "extracted files: $(find . -type f | wc -l)"
echo "=== files mentioning LAYERFS_PATH ==="
grep -rl "LAYERFS_PATH" . 2>/dev/null | head -10
echo
for f in $(grep -rl "LAYERFS_PATH" . 2>/dev/null | head -5); do
  echo "############ $f ############"
  grep -n -B6 -A25 "LAYERFS_PATH" "$f" | head -80
  echo
done
echo "=== files mentioning squashfs mount ==="
grep -rlE "lowerdir|squashfs" . 2>/dev/null | head -10
echo "LAYERFS3-DONE"