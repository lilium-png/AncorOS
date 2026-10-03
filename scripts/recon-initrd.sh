#!/bin/bash
set -u
W=/home/builder/work
rm -rf "$W/initrd"
mkdir -p "$W/initrd"
cd "$W/initrd"
if lsinitramfs -x /mnt/iso/casper/initrd "$W/initrd" > "$W/lsinitramfs.log" 2>&1; then
  echo "extracted via lsinitramfs -x"
elif zstd -dc /mnt/iso/casper/initrd 2>/dev/null | cpio -idmu --quiet 2>/dev/null; then
  echo "extracted via zstd+cpio"
elif gzip -dc /mnt/iso/casper/initrd 2>/dev/null | cpio -idmu --quiet 2>/dev/null; then
  echo "extracted via gzip+cpio"
elif cat /mnt/iso/casper/initrd | cpio -idmu --quiet 2>/dev/null; then
  echo "extracted via raw cpio"
else
  echo "ALL EXTRACTION FAILED"
fi
echo "=== top level ==="
ls "$W/initrd"
echo "=== casper.conf ==="
cat "$W/initrd/etc/casper.conf" 2>/dev/null
echo "=== default-layer.conf ==="
cat "$W/initrd/conf/conf.d/default-layer.conf" 2>/dev/null
echo "=== casperize.conf ==="
cat "$W/initrd/conf/conf.d/casperize.conf" 2>/dev/null
echo "=== grep layer in scripts ==="
grep -rn --binary-files=without-match -i 'layer' "$W/initrd/scripts" 2>/dev/null | head -30
echo "=== done ==="