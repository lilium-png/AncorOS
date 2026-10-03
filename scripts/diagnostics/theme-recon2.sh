#!/bin/bash
set -u
T=/home/builder/work/themes
echo "=== gtk release dir ==="
ls "$T/WhiteSur-gtk-theme-2026-09-10/release" 2>/dev/null | head -30
echo "=== gtk release depth2 ==="
find "$T/WhiteSur-gtk-theme-2026-09-10/release" -maxdepth 2 -type d 2>/dev/null | head -30
echo "=== gtk theme dirs containing index.theme ==="
find "$T/WhiteSur-gtk-theme-2026-09-10" -name 'index.theme' 2>/dev/null | head -20
echo "=== gtk gnome-shell.css locations ==="
find "$T/WhiteSur-gtk-theme-2026-09-10" -name 'gnome-shell.css' 2>/dev/null | head -10
echo "=== gtk gtk.css locations (sample) ==="
find "$T/WhiteSur-gtk-theme-2026-09-10" -name 'gtk.css' 2>/dev/null | head -15
echo "=== icons release ==="
ls "$T/WhiteSur-icon-theme-master/release" 2>/dev/null | head -20
find "$T/WhiteSur-icon-theme-master" -name 'index.theme' 2>/dev/null | head -10
echo "=== cursors dist ==="
ls "$T/WhiteSur-cursors-master/dist" 2>/dev/null | head -20
find "$T/WhiteSur-cursors-master/dist" -name 'index.theme' 2>/dev/null | head -5
echo "=== sizes ==="
du -sh "$T/WhiteSur-gtk-theme-2026-09-10" "$T/WhiteSur-icon-theme-master" "$T/WhiteSur-cursors-master" 2>/dev/null
echo "=== install.sh destdir handling ==="
grep -n 'DESTDIR\|destdir' "$T/WhiteSur-gtk-theme-2026-09-10/install.sh" | head -10
echo "=== done ==="