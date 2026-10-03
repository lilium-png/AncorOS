#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/pack-final.log"

exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "unmount pseudo filesystems"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then
    sudo umount -l "$R/$m" && echo "unmounted $m"
  fi
done

step "layer sizes of source"
sudo du -sh "$R/usr/lib" "$R/usr/share" "$R/var" "$R/opt" 2>/dev/null

step "layer 2: usr/lib"
rm -f "$LAYERS/minimal.standard.squashfs"
cd "$R" || exit 1
sudo mksquashfs usr/lib "$LAYERS/minimal.standard.squashfs" \
  -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -3

step "layer 3: usr/share"
rm -f "$LAYERS/minimal.standard.live.squashfs"
sudo mksquashfs usr/share "$LAYERS/minimal.standard.live.squashfs" \
  -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -3

step "layer 4: everything except usr/lib and usr/share"
rm -f "$LAYERS/minimal.standard.live.extra.squashfs"
ENTRIES=$(ls -A . | grep -v -E '^usr$' | tr '\n' ' ')
USRREST=$(ls -A usr | grep -v -E '^(lib|share)$' | sed 's|^|usr/|' | tr '\n' ' ')
echo "top-level: $ENTRIES"
echo "usr rest: $USRREST"
sudo mksquashfs $ENTRIES $USRREST "$LAYERS/minimal.standard.live.extra.squashfs" \
  -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -3
cd "$W" || exit 1

step "layer size check"
ls -la "$LAYERS"/*.squashfs
ok=1
for f in "$LAYERS"/*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then
    echo "FATAL: $f is $s bytes, ISO9660 limit is 4 GiB"
    ok=0
  else
    echo "size ok: $(basename "$f") $s"
  fi
done
[ "$ok" -eq 1 ] || exit 1

step "iso tree"
test -d "$TREE/casper" || { echo "FATAL: iso tree missing"; exit 1; }
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
cp "$LAYERS/minimal.standard.live.extra.squashfs" "$TREE/casper/minimal.standard.live.extra.squashfs"
ls -la "$TREE/casper" | head -8

SIZE=$(stat -c %s "$TREE/casper/minimal.standard.live.extra.squashfs")
cat > "$TREE/casper/install-sources.yaml" <<EOF
version: 2
sources:
- default: true
  id: ubuntu-desktop
  variant: desktop
  type: fsimage-layered
  path: minimal.standard.live.extra.squashfs
  size: $SIZE
  locale_support: langpack
  preinstalled_langs: []
  name:
    en: AncorOS Desktop
  description:
    en: AncorOS Desktop, GNOME 50, Wayland only, Angelcore look
  variations:
    standard:
      path: minimal.standard.live.extra.squashfs
      size: $SIZE
kernel:
  default: linux-generic-hwe-24.04
EOF
head -9 "$TREE/casper/install-sources.yaml"

step "grub with layerfs-path"
cat > "$TREE/boot/grub/grub.cfg" <<'CFG'
set timeout=30

loadfont unicode

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Install AncorOS (automatic)" {
    set gfxpayload=keep
    linux  /casper/vmlinuz autoinstall layerfs-path=minimal.standard.live.extra.squashfs --- quiet splash
    initrd /casper/initrd
}
menuentry "Try AncorOS" {
    set gfxpayload=keep
    linux  /casper/vmlinuz layerfs-path=minimal.standard.live.extra.squashfs --- quiet splash
    initrd /casper/initrd
}
menuentry "AncorOS (safe graphics)" {
    set gfxpayload=keep
    linux  /casper/vmlinuz layerfs-path=minimal.standard.live.extra.squashfs nomodeset --- quiet splash
    initrd /casper/initrd
}
grub_platform
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
    exit 1
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
fi
CFG
head -8 "$TREE/boot/grub/grub.cfg"

step "cloud-init files"
cp -f /home/builder/user-data "$TREE/user-data"
cp -f /home/builder/meta-data "$TREE/meta-data"
cp -f /home/builder/autoinstall.yaml "$TREE/autoinstall.yaml"
for f in user-data meta-data autoinstall.yaml; do
  echo "$f first bytes: $(head -c 12 "$TREE/$f" | od -An -tx1 | tr -d '\n')"
done

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
echo "PACK-FINAL-OK"