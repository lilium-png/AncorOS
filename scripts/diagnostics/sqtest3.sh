#!/bin/bash
set -u
LOG=/home/builder/work/sqtest3.log
exec > >(tee -a "$LOG") 2>&1

rm -rf /tmp/sq3 /tmp/out*.squashfs
mkdir -p /tmp/sq3/usr/lib/deep /tmp/sq3/usr/bin /tmp/sq3/etc
touch /tmp/sq3/usr/lib/deep/MARKER_LIB
touch /tmp/sq3/usr/bin/MARKER_BIN
touch /tmp/sq3/etc/MARKER_ETC
touch /tmp/sq3/MARKER_ROOT

echo "########## 1: relative source, dest outside cwd ##########"
cd /tmp/sq3 || exit 1
sudo mksquashfs usr/lib /tmp/out1.squashfs -noappend -no-progress > /dev/null 2>&1
sudo unsquashfs -l /tmp/out1.squashfs 2>/dev/null | grep MARKER

echo "########## 2: absolute source, dest outside ##########"
cd /tmp || exit 1
sudo mksquashfs /tmp/sq3/usr/lib /tmp/out2.squashfs -noappend -no-progress > /dev/null 2>&1
sudo unsquashfs -l /tmp/out2.squashfs 2>/dev/null | grep MARKER

echo "########## 3: tar source ##########"
cd /tmp/sq3 || exit 1
tar cf /tmp/src.tar usr/lib usr/bin etc
sudo mksquashfs /tmp/src.tar /tmp/out3.squashfs -noappend -no-progress 2>&1 | tail -2
sudo unsquashfs -l /tmp/out3.squashfs 2>/dev/null | grep MARKER

echo "########## 4: root source . with dest outside ##########"
sudo mksquashfs . /tmp/out4.squashfs -noappend -no-progress -e usr/bin > /dev/null 2>&1
sudo unsquashfs -l /tmp/out4.squashfs 2>/dev/null | grep MARKER

echo "########## 5: multiple dirs incl dot-prefixed names ##########"
sudo mksquashfs usr/lib usr/bin etc /tmp/out5.squashfs -noappend -no-progress > /dev/null 2>&1
sudo unsquashfs -l /tmp/out5.squashfs 2>/dev/null | grep MARKER

echo "SQTEST3-DONE"