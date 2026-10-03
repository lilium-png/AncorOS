#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
LOG="$W/wallpapers.log"
exec > >(tee -a "$LOG") 2>&1

c() {
  sudo chroot "$R" /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C HOME=/root "$@"
}

echo "############ wallpapers  $(date -Is)"
sudo rm -f "$R/usr/share/backgrounds/ancoros-angelcore-dark-"*.png 2>/dev/null || true
sudo rm -f "$R/usr/share/backgrounds/ancoros-angelcore-light-"*.png 2>/dev/null || true
sudo mkdir -p "$R/usr/share/backgrounds"
sudo cp -f /home/builder/wallpapers/*.png "$R/usr/share/backgrounds/" || echo "wallpaper copy failed"
ls "$R/usr/share/backgrounds" | grep ancoros | tr '\n' ' '
echo

sudo python3 - "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override" <<'PY'
import re
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()

new_uri = "file:///usr/share/backgrounds/ancoros-angelcore-02-angelcore-1920x1080.png"
text = re.sub(r"picture-uri='[^']*'", "picture-uri='" + new_uri + "'", text)
text = re.sub(r"picture-uri-dark='[^']*'", "picture-uri-dark='" + new_uri + "'", text)

with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PY

grep -A3 'org.gnome.desktop.background' "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override" | head -4

sudo tee "$R/usr/share/gnome-background-properties/ancoros.xml" > /dev/null <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore 01</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-01-welcome-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#05070e</pcolor>
    <scolor>#05070e</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore 02</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-02-angelcore-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#05070e</pcolor>
    <scolor>#05070e</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore 03</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-03-whitesur-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#05070e</pcolor>
    <scolor>#05070e</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore 04</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-04-preinstalled-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#05070e</pcolor>
    <scolor>#05070e</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore 05</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-05-automation-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#05070e</pcolor>
    <scolor>#05070e</scolor>
  </wallpaper>
</wallpapers>
XML

sudo python3 - "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override" <<'PY'
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    text = handle.read()

if "org.gnome.desktop.a11y.interface" in text:
    text = text.split("[org.gnome.desktop.a11y.interface]")[0].rstrip() + "\n"

with open(path, "w", encoding="utf-8") as handle:
    handle.write(text)
PY
tail -6 "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override"

c /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas && echo "schemas compiled"

if [ -f /home/builder/ancoros-apply-look.sh ]; then
  sudo cp -f /home/builder/ancoros-apply-look.sh "$R/usr/local/bin/ancoros-apply-look.sh"
  sudo chmod 0755 "$R/usr/local/bin/ancoros-apply-look.sh"
fi
grep -n 'WALL_DARK=' "$R/usr/local/bin/ancoros-apply-look.sh" | head -2

if [ -d /home/builder/slides ]; then
  sudo mkdir -p "$R/usr/share/ancoros-slides"
  sudo cp -f /home/builder/slides/. "$R/usr/share/ancoros-slides/" 2>/dev/null || true
  ls "$R/usr/share/ancoros-slides" | tr '\n' ' '
  echo
fi

echo "WALLPAPERS-OK"