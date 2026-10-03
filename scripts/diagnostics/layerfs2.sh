#!/bin/bash
set -u
LOG=/home/builder/work/layerfs2.log
exec > >(tee -a "$LOG") 2>&1

lsinitramfs /tmp/initrd/initrd > /tmp/initrd.list 2>/dev/null
echo "total entries: $(wc -l < /tmp/initrd.list)"
echo "=== casper-bottom scripts ==="
grep "casper-bottom" /tmp/initrd.list
echo "=== anything with layer ==="
grep -i "layer" /tmp/initrd.list
echo "=== extract and read layerfs script ==="
for f in $(grep -i "layerfs" /tmp/initrd.list); do
  echo "----- $f -----"
  lsinitramfs /tmp/initrd/initrd "$f" 2>/dev/null | head -60
done
echo "=== grep LAYERFS_PATH in all casper scripts ==="
mkdir -p /tmp/casper
cd /tmp/casper || exit 1
for f in $(grep "casper-bottom" /tmp/initrd.list | head -40); do
  lsinitramfs /tmp/initrd/initrd "$f" > /tmp/casper/out.txt 2>/dev/null
  if grep -qi "LAYERFS_PATH" /tmp/casper/out.txt 2>/dev/null; then
    echo "### $f"
    grep -n -i -B3 -A12 "LAYERFS_PATH" /tmp/casper/out.txt | head -40
  fi
done
echo "LAYERFS2-DONE"