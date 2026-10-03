#!/bin/bash
set -u
R=/home/builder/work/mnt/merged
echo "=== transparency-mode / preview / middle-click enums ==="
grep -A12 'key name="transparency-mode"' "$R/usr/share/glib-2.0/schemas/org.gnome.shell.extensions.dash-to-dock.gschema.xml" 2>/dev/null | head -20
ls "$R/usr/share/glib-2.0/schemas" | grep -i dock
echo "=== existing overrides content ==="
for f in 00_org.gnome.shell.gschema.override 10_gnome-shell.gschema.override 10_ubuntu-dock.gschema.override; do
  echo "--- $f ---"
  head -30 "$R/usr/share/glib-2.0/schemas/$f" 2>/dev/null
done
echo "=== themes ==="
ls "$R/usr/share/themes" | tr '\n' ' '
echo
echo "=== icons ==="
ls "$R/usr/share/icons" | tr '\n' ' '
echo
echo "=== fonts ==="
fc-list 2>/dev/null | head -3 || true
ls "$R/usr/share/fonts/truetype" 2>/dev/null | tr '\n' ' '
echo
echo "=== shell theme check (gnome-shell themes installed?) ==="
ls "$R/usr/share/themes/Yaru" 2>/dev/null | tr '\n' ' '
echo
echo "=== apt sources in image ==="
cat "$R/etc/apt/sources.list" 2>/dev/null | grep -v '^#' | grep -v '^$' | head -20
ls "$R/etc/apt/sources.list.d/" 2>/dev/null | tr '\n' ' '
echo
echo "=== apt sources ubuntu.sources ==="
cat "$R/etc/apt/sources.list.d/ubuntu.sources" 2>/dev/null | head -30
echo "=== done ==="