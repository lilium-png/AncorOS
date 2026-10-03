#!/bin/bash
set -u
R=/home/builder/work/mnt/merged
LOG=/home/builder/work/sqtest4.log
exec > >(tee -a "$LOG") 2>&1

rm -f /tmp/m1.squashfs /tmp/m2.squashfs /tmp/m3.squashfs
cd "$R" || exit 1

echo "########## M1: multiple explicit sources including usr/lib ##########"
sudo mksquashfs etc boot usr/lib /tmp/m1.squashfs -noappend -no-progress -processors 2 >/dev/null 2>&1
echo "root entries:"
sudo unsquashfs -l /tmp/m1.squashfs 2>/dev/null | awk '{print $NF}' | grep -v '^$' | head -8
echo "wrapper count: $(sudo unsquashfs -l /tmp/m1.squashfs 2>/dev/null | grep -c squashfs-root)"
echo "usr/lib entries: $(sudo unsquashfs -l /tmp/m1.squashfs 2>/dev/null | grep -c '^usr/lib/')"
echo "plain lib entries: $(sudo unsquashfs -l /tmp/m1.squashfs 2>/dev/null | grep -c '^lib/')"
echo "etc/passwd present: $(sudo unsquashfs -l /tmp/m1.squashfs 2>/dev/null | grep -c 'etc/passwd')"

echo "########## M2: original ubuntu layer wrapper check ##########"
if sudo test -f /tmp/ubiso/casper/minimal.standard.squashfs; then
  echo "wrapper count in ubuntu layer: $(sudo unsquashfs -l /tmp/ubiso/casper/minimal.standard.squashfs 2>/dev/null | grep -c squashfs-root)"
  echo "usr/lib entries: $(sudo unsquashfs -l /tmp/ubiso/casper/minimal.standard.squashfs 2>/dev/null | grep -c '^usr/lib/')"
  echo "root sample:"
  sudo unsquashfs -l /tmp/ubiso/casper/minimal.standard.squashfs 2>/dev/null | awk '{print $NF}' | grep -v '^$' | head -5
else
  echo "ubuntu iso not mounted"
fi

echo "########## M3: collision behaviour ##########"
sudo mksquashfs usr/bin bin /tmp/m3.squashfs -noappend -no-progress -processors 2 >/dev/null 2>&1
echo "entries named bin*:"
sudo unsquashfs -l /tmp/m3.squashfs 2>/dev/null | awk '{print $NF}' | grep -E '^(usr/)?bin' | head -6
echo "M4TEST-DONE"