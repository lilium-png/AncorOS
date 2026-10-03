#!/bin/bash
echo "=== pack-iso processes ==="
ps -eo pid,args | grep -E 'pack-iso|mksquashfs|xorriso' | grep -v grep | head -10
echo "=== mksquashfs error lines ==="
grep -n -i -m 8 -E 'unrecognised|invalid|unknown|not a valid' /home/builder/work/pack-iso.log
echo "=== first 40 lines after pack top layer ==="
awk '/pack top layer/{flag=1;next}/iso tree copy/{flag=0}flag' /home/builder/work/pack-iso.log | head -12
echo "=== mksquashfs xattrs help ==="
mksquashfs -help 2>&1 | grep -i -n "xattr" | head -12
echo "=== layers dir ==="
ls -la /home/builder/work/layers/ 2>&1 | head -8
echo "=== tree dir ==="
ls /home/builder/work/isotree 2>&1 | head -8