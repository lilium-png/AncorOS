#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
LOG="$W/grub-theme.log"
exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "run Elegant install.sh on host"
cd /home/builder/Elegant-grub2-themes || exit 1
sudo rm -rf /boot/grub/themes/Elegant-* 2>/dev/null || true
sudo ./install.sh -b -t mountain -p window -c dark -s 1080p -i left 2>&1 | tail -12

step "generated themes on host"
ls -la /boot/grub/themes/ 2>&1 | head -8
THEMEDIR=$(ls -d /boot/grub/themes/Elegant-* 2>/dev/null | head -1)
echo "theme dir: $THEMEDIR"
if [ -n "$THEMEDIR" ]; then
  ls -la "$THEMEDIR" | head -10
  step "angelcore wallpaper as grub background"
  cp -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png "$THEMEDIR/ancoros-bg.png"
  THEME_NAME=$(basename "$THEMEDIR")
  echo "theme name: $THEME_NAME"
  grep -n 'wallpaper\|background' "$THEMEDIR/theme.txt" | head -8
fi

step "copy theme into chroot"
sudo mkdir -p "$R/boot/grub/themes"
if [ -n "$THEMEDIR" ]; then
  sudo rm -rf "${THEMEDIR/#/\/}" >/dev/null 2>&1 || true
  sudo rm -rf "$R/boot/grub/themes/$(basename "$THEMEDIR")"
  sudo cp -a "$THEMEDIR" "$R/boot/grub/themes/"
  sudo chmod -R a+rX "$R/boot/grub/themes"
fi
ls -la "$R/boot/grub/themes" 2>&1 | head -8

step "set grub defaults with actual theme name"
THEME_NAME=$(basename "$(ls -d /boot/grub/themes/Elegant-* 2>/dev/null | head -1)")
sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/${THEME_NAME}/theme.txt\"|" "$R/etc/default/grub"
grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT' "$R/etc/default/grub"

step "theme into iso tree as well"
if [ -n "$THEMEDIR" ]; then
  mkdir -p "$W/isotree/boot/grub/themes"
  rm -rf "$W/isotree/boot/grub/themes/$(basename "$THEMEDIR")"
  cp -a "$THEMEDIR" "$W/isotree/boot/grub/themes/"
  ls -la "$W/isotree/boot/grub/themes" | head -6
fi

echo "GRUB-THEME-OK"