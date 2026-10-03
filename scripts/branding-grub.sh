#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
LOG="$W/branding-grub.log"
exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "mount pseudo filesystems for chroot work"
for m in proc sys dev run; do
  sudo mkdir -p "$R/$m"
  mountpoint -q "$R/$m" || sudo mount --bind /$m "$R/$m"
done
mount | grep -c "on $R/"

step "installer whitelabel"
sudo mkdir -p "$R/usr/share/desktop-provision"
sudo tee "$R/usr/share/desktop-provision/whitelabel.yaml" > /dev/null <<'YAML'
app-name: AncorOS
accent-color: "#b8a0ff"
YAML
cat "$R/usr/share/desktop-provision/whitelabel.yaml"
echo "--- existing whitelabel inside bootstrap snap ---"
sudo find "$R/snap/ubuntu-desktop-bootstrap" -name 'whitelabel*' 2>/dev/null | head -5
sudo find "$R/var/lib/snapd/snaps" -maxdepth 1 -name 'ubuntu-desktop-bootstrap*' 2>/dev/null | head -2

step "fetch Elegant grub themes"
cd /home/builder || exit 1
if [ ! -d Elegant-grub2-themes ]; then
  sudo rm -rf Elegant-grub2-themes
  git clone --depth=1 https://github.com/vinceliuice/Elegant-grub2-themes.git 2>&1 | tail -2
fi
ls Elegant-grub2-themes | head -8

step "theme files available"
ls Elegant-grub2-themes/themes 2>/dev/null | head -10
ls Elegant-grub2-themes/themes/Elegant-mountain 2>/dev/null | head -5

step "install mountain theme dark window into chroot"
sudo mkdir -p "$R/boot/grub/themes"
if [ -d Elegant-grub2-themes/themes/Elegant-mountain ]; then
  sudo rm -rf "$R/boot/grub/themes/Elegant-mountain"
  sudo cp -a Elegant-grub2-themes/themes/Elegant-mountain "$R/boot/grub/themes/Elegant-mountain"
fi
sudo chmod -R a+rX "$R/boot/grub/themes" 2>/dev/null || true
ls -la "$R/boot/grub/themes/Elegant-mountain" 2>&1 | head -6

step "angelcore background for grub"
sudo mkdir -p "$R/usr/share/backgrounds"
if [ -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png ]; then
  sudo cp -f /home/builder/wallpapers/ancoros-angelcore-01-welcome-1920x1080.png "$R/boot/grub/themes/Elegant-mountain/ancoros-bg.png"
  echo "background copied into theme dir"
else
  echo "wallpaper not found in /home/builder/wallpapers"
fi
ls -la "$R/boot/grub/themes/Elegant-mountain" | head -8

step "grub defaults"
sudo cp -f /home/builder/grub-defaults "$R/etc/default/grub"
grep -E 'GRUB_THEME|GRUB_GFXMODE|GRUB_TIMEOUT' "$R/etc/default/grub"

step "update-grub inside chroot"
sudo chroot "$R" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C /bin/bash -c 'update-grub 2>&1 | tail -6' || echo "update-grub returned non zero"

step "for unmount before packing"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then
    sudo umount -l "$R/$m" && echo "unmounted $m"
  fi
done

echo "BRANDING-GRUB-OK"