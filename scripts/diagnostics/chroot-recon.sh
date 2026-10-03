#!/bin/bash
set -eu
W=/home/builder/work
R="$W/mnt/merged"
sudo mkdir -p "$R/proc" "$R/sys" "$R/dev" "$R/run"
sudo mount --bind /proc "$R/proc" 2>/dev/null || true
sudo mount --bind /sys "$R/sys" 2>/dev/null || true
sudo mount --bind /dev "$R/dev" 2>/dev/null || true
sudo mount --bind /run "$R/run" 2>/dev/null || true
sudo cp -f /etc/resolv.conf "$R/etc/resolv.conf" 2>/dev/null || echo "resolv.conf already linked/shared"
echo "=== dpkg packages of interest (inside merged tree) ==="
grep -E '^Package: (gnome-shell|gnome-shell-ubuntu-extensions|dash-to-dock|gnome-shell-extension-ubuntu-dock|ptyxis|gnome-terminal|ubiquity|subiquity|gnome-control-center|gnome-tweaks|flatpak|gnome-initial-setup|ubuntu-desktop|linux-image-generic|plymouth-theme-ubuntu|mutter|gdm3|snapd|fonts-comfortaa|fonts-inter)$' "$R/var/lib/dpkg/status" | sort | while read -r line; do
  pkg="${line#Package: }"
  ver=$(awk -v p="$pkg" '$1=="Package:" && $2==p {found=1} found && $1=="Version:" {print $2; exit}' "$R/var/lib/dpkg/status")
  printf '%s %s\n' "$pkg" "$ver"
done
echo "=== sudo alternative ==="
readlink -f "$R/etc/alternatives/sudo" || true
ls -la "$R/etc/alternatives/sudo" || true
echo "=== rust coreutils links ==="
ls -la "$R/usr/bin/ls" "$R/usr/bin/cat" "$R/usr/bin/grep" 2>/dev/null || true
echo "=== gnu prefixed binaries present? ==="
find "$R/usr/bin" -maxdepth 1 -name 'gnu-*' | head -20
find "$R/usr/bin" -maxdepth 1 -name 'gnu-*' | wc -l
echo "=== ubiquity tree ==="
ls "$R/usr/lib/ubiquity" | head -20
ls "$R/usr/share/ubiquity*" 2>/dev/null | head -20
echo "=== installer desktop entries ==="
ls "$R/usr/share/applications" | grep -Ei 'ubiquity|install' | head -20
echo "=== gnome-shell version file ==="
cat "$R/usr/share/gnome-shell/gnome-shell-theme.gresource" > /dev/null 2>&1 && echo gresource-present || true
python3 - <<'EOF'
import re
p='/home/builder/work/mnt/merged/usr/bin/gnome-shell'
data=open(p,'rb').read(2000000)
m=re.findall(rb'4[5-9]\.\d+|5[0-9]\.\d+', data)
print(sorted({x.decode() for x in m})[:10])
EOF
echo "=== gnome-shell package file list: shell version from changelog ==="
dpkg-deb --version >/dev/null 2>&1 || true
grep -m1 -A2 '^Package: gnome-shell$' "$R/var/lib/dpkg/status" || true
echo "=== X11 presence ==="
ls "$R/usr/bin/Xorg" "$R/usr/bin/X" 2>/dev/null || echo "no Xorg binary"
ls -d "$R/usr/lib/xorg" 2>/dev/null || echo "no /usr/lib/xorg"
echo "=== wayland only check: gdm config ==="
grep -rn 'WaylandEnable' "$R/etc/gdm3/" 2>/dev/null | head -10
echo "=== done ==="