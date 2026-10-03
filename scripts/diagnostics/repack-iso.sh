#!/bin/bash
set -u
W=/home/builder/work
TREE="$W/isotree"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/repack-iso.log"

exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "push corrected files"
for f in user-data meta-data grub.cfg autoinstall.yaml; do
  test -f "/home/builder/$f" || { echo "missing $f"; exit 1; }
  cp -f "/home/builder/$f" "$TREE/$f" 2>/dev/null || true
  case "$f" in
    grub.cfg) cp -f "/home/builder/$f" "$TREE/boot/grub/grub.cfg" ;;
  esac
  echo "$f -> $(head -c 24 "$TREE/$f" | tr -d '\0' | od -An -tx1 | head -1)"
done
echo "--- grub.cfg first bytes ---"
head -c 16 "$TREE/boot/grub/grub.cfg" | od -An -tx1
echo "--- user-data first bytes ---"
head -c 16 "$TREE/user-data" | od -An -tx1

step "rebuild iso"
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
  "$TREE" 2>&1 | tail -12
if [ ! -s "$OUT" ]; then
  echo "FATAL: iso not created"
  exit 1
fi
ls -la "$OUT"

step "checksum"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "REPACK-ISO-OK"