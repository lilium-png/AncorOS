#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
EXPECT_BASE=3287158784
LOG="$W/fix-layers2.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "layers before"
sudo ls -la "$LAYERS"/

step "promote extra layer to minimal.squashfs"
sudo rm -f "$LAYERS/minimal.squashfs"
if sudo test -f "$LAYERS/minimal.standard.live.extra.squashfs"; then
  sudo mv "$LAYERS/minimal.standard.live.extra.squashfs" "$LAYERS/minimal.squashfs"
  echo "renamed"
else
  echo "extra layer missing, nothing to rename"
fi
sudo chown "$(id -un):$(id -gn)" "$LAYERS"/*.squashfs
sudo ls -la "$LAYERS"/

step "hard checks"
BASE=$(stat -c %s "$LAYERS/minimal.squashfs")
STD=$(stat -c %s "$LAYERS/minimal.standard.squashfs")
LIVE=$(stat -c %s "$LAYERS/minimal.standard.live.squashfs")
echo "base=$BASE standard=$STD live=$LIVE"
if [ "$BASE" -ne "$EXPECT_BASE" ]; then echo "FATAL base is $BASE, expected $EXPECT_BASE"; exit 1; fi
if [ "$STD" -ne 1621405696 ]; then echo "FATAL standard is $STD"; exit 1; fi
if [ "$LIVE" -ne 896565248 ]; then echo "FATAL live is $LIVE"; exit 1; fi
echo "all three layers verified"

step "drop leftover png background from theme"
sudo rm -f "$TREE/boot/grub/themes/Elegant-mountain-window-left-dark/background.png"

step "isotree casper permissions"
sudo chown -R "$(id -un):$(id -gn)" "$TREE/casper"
sudo chmod -R u+w "$TREE/casper"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
ls -la "$TREE/casper"/*.squashfs
echo "--- sanity ---"
test -e "$TREE/casper/minimal.standard.live.extra.squashfs" && { echo "FATAL extra still present"; exit 1; } || echo "extra absent, correct"
for f in minimal minimal.standard minimal.standard.live; do
  s=$(stat -c %s "$TREE/casper/$f.squashfs")
  echo "$f.squashfs = $s"
done

step "uncompressed size"
TOTAL=$(sudo du -sb "$R" 2>/dev/null | cut -f1)
echo "uncompressed: $TOTAL"
[ -n "$TOTAL" ] && [ "$TOTAL" -gt 0 ] || { echo "FATAL du failed"; exit 1; }

step "install-sources.yaml"
sudo tee "$TREE/casper/install-sources.yaml" > /dev/null <<EOF
version: 2
sources:
- default: true
  id: ancoros-desktop
  variant: desktop
  type: fsimage-layered
  path: minimal.standard.live.squashfs
  size: $TOTAL
  locale_support: langpack
  preinstalled_langs: []
  name:
    en: AncorOS Desktop
  description:
    en: AncorOS Desktop, GNOME 50, Wayland only, Angelcore look
  variations:
    standard:
      path: minimal.standard.live.squashfs
    live:
      path: minimal.standard.live.squashfs
kernel:
  default: linux-generic-hwe-24.04
EOF
head -8 "$TREE/casper/install-sources.yaml"

step "build iso"
sudo rm -f "$OUT"
xorriso -as mkisofs \
  -r -V "AncorOS 26.04.1 LTS amd64" -o "$OUT" \
  -J -joliet-long \
  --grub2-mbr "$W/mbr.bin" \
  --protective-msdos-label \
  -partition_cyl_align off -partition_offset 16 --mbr-force-bootable \
  -append_partition 2 0xef "$W/efi_part.img" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2_start_0s_size_10296d:all::' \
  -no-emul-boot -boot-load-size 10296 \
  "$TREE" 2>&1 | tail -4
ls -la "$OUT"

step "verify iso content"
sudo rm -rf /tmp/verify && mkdir -p /tmp/verify
sudo xorriso -osirrox on -indev "$OUT" -extract /casper /tmp/verify/casper 2>/dev/null
sudo xorriso -osirrox on -indev "$OUT" -extract /boot/grub/grub.cfg /tmp/verify/grub.cfg 2>/dev/null
sudo ls -la /tmp/verify/casper/*.squashfs
echo "--- grub.cfg ---"
sudo grep -c '^menuentry' /tmp/verify/grub.cfg
sudo grep -c 'layerfs-path' /tmp/verify/grub.cfg || echo "layerfs-path 0 correct"
sudo grep 'linux  /casper/vmlinuz' /tmp/verify/grub.cfg

step "checksum"
sha256sum "$OUT" | sudo tee "$OUT.sha256"
echo "FIX-LAYERS2-OK"