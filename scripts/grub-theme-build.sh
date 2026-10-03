#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
THEME_NAME=Elegant-mountain-window-left-dark
THEMEDIR="/boot/grub/themes/$THEME_NAME"
LOG="$W/grub-theme-build.log"
exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "regenerate Elegant theme on host"
cd /home/builder/Elegant-grub2-themes || exit 1
sudo rm -rf "/boot/grub/themes/$THEME_NAME"
sudo ./install.sh -b -t mountain -p window -c dark -s 1080p -i left 2>&1 | tail -4
sudo ls -la "$THEMEDIR"
sudo test -f "$THEMEDIR/theme.txt" && echo "theme.txt OK" || { echo "theme.txt MISSING - abort"; exit 1; }

step "angelcore background"
sudo cp -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png "$THEMEDIR/background.jpg"
sudo chown root:root "$THEMEDIR/background.jpg"
sudo chmod 644 "$THEMEDIR/background.jpg"
sudo file "$THEMEDIR/background.jpg"

step "branded theme.txt"
sudo tee "$THEMEDIR/theme.txt" > /dev/null <<'THEME'
desktop-image: "background.jpg"
desktop-color: "#0f0d14"
desktop-text-color: "#e8e4f2"
title-text: "AncorOS 26.04"
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
sudo wc -l "$THEMEDIR/theme.txt"

step "into chroot"
sudo mkdir -p "$R/boot/grub/themes"
sudo rm -rf "$R/boot/grub/themes/$THEME_NAME"
sudo cp -a "$THEMEDIR" "$R/boot/grub/themes/$THEME_NAME"
sudo chown -R root:root "$R/boot/grub/themes/$THEME_NAME"
sudo chmod -R a+rX "$R/boot/grub/themes/$THEME_NAME"
sudo ls -la "$R/boot/grub/themes/$THEME_NAME" | head -14

step "into iso tree"
sudo mkdir -p "$W/isotree/boot/grub/themes"
sudo rm -rf "$W/isotree/boot/grub/themes/$THEME_NAME"
sudo cp -a "$THEMEDIR" "$W/isotree/boot/grub/themes/$THEME_NAME"
sudo chown -R root:root "$W/isotree/boot/grub/themes/$THEME_NAME"
sudo chmod -R a+rX "$W/isotree/boot/grub/themes/$THEME_NAME"
sudo ls -la "$W/isotree/boot/grub/themes/$THEME_NAME" | head -6

step "grub defaults"
sudo sed -i "s|^GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/$THEME_NAME/theme.txt\"|" "$R/etc/default/grub"
sudo grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT|GRUB_TERMINAL' "$R/etc/default/grub"

step "current iso grub.cfg"
sudo cat "$W/isotree/boot/grub/grub.cfg"

echo "GRUB-THEME-BUILD-OK"