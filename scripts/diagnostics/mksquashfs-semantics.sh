#!/bin/bash
set -u
LOG=/home/builder/work/mksquashfs-semantics.log
exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*"; }

step "mksquashfs version and help on pseudo files"
mksquashfs -version 2>&1 | head -3
mksquashfs -help 2>&1 | grep -iE 'pseudo|root-becomes|-ef|-e ' | head -12

step "test A: mksquashfs usr/lib from parent"
rm -rf /tmp/sqt && mkdir -p /tmp/sqt/usr/lib/deep
touch /tmp/sqt/usr/lib/deep/MARKER_A
touch /tmp/sqt/ROOTLEVEL_MARKER
cd /tmp/sqt || exit 1
sudo mksquashfs usr/lib /tmp/sqt/A.squashfs -noappend -no-progress >/dev/null 2>&1
echo "A contents:"
sudo unsquashfs -l /tmp/sqt/A.squashfs 2>/dev/null | grep -E 'MARKER'

step "test B: mksquashfs . with -e usr/share"
sudo mksquashfs . /tmp/sqt/B.squashfs -noappend -no-progress -e usr/share >/dev/null 2>&1
echo "B contents:"
sudo unsquashfs -l /tmp/sqt/B.squashfs 2>/dev/null | grep -E 'MARKER'

step "test C: pseudo file preserves prefix"
sudo mksquashfs usr/lib /tmp/sqt/C.squashfs -noappend -no-progress usr/lib >/dev/null 2>&1
echo "C contents:"
sudo unsquashfs -l /tmp/sqt/C.squashfs 2>/dev/null | grep -E 'MARKER'

step "test D: file list with -ef"
( cd /tmp/sqt && find usr/lib | sed 's|^|./|' > /tmp/sqt/list.txt )
sudo mksquashfs -ef /tmp/sqt/list.txt /tmp/sqt/D.squashfs -noappend -no-progress >/dev/null 2>&1
echo "D contents:"
sudo unsquashfs -l /tmp/sqt/D.squashfs 2>/dev/null | grep -E 'MARKER'

step "test E: run from parent with explicit relative path"
cd /tmp || exit 1
sudo mksquashfs sqt/usr/lib /tmp/sqt/E.squashfs -noappend -no-progress >/dev/null 2>&1
echo "E contents:"
sudo unsquashfs -l /tmp/sqt/E.squashfs 2>/dev/null | grep -E 'MARKER'

step "original ubuntu minimal.squashfs layout"
lsblk -o NAME,MOUNTPOINT,LABEL | head -10
MOUNT=$(lsblk -o NAME | grep -E 'sr0' | head -1)
if [ -n "$MOUNT" ]; then
  sudo mkdir -p /tmp/ubiso
  sudo mount -o ro,loop "/dev/$MOUNT" /tmp/ubiso 2>&1
  ls -la /tmp/ubiso/casper/minimal.squashfs 2>&1
  echo "--- top level dirs in original minimal.squashfs ---"
  sudo unsquashfs -ll /tmp/ubiso/casper/minimal.squashfs 2>/dev/null > /tmp/orig-list.txt
  echo "entries: $(wc -l < /tmp/orig-list.txt)"
  awk -F/ 'NF>1{print $1}' /tmp/orig-list.txt | sort -u | head -40
  echo "--- probes ---"
  for p in usr/bin/mktemp usr/sbin/debconf-communicate usr/lib/systemd/systemd usr/share/gnome-shell sbin/init; do
    echo "$p -> $(grep -c "/$p\$" /tmp/orig-list.txt)"
  done
  sudo umount /tmp/ubiso
fi
echo "MKSQ-SEMANTICS-DONE"