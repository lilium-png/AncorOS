#!/bin/bash
sed -n '35,60p' /tmp/ha.txt
echo "-----"
sed -n '205,215p' /tmp/ha.txt
echo "===== TEST keep-as-directory with source . ====="
cd /tmp/sq3 || exit 1
sudo mksquashfs . /tmp/k1.squashfs -noappend -no-progress -keep-as-directory >/dev/null 2>&1
sudo unsquashfs -l /tmp/k1.squashfs 2>/dev/null | grep MARKER
echo "===== TEST parent as source: usr ====="
sudo mksquashfs usr /tmp/k2.squashfs -noappend -no-progress >/dev/null 2>&1
sudo unsquashfs -l /tmp/k2.squashfs 2>/dev/null | grep MARKER
echo "===== TEST with -root-becomes ====="
sudo mksquashfs . /tmp/k3.squashfs -noappend -no-progress -root-becomes '' >/dev/null 2>&1
sudo unsquashfs -l /tmp/k3.squashfs 2>/dev/null | grep MARKER
echo "KTEST-DONE"