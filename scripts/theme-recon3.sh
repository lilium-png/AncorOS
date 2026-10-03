#!/bin/bash
set -u
T=/home/builder/work/themes
mkdir -p "$T/extracted"
cd "$T/extracted"
echo "=== extract WhiteSur-Dark.tar.xz ==="
tar xJf "$T/WhiteSur-gtk-theme-2026-09-10/release/WhiteSur-Dark.tar.xz" && echo extracted
find . -maxdepth 2 -type d | head -20
echo "=== theme dirs ==="
ls -d WhiteSur-Dark/* 2>/dev/null | head -20
echo "=== index.theme ==="
cat WhiteSur-Dark/index.theme 2>/dev/null | head -20
echo "=== gtk-3.0 sample ==="
ls WhiteSur-Dark/gtk-3.0 2>/dev/null | head -15
echo "=== gtk-4.0 sample ==="
ls WhiteSur-Dark/gtk-4.0 2>/dev/null | head -15
echo "=== gnome-shell sample ==="
ls WhiteSur-Dark/gnome-shell 2>/dev/null | head -15
echo "=== gnome-shell version ==="
grep -o '"[0-9][0-9]"' WhiteSur-Dark/gnome-shell/gnome-shell-theme.gresource.xml 2>/dev/null | head -3
cat WhiteSur-Dark/gnome-shell/gnome-shell-theme.gresource.xml 2>/dev/null | head -8
echo "=== cursor dist ==="
ls "$T/WhiteSur-cursors-master/dist/cursors" | head -10
cat "$T/WhiteSur-cursors-master/dist/index.theme" 2>/dev/null | head -15
echo "=== icons src ==="
ls "$T/WhiteSur-icon-theme-master/src" | head -20
find "$T/WhiteSur-icon-theme-master/src" -maxdepth 1 -type d | head -20
echo "=== icons: is it scss? ==="
find "$T/WhiteSur-icon-theme-master" -name '*.scss' | head -5
echo "=== icons prebuilt dirs? ==="
find "$T/WhiteSur-icon-theme-master" -maxdepth 2 -type d -name '*16x16*' | head -5
echo "=== sassc available? ==="
command -v sassc || echo "sassc missing"
echo "=== done ==="