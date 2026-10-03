#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/fix-casper.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "layers on disk"
ls -la "$LAYERS"/*.squashfs

step "fix isotree casper permissions"
sudo chown -R "$(id -un):$(id -gn)" "$TREE/casper"
sudo chmod -R u+w "$TREE/casper"
ls -la "$TREE/casper" | head -12

step "remove every squashfs in tree"
rm -f "$TREE"/casper/minimal*.squashfs
ls -la "$TREE/casper"/*.squashfs 2>&1 | head -4

step "install three layers"
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
echo "--- tree layers now ---"
ls -la "$TREE/casper"/*.squashfs
echo "--- extra layer must be absent ---"
test -e "$TREE/casper/minimal.standard.live.extra.squashfs" && echo "STILL PRESENT" || echo "absent, correct"

step "real uncompressed size"
TOTAL=$(sudo du -sb --exclude=proc --exclude=sys --exclude=dev --exclude=run "$R" 2>/dev/null | cut -f1)
echo "uncompressed bytes: $TOTAL"
BASE=$(stat -c %s "$LAYERS/minimal.squashfs")
STD=$(stat -c %s "$LAYERS/minimal.standard.squashfs")
LIVE=$(stat -c %s "$LAYERS/minimal.standard.live.squashfs")
echo "compressed: base=$BASE standard=$STD live=$LIVE"

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
cat "$TREE/casper/install-sources.yaml"

step "build iso"
sudo rm -f "$OUT"
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
  "$TREE" 2>&1 | tail -4
ls -la "$OUT"

step "layers inside iso with sizes"
xorriso -indev "$OUT" -find /casper -maxdepth 1 2>/dev/null | grep squashfs
sudo rm -rf /tmp/isomnt && mkdir -p /tmp/isomnt
sudo xorriso -osirrox on -indev "$OUT" -extract /casper /tmp/isomnt/casper 2>/dev/null
ls -la /tmp/isomnt/casper/*.squashfs 2>/dev/null

step "grub.cfg inside iso"
sudo cat /tmp/isomnt/boot/grub/grub.cfg 2>/dev/null | head -5 || true
sudo xorriso -osirrox on -indev "$OUT" -extract /boot/grub/grub.cfg /tmp/isomnt/grub.cfg 2>/dev/null
echo "grub.cfg bytes: $(stat -c %s /tmp/isomnt/grub.cfg)"
grep -c 'layerfs-path' /tmp/isomnt/grub.cfg || echo "layerfs-path: 0, correct"
grep -c '^menuentry' /tmp/isomnt/grub.cfg

step "theme inside iso"
sudo xorriso -osirrox on -indev "$OUT" -extract /boot/grub/themes /tmp/isomnt/themes 2>/dev/null
sudo ls -la /tmp/isomnt/themes/*/ | head -12
sudo cat /tmp/isomnt/themes/*/theme.txt | head -4

step "checksum"
sha256sum "$OUT" | sudo tee "$OUT.sha256"
echo "FIX-CASPER-OK"