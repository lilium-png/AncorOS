#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
LOG="$W/finish-chroot.log"
exec > >(tee -a "$LOG") 2>&1

APT_OPTS="-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -o Acquire::Retries=3"

c() {
  sudo chroot "$R" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C HOME=/root NEEDRESTART_MODE=a "$@"
}

step() {
  echo
  echo "############ $*  $(date -Is)"
}

step "preflight"
test -d "$R" || { echo "merged tree missing"; exit 1; }
sudo mountpoint -q "$R/proc" || sudo mount --bind /proc "$R/proc"
sudo mountpoint -q "$R/dev" || sudo mount --bind /dev "$R/dev"
sudo mountpoint -q "$R/sys" || sudo mount --bind /sys "$R/sys"
sudo mountpoint -q "$R/run" || sudo mount --bind /run "$R/run"
df -h /home/builder | tail -1

step "interrupted install repair"
c /usr/bin/dpkg --configure -a || true
c /usr/bin/dpkg --audit || true

step "fonts gothic and serif"
sudo mkdir -p "$R/usr/local/share/fonts/ancoros"
if [ -d /home/builder/fonts ]; then
  sudo cp -a /home/builder/fonts/. "$R/usr/local/share/fonts/ancoros/"
fi
ls "$R/usr/local/share/fonts/ancoros" | tr '\n' ' '
echo
c /usr/bin/fc-cache -f /usr/local/share/fonts/ancoros || true
c /usr/bin/fc-list | grep -Ei 'unifraktur|cormorant|playfair|pirata' | head -8 || true

step "gothic titlebar font default"
sudo python3 - "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()

if "titlebar-font" not in text:
    text = text.replace(
        "[org.gnome.desktop.wm.preferences]\ntheme='Adwaita'\n",
        "[org.gnome.desktop.wm.preferences]\ntheme='Adwaita'\ntitlebar-font='Unifraktur Cook 13'\n",
    )

with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PY
grep -A4 'wm.preferences' "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override" | head -6
c /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas && echo "schemas compiled"

step "apply-look script refresh"
if [ -f /home/builder/ancoros-apply-look.sh ]; then
  sudo cp -f /home/builder/ancoros-apply-look.sh "$R/usr/local/bin/ancoros-apply-look.sh"
  sudo chmod 0755 "$R/usr/local/bin/ancoros-apply-look.sh"
fi
if [ -f /home/builder/ancoros-firstboot.sh ]; then
  sudo cp -f /home/builder/ancoros-firstboot.sh "$R/usr/local/bin/ancoros-firstboot.sh"
  sudo chmod 0755 "$R/usr/local/bin/ancoros-firstboot.sh"
fi
grep -n titlebar-font "$R/usr/local/bin/ancoros-apply-look.sh" | head -3 || true

step "flatpak sober"
if [ -x "$R/usr/bin/flatpak" ]; then
  sudo chroot "$R" /usr/bin/env DEBIAN_FRONTEND=noninteractive HOME=/root /usr/bin/bash -c 'flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo; flatpak install --system -y --noninteractive flathub org.vinegarhq.Sober' || echo "sober system install failed"
  sudo chroot "$R" /usr/bin/env HOME=/root /usr/bin/flatpak list 2>/dev/null | head -10 || true
fi

step "package audit"
c /usr/bin/dpkg -l | grep -E '^i[^i]' | awk '{print $2, $3}' | head -30 || true
c /usr/bin/dpkg -l | grep -E 'google-chrome|steam-launcher|tg-ws-proxy|incy|code|powershell|windows-terminal|docker|nodejs|neovim|ptyxis|whitesur|flatpak|obs-studio|telegram' | awk '{print $2, $3}' | head -30 || true

step "cleanup inside chroot"
c /usr/bin/apt-get $APT_OPTS clean || true
sudo rm -rf "$R/var/lib/apt/lists/"* || true
sudo rm -f "$R/var/cache/apt/archives/"*.deb 2>/dev/null || true
sudo rm -rf "$R/tmp/ancoros-debs" || true
sudo rm -rf "$R/tmp/"* 2>/dev/null || true
sudo rm -rf "$R/var/log/"* 2>/dev/null || true
sudo rm -rf "$R/root/.cache" 2>/dev/null || true
sudo find "$R/var/cache" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

step "verification"
ls -d "$R/usr/share/themes/WhiteSur-Dark" "$R/usr/share/icons/WhiteSur-Dark" "$R/usr/share/icons/WhiteSur-cursors" 2>&1
ls "$R/usr/share/gnome-shell/extensions" | tr '\n' ' '
echo
ls "$R/usr/share/backgrounds" | grep ancoros | tr '\n' ' '
echo
ls -la "$R/usr/local/bin/ancoros-firstboot.sh" "$R/usr/local/bin/ancoros-apply-look.sh" 2>&1
ls -la "$R/etc/systemd/system/ancoros-firstboot.service" "$R/etc/xdg/autostart/ancoros-apply-look.desktop" 2>&1
head -3 "$R/etc/os-release"

step "size"
sudo du -sh --apparent-size "$R" 2>/dev/null | tail -1 || true
sudo du -sh "$R" 2>/dev/null | tail -1 || true
df -h /home/builder | tail -1
echo "FINISH-CHROOT-OK"