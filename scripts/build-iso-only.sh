#!/bin/bash
set -u
W=/home/builder/work
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
ORIG="$W/original.iso"
LOG="$W/build-iso.log"

exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "preflight"
test -s "$LAYERS/minimal.standard.live.squashfs" || { echo "FATAL: top layer missing"; exit 1; }
test -d "$TREE/casper" || { echo "FATAL: iso tree missing"; exit 1; }
ls -la "$TREE/casper/minimal.standard.live.squashfs" "$TREE/user-data" "$TREE/autoinstall.yaml" "$TREE/meta-data" 2>&1 | head -6
head -3 "$TREE/boot/grub/grub.cfg"

step "extract boot structures from source iso"
sudo dd if="$ORIG" of="$W/mbr.bin" bs=512 count=16 status=none
sudo dd if="$ORIG" of="$W/efi_part.img" bs=512 skip=12649996 count=10296 status=none
ls -la "$W/mbr.bin" "$W/efi_part.img"
sudo chown builder:builder "$W/mbr.bin" "$W/efi_part.img"

step "build iso"
rm -f "$OUT"
xorriso -as mkisofs \
  -r \
  -V "AncorOS 26.04.1 LTS amd64" \
  -o "$OUT" \
  -J -joliet-long \
  --grub2-mbr "$W/mbr.bin" \
  --protective-msdos-label \
  -partition_cyl_align off \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 0xef "$W/efi_part.img" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2_start_0s_size_10296d:all::' \
  -no-emul-boot -boot-load-size 10296 \
  "$TREE" 2>&1 | tail -20
if [ ! -s "$OUT" ]; then
  echo "FATAL: iso not created"
  exit 1
fi
ls -la "$OUT"

step "el torito report"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -20

step "checksum"
sha256sum "$OUT" | tee "$OUT.sha256"

step "done"
du -h "$OUT"
df -h /home/builder | tail -1
echo "BUILD-ISO-OK"