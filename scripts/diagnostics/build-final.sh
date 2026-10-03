#!/bin/bash
set -u
W=/home/builder/work
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/build-final.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "layers"
ls -la "$LAYERS"/*.squashfs
test -e "$LAYERS/minimal.standard.live.extra.squashfs" && { echo "FATAL extra layer still present"; exit 1; }

step "isotree layers"
sudo chown -R "$(id -un):$(id -gn)" "$TREE/casper"
sudo chmod -R u+w "$TREE/casper"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
ls -la "$TREE/casper"/*.squashfs

step "grub.cfg"
sudo chown "$(id -un):$(id -gn)" "$TREE/boot/grub/grub.cfg" 2>/dev/null || sudo chmod u+w "$TREE/boot/grub/grub.cfg"
echo "bytes: $(stat -c %s "$TREE/boot/grub/grub.cfg")  menuentries: $(grep -c '^menuentry' "$TREE/boot/grub/grub.cfg")  layerfs-path: $(grep -c 'layerfs-path' "$TREE/boot/grub/grub.cfg" || true)"

step "install-sources.yaml"
sudo tee "$TREE/casper/install-sources.yaml" > /dev/null <<'EOF'
version: 2
sources:
- default: true
  id: ancoros-desktop
  variant: desktop
  type: fsimage-layered
  path: minimal.standard.live.squashfs
  size: 11811160064
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

step "verify extracted from iso"
sudo rm -rf /tmp/verify && mkdir -p /tmp/verify
sudo xorriso -osirrox on -indev "$OUT" -extract /casper /tmp/verify/casper 2>/dev/null
sudo xorriso -osirrox on -indev "$OUT" -extract /boot/grub/grub.cfg /tmp/verify/grub.cfg 2>/dev/null
sudo xorriso -osirrox on -indev "$OUT" -extract /casper/install-sources.yaml /tmp/verify/install-sources.yaml 2>/dev/null
sudo ls -la /tmp/verify/casper/*.squashfs
echo "--- grub ---"
sudo grep -c '^menuentry' /tmp/verify/grub.cfg
sudo grep -c 'layerfs-path' /tmp/verify/grub.cfg || echo "layerfs-path absent, correct"
sudo grep 'vmlinuz' /tmp/verify/grub.cfg
echo "--- sources ---"
sudo grep -E 'path:|size:' /tmp/verify/install-sources.yaml

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | grep -E 'El Torito (boot img|cat path)'

step "checksum"
sha256sum "$OUT" | sudo tee "$OUT.sha256"
echo "BUILD-FINAL-OK"