#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
L="$W/layers"
LOG="$W/repack3.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "unmount pseudo filesystems"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then sudo umount -l "$R/$m" && echo "unmounted $m"; fi
done

cd "$R" || exit 1

TOP=$(ls -A . | grep -v '^usr$' | tr '\n' ' ')
echo "top level: $TOP"
USR=$(ls -A usr | tr '\n' ' ')
echo "usr level: $USR"

EX_TOP=""
for t in $TOP; do EX_TOP="$EX_TOP -e $t"; done
EX_PSEUDO=" -e proc/* -e sys/* -e dev/* -e run/* -e tmp/* -e mnt/* -e media/*"
SQ="sudo mksquashfs . -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M -xattrs -xattrs-exclude ^trusted\\.overlay\\..*"

step "layer 1: base, everything except usr/lib and usr/share"
sudo rm -f "$L/minimal.squashfs"
eval "$SQ $L/minimal.squashfs -e usr/lib -e usr/share $EX_PSEUDO" 2>&1 | tail -3
stat -c '%s %n' "$L/minimal.squashfs"

step "layer 2: usr/lib only"
sudo rm -f "$L/minimal.standard.squashfs"
EX_STD="$EX_TOP"
for u in $USR; do
  if [ "$u" != "lib" ]; then EX_STD="$EX_STD -e usr/$u"; fi
done
eval "$SQ $L/minimal.standard.squashfs $EX_STD $EX_PSEUDO" 2>&1 | tail -3
stat -c '%s %n' "$L/minimal.standard.squashfs"

step "layer 3: usr/share only"
sudo rm -f "$L/minimal.standard.live.squashfs"
EX_LIVE="$EX_TOP"
for u in $USR; do
  if [ "$u" != "share" ]; then EX_LIVE="$EX_LIVE -e usr/$u"; fi
done
eval "$SQ $L/minimal.standard.live.squashfs $EX_LIVE $EX_PSEUDO" 2>&1 | tail -3
stat -c '%s %n' "$L/minimal.standard.live.squashfs"

step "size guard"
for f in "$L"/minimal*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then echo "FATAL $f = $s"; exit 1; fi
  echo "ok $(basename "$f") = $s"
done

step "verify structure"
for f in minimal minimal.standard minimal.standard.live; do
  echo "===== $f ====="
  sudo unsquashfs -ll "$L/$f.squashfs" 2>/dev/null > /tmp/v-$f.txt
  echo "entries: $(wc -l < /tmp/v-$f.txt)"
  echo "usr/lib:  $(grep -c 'squashfs-root/usr/lib/'  /tmp/v-$f.txt)"
  echo "usr/bin:  $(grep -c 'squashfs-root/usr/bin/'  /tmp/v-$f.txt)"
  echo "usr/share:$(grep -c 'squashfs-root/usr/share/' /tmp/v-$f.txt)"
  echo "etc:      $(grep -c 'squashfs-root/etc/'      /tmp/v-$f.txt)"
  echo "var:      $(grep -c 'squashfs-root/var/'      /tmp/v-$f.txt)"
  echo "systemd:  $(grep -c 'squashfs-root/usr/lib/systemd/systemd$' /tmp/v-$f.txt)"
  echo "bash:     $(grep -c 'squashfs-root/usr/bin/bash$'        /tmp/v-$f.txt)"
  echo "bin_1:    $(grep -c '/bin_1/'                          /tmp/v-$f.txt)"
  echo "WhiteSur: $(grep -c 'WhiteSur'                          /tmp/v-$f.txt)"
  sudo rm -f /tmp/v-$f.txt
done
echo "REPACK3-DONE"