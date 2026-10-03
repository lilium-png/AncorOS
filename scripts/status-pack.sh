#!/bin/bash
echo "=== processes ==="
ps -eo pid,etime,args | grep -E 'pack-iso|mksquashfs|xorriso|cp -a' | grep -v grep | head -6
SQ=$(pgrep -f 'mksquashfs /home/builder/work/mnt/merged' | tail -1)
if [ -n "$SQ" ]; then
  echo "=== mksquashfs progress ==="
  echo "read_bytes: $(awk '/read_bytes/{print $2}' /proc/$SQ/io 2>/dev/null) of about 15800000000"
  echo "rchar:      $(awk '/^rchar/{print $2}' /proc/$SQ/io 2>/dev/null)"
fi
echo "=== last steps ==="
grep '^############' /home/builder/work/pack-iso.log | tail -3
echo "=== log tail ==="
tail -4 /home/builder/work/pack-iso.log
echo "=== artifacts ==="
ls -la /home/builder/work/layers/ 2>/dev/null | tail -4
ls -la /home/builder/work/AncorOS-26.04-amd64.iso 2>/dev/null || echo "iso not built yet"
du -sh /home/builder/work/isotree 2>/dev/null || echo "isotree not ready"
echo "=== disk ==="
df -h /home/builder | tail -1