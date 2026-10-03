#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
THEME_NAME=Elegant-mountain-window-left-dark
LOG="$W/rebuild-iso.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "isotree permissions"
sudo ls -la "$TREE/boot/grub/" | head -8
sudo chmod u+w "$TREE/boot/grub/grub.cfg"
sudo chown builder:builder "$TREE/boot/grub/grub.cfg" 2>/dev/null || sudo chown "$(id -un):$(id -gn)" "$TREE/boot/grub/grub.cfg"
sudo ls -la "$TREE/boot/grub/grub.cfg"

step "write grub.cfg"
cat > "$TREE/boot/grub/grub.cfg" <<CFG
set timeout=30
set timeout_style=menu

loadfont unicode

insmod all_video
insmod gfxterm
insmod png

terminal_output console
if terminal_output gfxterm; then
    set gfxmode=1920x1080
    if [ -f /boot/grub/themes/$THEME_NAME/theme.txt ]; then
        load_theme /boot/grub/themes/$THEME_NAME/theme.txt
    fi
fi

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
if [ "\$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
    exit 1
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
fi
CFG
echo "bytes: $(stat -c %s "$TREE/boot/grub/grub.cfg")"
echo "menuentries: $(grep -c '^menuentry' "$TREE/boot/grub/grub.cfg")"
echo "theme load: $(grep -c 'load_theme' "$TREE/boot/grub/grub.cfg")"

step "grub.cfg written back into chroot tree check"
sudo wc -c "$R/boot/grub/grub.cfg"

step "theme files in tree"
sudo ls -la "$TREE/boot/grub/themes/$THEME_NAME" | head -6
sudo cat "$TREE/boot/grub/themes/$THEME_NAME/theme.txt"

step "install-sources refresh"
SIZE=$(stat -c %s "$LAYERS/minimal.standard.live.extra.squashfs")
echo "layer4 size: $SIZE"

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
  "$TREE" 2>&1 | tail -5
if [ ! -s "$OUT" ]; then echo "FATAL: iso not created"; exit 1; fi
ls -la "$OUT"

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -8

step "grub.cfg inside iso"
xorriso -indev "$OUT" -find /boot/grub -name grub.cfg 2>/dev/null | head -3

step "checksum"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "REBUILD-ISO-OK"