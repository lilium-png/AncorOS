#!/bin/bash
set -u
W=/home/builder/work
TREE="$W/isotree"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/rebuild-iso2.log"
exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "fix isotree root permissions"
sudo chown "$(id -un):$(id -gn)" "$TREE"/*.yaml "$TREE"/user-data "$TREE"/meta-data 2>/dev/null
sudo chmod u+w "$TREE"/*.yaml "$TREE"/user-data "$TREE"/meta-data 2>/dev/null
ls -la "$TREE" | head -12

step "copy cloud-init files"
for f in user-data meta-data autoinstall.yaml; do
  rm -f "$TREE/$f"
  cp -f "/home/builder/$f" "$TREE/$f" || { echo "FATAL cannot copy $f"; exit 1; }
  echo "$f: $(stat -c %s "$TREE/$f") bytes, head: $(head -c 20 "$TREE/$f" | tr '\n' ' ')"
done

step "verify grub.cfg has serial console and no layerfs-path"
echo "bytes=$(stat -c %s "$TREE/boot/grub/grub.cfg") menuentries=$(grep -c '^menuentry' "$TREE/boot/grub/grub.cfg") layerfs-path=$(grep -c 'layerfs-path' "$TREE/boot/grub/grub.cfg" || true)"

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
  "$TREE" 2>&1 | tail -3
[ -s "$OUT" ] || { echo "FATAL iso not created"; exit 1; }
ls -la "$OUT"

step "extract and verify from iso"
sudo rm -rf /tmp/v && mkdir -p /tmp/v
sudo xorriso -osirrox on -indev "$OUT" -extract /casper/install-sources.yaml /tmp/v/install-sources.yaml 2>/dev/null
sudo xorriso -osirrox on -indev "$OUT" -extract /boot/grub/grub.cfg /tmp/v/grub.cfg 2>/dev/null
sudo xorriso -osirrox on -indev "$OUT" -extract /user-data /tmp/v/user-data 2>/dev/null
sudo xorriso -osirrox on -indev "$OUT" -extract /meta-data /tmp/v/meta-data 2>/dev/null
echo "install-sources path:"; sudo grep -E 'path:' /tmp/v/install-sources.yaml
echo "grub menuentries: $(sudo grep -c '^menuentry' /tmp/v/grub.cfg)  layerfs-path: $(sudo grep -c 'layerfs-path' /tmp/v/grub.cfg || true)"
echo "user-data bytes: $(stat -c %s /tmp/v/user-data)"
echo "meta-data bytes: $(stat -c %s /tmp/v/meta-data)"

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | grep -E 'El Torito boot img'

step "checksum"
sha256sum "$OUT" | sudo tee "$OUT.sha256"
echo "REBUILD-ISO2-OK"