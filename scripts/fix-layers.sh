#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/fix-layers.log"

exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "unmount pseudo filesystems from tree"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then
    sudo umount -l "$R/$m" && echo "unmounted $m"
  fi
done
mount | grep -c "on $R/" || true

step "preflight"
test -d "$R" || { echo "FATAL: merged tree not mounted"; exit 1; }
test -s "$LAYERS/minimal.standard.squashfs" || { echo "FATAL: usr/lib layer missing"; exit 1; }
ls -la "$LAYERS"

step "top layer = usr/share plus everything except usr/lib"
rm -f "$LAYERS/minimal.standard.live.squashfs" "$LAYERS/minimal.standard.live.extra.squashfs"
cd "$R" || exit 1
ENTRIES=$(ls -A . | grep -v -E '^usr$' | tr '\n' ' ')
USRREST=$(ls -A usr | grep -v -E '^lib$' | sed 's|^|usr/|' | tr '\n' ' ')
echo "top-level: $ENTRIES"
echo "usr rest : $USRREST"
sudo mksquashfs usr/share $ENTRIES $USRREST "$LAYERS/minimal.standard.live.squashfs" \
  -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -5
cd "$W" || exit 1
if [ ! -s "$LAYERS/minimal.standard.live.squashfs" ]; then
  echo "FATAL: top layer not created"
  exit 1
fi
ls -la "$LAYERS"/*.squashfs
for f in "$LAYERS"/*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then
    echo "FATAL: $f is $s bytes, ISO9660 limit is 4 GiB"
    exit 1
  fi
  echo "size ok: $f $s"
done

step "update iso tree"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
ls -la "$TREE/casper" | head -8

SIZE=$(stat -c %s "$TREE/casper/minimal.standard.live.squashfs")
cat > "$TREE/casper/install-sources.yaml" <<EOF
version: 2
sources:
- default: true
  id: ubuntu-desktop
  variant: desktop
  type: fsimage-layered
  path: minimal.standard.live.squashfs
  size: $SIZE
  locale_support: langpack
  preinstalled_langs: []
  name:
    en: AncorOS Desktop
  description:
    en: AncorOS Desktop, GNOME 50, Wayland only, Angelcore look
  variations:
    standard:
      path: minimal.standard.live.squashfs
      size: $SIZE
kernel:
  default: linux-generic-hwe-24.04
EOF
head -10 "$TREE/casper/install-sources.yaml"
echo "top layer size recorded: $SIZE"

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
  "$TREE" 2>&1 | tail -10
if [ ! -s "$OUT" ]; then
  echo "FATAL: iso not created"
  exit 1
fi
ls -la "$OUT"

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -12

step "checksum"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "FIX-LAYERS-OK"