#!/bin/bash
set -u
R=/home/builder/work/mnt/merged
C="sudo chroot $R /usr/bin/env DEBIAN_FRONTEND=noninteractive LC_ALL=C"
echo "=== dash-to-dock keys ==="
$C gsettings list-keys org.gnome.shell.extensions.dash-to-dock 2>/dev/null | tr '\n' ' '
echo
echo "=== dash-to-dock current values ==="
$C gsettings list-recursively org.gnome.shell.extensions.dash-to-dock 2>/dev/null | head -60
echo "=== org.gnome.desktop.interface keys ==="
$C gsettings list-keys org.gnome.desktop.interface 2>/dev/null | tr '\n' ' '
echo
echo "=== wm.preferences keys ==="
$C gsettings list-keys org.gnome.desktop.wm.preferences 2>/dev/null | tr '\n' ' '
echo
echo "=== enabled extensions ==="
ls "$R/usr/share/gnome-shell/extensions" 2>/dev/null | tr '\n' ' '
echo
echo "=== schemas dir ==="
ls "$R/usr/share/glib-2.0/schemas" | grep -i -E 'dash|ubuntu|shell' | head -10
echo "=== ubuntu session gsettings overrides ==="
find "$R/usr/share/glib-2.0/schemas" -name '*ubuntu*' | head -10
echo "=== default gsettings file ==="
ls -la "$R/usr/share/glib-2.0/schemas/10_ubuntu-settings.gschema.override" 2>/dev/null && head -40 "$R/usr/share/glib-2.0/schemas/10_ubuntu-settings.gschema.override"
echo "=== app grid related keys (search schemas) ==="
grep -rl --binary-files=without-match 'app-grid\|app_grid' "$R/usr/share/glib-2.0/schemas/" 2>/dev/null | head -10
echo "=== icons/cursors currently ==="
ls "$R/usr/share/icons" | tr '\n' ' '
echo
echo "=== themes ==="
ls "$R/usr/share/themes" | tr '\n' ' '
echo
echo "=== done ==="