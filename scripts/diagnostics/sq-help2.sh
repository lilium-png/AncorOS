#!/bin/bash
mksquashfs -help-section pseudo > /tmp/hp.txt 2>&1
echo "=== pseudo section ==="
cat /tmp/hp.txt
echo "=== pseudo-defs section ==="
mksquashfs -help-section pseudo-defs > /tmp/hpd.txt 2>&1
cat /tmp/hpd.txt
echo "=== help-all grep squashfs-root / root-becomes ==="
mksquashfs -help-all > /tmp/ha.txt 2>&1
grep -in "squashfs-root" /tmp/ha.txt | head -10
grep -in "root-becomes" /tmp/ha.txt | head -10
grep -in "keep-as-directory" /tmp/ha.txt | head -5
echo "=== build section (list related) ==="
grep -in "list" /tmp/ha.txt | head -20
echo "HELPALL-DONE"