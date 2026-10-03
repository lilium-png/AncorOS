#!/bin/bash
set -u
LOG=/home/builder/work/sqtest2.log
exec > >(tee -a "$LOG") 2>&1

rm -rf /tmp/sq2 && mkdir -p /tmp/sq2/usr/lib/deep /tmp/sq2/usr/bin /tmp/sq2/etc
touch /tmp/sq2/usr/lib/deep/MARKER_LIB
touch /tmp/sq2/usr/bin/MARKER_BIN
touch /tmp/sq2/etc/MARKER_ETC
touch /tmp/sq2/MARKER_ROOT
mkdir -p /tmp/sq2/usr/lib/x && touch /tmp/sq2/usr/lib/x/f1

cd /tmp/sq2 || exit 1

echo "########## A: source dir usr/lib, no suppress ##########"
sudo mksquashfs usr/lib /tmp/sq2/A.squashfs -noappend -no-progress 2>&1 | tail -4
echo "A listing:"
sudo unsquashfs -l /tmp/sq2/A.squashfs 2>/dev/null | grep MARKER
sudo unsquashfs -l /tmp/sq2/A.squashfs 2>/dev/null | head -6

echo "########## B: multiple sources usr/lib + usr/bin + etc ##########"
sudo mksquashfs usr/lib usr/bin etc /tmp/sq2/B.squashfs -noappend -no-progress 2>&1 | tail -4
echo "B listing:"
sudo unsquashfs -l /tmp/sq2/B.squashfs 2>/dev/null | grep MARKER

echo "########## C: root source . with excludes ##########"
sudo mksquashfs . /tmp/sq2/C.squashfs -noappend -no-progress -e usr/bin 2>&1 | tail -4
echo "C listing:"
sudo unsquashfs -l /tmp/sq2/C.squashfs 2>/dev/null | grep MARKER

echo "########## D: prefix preserved by pseudo arg ##########"
sudo mksquashfs usr/lib /tmp/sq2/D.squashfs -noappend -no-progress -keep-as-directory usr/lib 2>&1 | tail -4
echo "D listing:"
sudo unsquashfs -l /tmp/sq2/D.squashfs 2>/dev/null | grep MARKER

echo "########## E: -keep-as-directory on plain dir ##########"
sudo mksquashfs usr/lib /tmp/sq2/E.squashfs -noappend -no-progress -keep-as-directory 2>&1 | tail -4
echo "E listing:"
sudo unsquashfs -l /tmp/sq2/E.squashfs 2>/dev/null | grep MARKER

echo "SQTEST2-DONE"