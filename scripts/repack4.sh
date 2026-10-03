#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
L="$W/layers"
LOG="$W/repack4.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

build() {
  local dest="$1"; shift
  sudo mksquashfs . "$dest" \
    -noappend -no-progress -processors 6 \
    -comp zstd -Xcompression-level 15 -b 1M \
    -xattrs -xattrs-exclude '^trusted\.overlay\..*' \
    "$@"
}

step "unmount pseudo filesystems"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then sudo umount -l "$R/$m" && echo "unmounted $m"; fi
done

cd "$R" || exit 1

TOP=$(ls -A . | grep -v '^usr$' | tr '\n' ' ')
USR=$(ls -A usr | tr '\n' ' ')
echo "top level: $TOP"
echo "usr level: $USR"

EX_TOP=""
for t in $TOP; do EX_TOP="$EX_TOP -e $t"; done
EX_PSEUDO="-e proc/* -e sys/* -e dev/* -e run/* -e tmp/* -e mnt/* -e media/*"

EX_STD="$EX_TOP"
for u in $USR; do
  if [ "$u" != "lib" ]; then EX_STD="$EX_STD -e usr/$u"; fi
done
EX_LIVE="$EX_TOP"
for u in $USR; do
  if [ "$u" != "share" ]; then EX_LIVE="$EX_LIVE -e usr/$u"; fi
done

step "layer 1: base, everything except usr/lib and usr/share"
sudo rm -f "$L/minimal.squashfs"
build "$L/minimal.squashfs" -e usr/lib -e usr/share $EX_PSEUDO 2>&1 | tail -4
[ -s "$L/minimal.squashfs" ] || { echo "FATAL base layer not created"; exit 1; }
stat -c '%s %n' "$L/minimal.squashfs"

step "layer 2: usr/lib only"
sudo rm -f "$L/minimal.standard.squashfs"
build "$L/minimal.standard.squashfs" $EX_STD $EX_PSEUDO 2>&1 | tail -4
[ -s "$L/minimal.standard.squashfs" ] || { echo "FATAL standard layer not created"; exit 1; }
stat -c '%s %n' "$L/minimal.standard.squashfs"

step "layer 3: usr/share only"
sudo rm -f "$L/minimal.standard.live.squashfs"
build "$L/minimal.standard.live.squashfs" $EX_LIVE $EX_PSEUDO 2>&1 | tail -4
[ -s "$L/minimal.standard.live.squashfs" ] || { echo "FATAL live layer not created"; exit 1; }
stat -c '%s %n' "$L/minimal.standard.live.squashfs"

step "size guard"
for f in "$L"/minimal*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then echo "FATAL $(basename "$f") = $s exceeds 4 GiB"; exit 1; fi
  echo "ok $(basename "$f") = $s"
done

step "verify structure"
fail=0
for f in minimal minimal.standard minimal.standard.live; do
  echo "===== $f ====="
  sudo unsquashfs -ll "$L/$f.squashfs" 2>/dev/null > /tmp/v.txt
  n=$(wc -l < /tmp/v.txt)
  lib=$(grep -c 'squashfs-root/usr/lib/' /tmp/v.txt)
  bin=$(grep -c 'squashfs-root/usr/bin/' /tmp/v.txt)
  shr=$(grep -c 'squashfs-root/usr/share/' /tmp/v.txt)
  etc=$(grep -c 'squashfs-root/etc/' /tmp/v.txt)
  b1=$(grep -c '/bin_1/' /tmp/v.txt)
  echo "entries=$n usr/lib=$lib usr/bin=$bin usr/share=$shr etc=$etc bin_1=$b1"
  echo "systemd=$(grep -c 'squashfs-root/usr/lib/systemd/systemd$' /tmp/v.txt) bash=$(grep -c 'squashfs-root/usr/bin/bash$' /tmp/v.txt) gnome-shell=$(grep -c 'squashfs-root/usr/share/gnome-shell$' /tmp/v.txt)"
  echo "WhiteSur=$(grep -c 'WhiteSur' /tmp/v.txt) firstboot=$(grep -c 'ancoros-firstboot' /tmp/v.txt) whitelabel=$(grep -c 'whitelabel.yaml' /tmp/v.txt)"
  [ "$b1" -eq 0 ] || { echo "FATAL bin_1 collision in $f"; fail=1; }
  [ "$n" -gt 0 ] || { echo "FATAL empty $f"; fail=1; }
  sudo rm -f /tmp/v.txt
done

step "hard requirements"
sudo unsquashfs -ll "$L/minimal.squashfs" 2>/dev/null > /tmp/b.txt
sudo unsquashfs -ll "$L/minimal.standard.squashfs" 2>/dev/null > /tmp/s.txt
sudo unsquashfs -ll "$L/minimal.standard.live.squashfs" 2>/dev/null > /tmp/l.txt
need_base='squashfs-root/usr/bin/bash'
need_lib='squashfs-root/usr/lib/systemd/systemd'
need_live='squashfs-root/usr/share/gnome-shell'
grep -q "$need_base" /tmp/b.txt || { echo "FATAL no bash in base"; fail=1; }
grep -q "$need_lib"  /tmp/s.txt || { echo "FATAL no systemd in standard layer"; fail=1; }
grep -q "$need_live" /tmp/l.txt || { echo "FATAL no gnome-shell in live layer"; fail=1; }
grep -q 'WhiteSur'         /tmp/l.txt || { echo "FATAL no WhiteSur in live layer"; fail=1; }
grep -q 'whitelabel.yaml'  /tmp/b.txt || { echo "FATAL no whitelabel in base"; fail=1; }
grep -q 'ancoros-firstboot' /tmp/b.txt || { echo "FATAL no firstboot script in base"; fail=1; }
sudo rm -f /tmp/b.txt /tmp/s.txt /tmp/l.txt
if [ "$fail" -ne 0 ]; then echo "VERIFICATION FAILED"; exit 1; fi
echo "REPACK4-OK"