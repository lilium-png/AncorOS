#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
THEME_NAME=Elegant-mountain-window-left-dark
THEMEDIR="/boot/grub/themes/$THEME_NAME"
LOG="$W/repack-final.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "mount pseudo filesystems"
for m in proc sys dev run; do
  if ! mountpoint -q "$R/$m"; then sudo mount --bind /$m "$R/$m"; fi
done

step "branded theme.txt with fonts"
sudo tee "$THEMEDIR/theme.txt" > /dev/null <<'THEME'
desktop-image: "background.png"
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
sudo cp -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png "$THEMEDIR/background.png"
sudo rm -f "$THEMEDIR/background.jpg"
sudo chmod 644 "$THEMEDIR/background.png" "$THEMEDIR/theme.txt"
sudo file "$THEMEDIR/background.png"
sudo ls "$THEMEDIR"

step "reinstall theme into chroot and iso tree"
for D in "$R/boot/grub/themes" "$TREE/boot/grub/themes"; do
  sudo mkdir -p "$D"
  sudo rm -rf "$D/$THEME_NAME"
  sudo cp -a "$THEMEDIR" "$D/$THEME_NAME"
  sudo chown -R root:root "$D/$THEME_NAME"
  sudo chmod -R a+rX "$D/$THEME_NAME"
done
sudo ls -la "$R/boot/grub/themes/$THEME_NAME" | head -6
sudo ls -la "$TREE/boot/grub/themes/$THEME_NAME" | head -6

step "whitelabel verify"
sudo cat "$R/usr/share/desktop-provision/whitelabel.yaml"

step "grub defaults"
sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/$THEME_NAME/theme.txt\"|" "$R/etc/default/grub"
sudo grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT' "$R/etc/default/grub"

step "unmount pseudo filesystems"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then sudo umount -l "$R/$m"; fi
done

step "layer 3: usr/share"
rm -f "$LAYERS/minimal.standard.live.squashfs"
cd "$R" || exit 1
sudo mksquashfs usr/share "$LAYERS/minimal.standard.live.squashfs" \
  -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -3

step "layer 4: everything except usr/lib and usr/share"
rm -f "$LAYERS/minimal.standard.live.extra.squashfs"
ENTRIES=$(ls -A . | grep -v -E '^usr$' | tr '\n' ' ')
USRREST=$(ls -A usr | grep -v -E '^(lib|share)$' | sed 's|^|usr/|' | tr '\n' ' ')
sudo mksquashfs $ENTRIES $USRREST "$LAYERS/minimal.standard.live.extra.squashfs" \
  -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -3
cd "$W" || exit 1

step "layer size check"
ok=1
for f in "$LAYERS"/*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then echo "FATAL: $f is $s bytes"; ok=0; else echo "size ok: $(basename "$f") $s"; fi
done
[ "$ok" -eq 1 ] || exit 1

step "copy layers into iso tree"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
cp "$LAYERS/minimal.standard.live.extra.squashfs" "$TREE/casper/minimal.standard.live.extra.squashfs"
SIZE=$(stat -c %s "$LAYERS/minimal.standard.live.extra.squashfs")

step "install-sources.yaml"
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

step "grub.cfg with Elegant theme"
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
if [ "$grub_platform" = "efi" ]; then
menuentry 'Boot from next volume' {
    exit 1
}
menuentry 'UEFI Firmware Settings' {
    fwsetup
}
fi
CFG
head -18 "$TREE/boot/grub/grub.cfg"

step "cloud-init files"
cp -f /home/builder/user-data "$TREE/user-data"
cp -f /home/builder/meta-data "$TREE/meta-data"
cp -f /home/builder/autoinstall.yaml "$TREE/autoinstall.yaml"

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
  "$TREE" 2>&1 | tail -6
if [ ! -s "$OUT" ]; then echo "FATAL: iso not created"; exit 1; fi
ls -la "$OUT"

step "el torito"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -10

step "theme present in iso"
xorriso -indev "$OUT" -find /boot/grub/themes -exec lsdl 2>&1 | head -8

step "checksum"
sha256sum "$OUT" | tee "$OUT.sha256"
echo "REPACK-FINAL-OK"