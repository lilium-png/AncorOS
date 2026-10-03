#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
LOG="$W/test-ef.log"
exec > >(tee -a "$LOG") 2>&1

echo "########## list from usr/bin, maxdepth 2 ##########"
cd "$R" || exit 1
sudo find usr/bin -xdev -mindepth 1 -maxdepth 2 > /tmp/t.list
echo "list lines: $(wc -l < /tmp/t.list)"
head -3 /tmp/t.list
sudo mksquashfs -ef /tmp/t.list /tmp/t.squashfs -noappend -no-progress -processors 2 2>&1 | tail -3
echo "--- archive top paths ---"
sudo unsquashfs -l /tmp/t.squashfs 2>/dev/null | head -8
echo "--- squashfs-root present? ---"
sudo unsquashfs -l /tmp/t.squashfs 2>/dev/null | grep -c 'squashfs-root'
echo "--- real files at usr/bin? ---"
sudo unsquashfs -l /tmp/t.squashfs 2>/dev/null | grep -c '^usr/bin/'
sudo unsquashfs -l /tmp/t.squashfs 2>/dev/null | grep -E 'usr/bin/(bash|mktemp|ls)$'

echo "########## symlink and special file survival ##########"
sudo find usr/bin -maxdepth 1 -xdev -type l | head -3 > /tmp/l.list
cat /tmp/t.list /tmp/l.list | sort -u > /tmp/t2.list
sudo mksquashfs -ef /tmp/t2.list /tmp/t2.squashfs -noappend -no-progress -processors 2 2>&1 | tail -2
sudo unsquashfs -l /tmp/t2.squashfs 2>/dev/null | grep -E '^l' | head -3
echo "total entries t2: $(sudo unsquashfs -l /tmp/t2.squashfs 2>/dev/null | wc -l)"

echo "TEST-EF-DONE"