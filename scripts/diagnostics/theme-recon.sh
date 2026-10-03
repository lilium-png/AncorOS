#!/bin/bash
set -u
W=/home/builder/work
mkdir -p "$W/themes" "$W/dl"
cd "$W/dl"
echo "=== download theme tarballs ==="
curl -sSL -o whitesur-gtk.tar.gz https://github.com/vinceliuice/WhiteSur-gtk-theme/archive/refs/tags/2026-09-10.tar.gz && echo gtk-ok
curl -sSL -o whitesur-icons.tar.gz https://github.com/vinceliuice/WhiteSur-icon-theme/archive/refs/heads/master.tar.gz && echo icons-ok
curl -sSL -o whitesur-cursors.tar.gz https://github.com/vinceliuice/WhiteSur-cursors/archive/refs/heads/master.tar.gz && echo cursors-ok
ls -la
cd "$W/themes"
tar xzf "$W/dl/whitesur-gtk.tar.gz"
tar xzf "$W/dl/whitesur-icons.tar.gz"
tar xzf "$W/dl/whitesur-cursors.tar.gz"
ls
echo "=== gtk theme top level ==="
ls WhiteSur-gtk-theme-2026-09-10 | head -40
echo "=== gtk-3.0 dir ==="
ls WhiteSur-gtk-theme-2026-09-10/gtk-3.0 2>/dev/null | head -20
echo "=== gtk-4.0 dir ==="
ls WhiteSur-gtk-theme-2026-09-10/gtk-4.0 2>/dev/null | head -20
echo "=== shell theme dir ==="
ls WhiteSur-gtk-theme-2026-09-10/WhiteSur-Dark 2>/dev/null | head -20
ls WhiteSur-gtk-theme-2026-09-10/WhiteSur-Dark/gnome-shell 2>/dev/null | head -20
echo "=== color-schemes ==="
ls WhiteSur-gtk-theme-2026-09-10/color-schemes 2>/dev/null | head -20
echo "=== gnome version support ==="
cat WhiteSur-gtk-theme-2026-09-10/gnome-shell/gnome-shell-theme.gresource.xml 2>/dev/null | head -5
cat WhiteSur-gtk-theme-2026-09-10/WhiteSur-Dark/gnome-shell/gnome-shell-theme.gresource.xml 2>/dev/null | head -5
echo "=== metadata.json ==="
head -30 WhiteSur-gtk-theme-2026-09-10/metadata.json 2>/dev/null
echo "=== install.sh usage / darker ==="
grep -n 'darker' WhiteSur-gtk-theme-2026-09-10/install.sh | head -30
echo "=== install.sh flags ==="
grep -n -A30 'usage' WhiteSur-gtk-theme-2026-09-10/install.sh | head -50
echo "=== icons layout ==="
ls WhiteSur-icon-theme-master | head -20
ls WhiteSur-icon-theme-master/icons 2>/dev/null | head -20
echo "=== cursors layout ==="
ls WhiteSur-cursors-master | head -20
ls WhiteSur-cursors-master/bin 2>/dev/null | head -20
echo "=== done ==="