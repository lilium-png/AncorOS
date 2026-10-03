#!/bin/bash
set -u
W=/home/builder/work/initrd
echo "=== scripts/casper lines 40-130 ==="
sed -n '40,130p' "$W/scripts/casper"
echo
echo "=== scripts/casper lines 585,680 ==="
sed -n '585,680p' "$W/scripts/casper"
echo
echo "=== scripts/casper-premount/20iso_scan ==="
cat "$W/scripts/casper-premount/20iso_scan" 2>/dev/null | head -60
echo "=== done ==="