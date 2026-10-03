#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
THEME_NAME=Elegant-mountain-window-left-dark
THEMEDIR="/boot/grub/themes/$THEME_NAME"
LOG="$W/grub-theme-fix.log"
exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "verify generated theme"
sudo ls -la "$THEMEDIR"
echo "--- theme.txt present? ---"
sudo test -f "$THEMEDIR/theme.txt" && echo "theme.txt OK" || echo "theme.txt MISSING"
echo "--- desktop-image line ---"
sudo grep -n 'desktop-image\|title-text\|color_fg' "$THEMEDIR/theme.txt" | head -6
echo "--- icons count ---"
sudo ls "$THEMEDIR/icons" | wc -l

step "replace background with angelcore wallpaper"
sudo cp -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png "$THEMEDIR/ancoros-bg.png"
sudo cp -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png "$THEMEDIR/background.jpg"
sudo chown root:root "$THEMEDIR/background.jpg"
sudo chmod 644 "$THEMEDIR/background.jpg" "$THEMEDIR/ancoros-bg.png"
sudo ls -la "$THEMEDIR" | head -12

step "theme text tuning: brand titles in ancoros colours"
sudo tee "$THEMEDIR/theme.txt" > /dev/null <<'THEME'
desktop-image: "background.jpg"
desktop-color: "#0f0d14"
desktop-text-color: "#e8e4f2"
title-text: "AncorOS"
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
sudo grep -c . "$THEMEDIR/theme.txt"

step "copy theme into chroot"
sudo rm -rf "$R/boot/grub/themes/$THEME_NAME"
sudo mkdir -p "$R/boot/grub/themes"
sudo cp -a "$THEMEDIR" "$R/boot/grub/themes/$THEME_NAME"
sudo chown -R root:root "$R/boot/grub/themes/$THEME_NAME"
sudo chmod -R a+rX "$R/boot/grub/themes/$THEME_NAME"
sudo ls -la "$R/boot/grub/themes/$THEME_NAME" | head -12

step "theme into iso tree"
sudo mkdir -p "$W/isotree/boot/grub/themes"
sudo rm -rf "$W/isotree/boot/grub/themes/$THEME_NAME"
sudo cp -a "$THEMEDIR" "$W/isotree/boot/grub/themes/$THEME_NAME"
sudo chown -R root:root "$W/isotree/boot/grub/themes"
sudo chmod -R a+rX "$W/isotree/boot/grub/themes"
sudo ls -la "$W/isotree/boot/grub/themes/$THEME_NAME" | head -6

step "fix GRUB_THEME in chroot"
sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/$THEME_NAME/theme.txt\"|" "$R/etc/default/grub"
sudo grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT|GRUB_TERMINAL' "$R/etc/default/grub"

step "whitelabel verify"
sudo cat "$R/usr/share/desktop-provision/whitelabel.yaml"

echo "GRUB-THEME-FIX-OK"