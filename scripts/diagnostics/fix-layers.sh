#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
THEME_NAME=Elegant-mountain-window-left-dark
THEMEDIR="$TREE/boot/grub/themes/$THEME_NAME"
LOG="$W/fix-layers.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "disk space before"
df -h /home | tail -1

step "current layers"
ls -la "$LAYERS"/*.squashfs

step "rename extra layer to minimal.squashfs"
rm -f "$LAYERS/minimal.squashfs"
if [ -f "$LAYERS/minimal.standard.live.extra.squashfs" ]; then
  mv "$LAYERS/minimal.standard.live.extra.squashfs" "$LAYERS/minimal.squashfs"
fi
ls -la "$LAYERS"/*.squashfs
echo "--- sizes vs 4 GiB limit ---"
ok=1
for f in "$LAYERS"/*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then echo "FATAL $(basename "$f") = $s"; ok=0; else echo "ok $(basename "$f") = $s"; fi
done
[ "$ok" -eq 1 ] || exit 1

step "layer contents sanity"
sudo test -e "$R/usr/bin/systemd" && echo "systemd in base source tree" || echo "systemd NOT in source tree (expected, it is a merged overlay)"
sudo ls "$R/sbin/init" "$R/usr/lib/systemd" -d 2>&1 | head -3
sudo ls "$R/usr/share/gnome-shell" -d 2>&1

step "grub background as jpeg"
sudo mkdir -p "$THEMEDIR"
sudo cp -f /home/builder/wallpapers/ancoros-grub-bg.jpg "$THEMEDIR/background.jpg"
sudo chmod 644 "$THEMEDIR/background.jpg"
sudo file "$THEMEDIR/background.jpg"
sudo ls -la "$THEMEDIR" | head -12

step "theme.txt"
sudo tee "$THEMEDIR/theme.txt" > /dev/null <<'THEME'
desktop-image: "background.jpg"
desktop-color: "#0f0d14"
desktop-text-color: "#e8e4f2"
title-text: "AncorOS 26.04"
font-title: "terminus-18.pf2"
font-body: "terminus-12.pf2"
color_fg: "#b8a0ff"
color_bg: "#0f0d14"
color_selected_fg: "#0f0d14"
color_selected_bg: "#b8a0ff"
color_menu_fg: "#cfc7e8"
color_menu_bg: "#0f0d14"
color_menu_highlight_fg: "#ffffff"
color_menu_highlight_bg: "#3a2f5c"
color_scrollbar: "#b8a0ff"
border_color: "#b8a0ff"
THEME
sudo chown -R root:root "$THEMEDIR"
sudo chmod -R a+rX "$THEMEDIR"

step "install-sources.yaml with three layers"
TOTAL=$(df -B1 --output=size "$R" | tail -1 | tr -d ' ')
BASE=$(stat -c %s "$LAYERS/minimal.squashfs")
STD=$(stat -c %s "$LAYERS/minimal.standard.squashfs")
LIVE=$(stat -c %s "$LAYERS/minimal.standard.live.squashfs")
echo "base=$BASE standard=$STD live=$LIVE uncompressed=$TOTAL"
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
sudo cat "$TREE/casper/install-sources.yaml"

step "copy three layers into iso tree"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
ls -la "$TREE/casper"/*.squashfs

step "grub.cfg without layerfs-path"
sudo chown "$(id -un):$(id -gn)" "$TREE/boot/grub/grub.cfg" 2>/dev/null || sudo chmod u+w "$TREE/boot/grub/grub.cfg"
cat > "$TREE/boot/grub/grub.cfg" <<CFG
set default=0
set timeout=30
set timeout_style=menu

loadfont unicode

insmod all_video
insmod gfxterm
insmod gfxterm_background
insmod jpeg

set gfxmode=1280x720,1024x768,auto
set gfxpayload=keep

terminal_output console
if terminal_output gfxterm; then
    if [ -f /boot/grub/themes/$THEME_NAME/theme.txt ]; then
        load_theme /boot/grub/themes/$THEME_NAME/theme.txt
    fi
fi

menuentry "Install AncorOS (automatic)" {
    linux  /casper/vmlinuz autoinstall --- quiet splash
    initrd /casper/initrd
}
menuentry "Try AncorOS" {
    linux  /casper/vmlinuz --- quiet splash
    initrd /casper/initrd
}
menuentry "AncorOS (safe graphics)" {
    linux  /casper/vmlinuz nomodeset --- quiet splash
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
echo "grub.cfg bytes: $(stat -c %s "$TREE/boot/grub/grub.cfg")"
echo "layerfs-path occurrences: $(grep -c 'layerfs-path' "$TREE/boot/grub/grub.cfg" || true)"
echo "menuentries: $(grep -c '^menuentry' "$TREE/boot/grub/grub.cfg")"

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

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -7

step "verify layers inside iso"
xorriso -indev "$OUT" -find /casper -maxdepth 1 2>/dev/null | grep squashfs

step "checksum"
sha256sum "$OUT" | sudo tee "$OUT.sha256"
echo "FIX-LAYERS-OK"