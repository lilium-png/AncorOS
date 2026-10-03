#!/bin/bash
set -u
W=/home/builder/work
TREE="$W/isotree"
L="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/build-iso.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "layers present"
ls -la "$L"/minimal*.squashfs
for f in minimal minimal.standard minimal.standard.live; do
  [ -s "$L/$f.squashfs" ] || { echo "FATAL missing $f.squashfs"; exit 1; }
done

step "isotree permissions"
sudo chown -R "$(id -un):$(id -gn)" "$TREE/casper"
sudo chmod -R u+w "$TREE/casper"
sudo chown "$(id -un):$(id -gn)" "$TREE/boot/grub/grub.cfg" 2>/dev/null || sudo chmod u+w "$TREE/boot/grub/grub.cfg"

step "install exactly three layers"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$L/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$L/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$L/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
ls -la "$TREE/casper"/*.squashfs
test -e "$TREE/casper/minimal.standard.live.extra.squashfs" && { echo "FATAL stray extra layer"; exit 1; }

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

step "grub.cfg state"
echo "bytes=$(stat -c %s "$TREE/boot/grub/grub.cfg") menuentries=$(grep -c '^menuentry' "$TREE/boot/grub/grub.cfg") layerfs-path=$(grep -c 'layerfs-path' "$TREE/boot/grub/grub.cfg" || true)"
grep 'vmlinuz' "$TREE/boot/grub/grub.cfg"

step "cloud-init files"
cp -f /home/builder/user-data "$TREE/user-data"
cp -f /home/builder/meta-data "$TREE/meta-data"
cp -f /home/builder/autoinstall.yaml "$TREE/autoinstall.yaml"

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
[ -s "$OUT" ] || { echo "FATAL iso not created"; exit 1; }
ls -la "$OUT"

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | grep -E 'El Torito (boot img|cat path)'

step "verify layers inside iso"
xorriso -indev "$OUT" -find /casper -maxdepth 1 2>/dev/null | grep squashfs

step "checksum"
sha256sum "$OUT" | sudo tee "$OUT.sha256"
echo "BUILD-ISO-OK"