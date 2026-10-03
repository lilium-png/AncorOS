#!/bin/bash
set -u
T=/home/builder/work/themes/extracted/WhiteSur-Dark
echo "=== gnome-shell dir full ==="
ls "$T/gnome-shell"
echo "=== define-color names in gtk-3.0/gtk.css ==="
grep -o '@define-color [a-zA-Z0-9_]*' "$T/gtk-3.0/gtk.css" | awk '{print $2}' | sort -u | tr '\n' ' '
echo
echo "=== first define-color lines ==="
grep -m 40 '@define-color' "$T/gtk-3.0/gtk.css" | head -40
echo "=== gtk.css size ==="
wc -c "$T/gtk-3.0/gtk.css" "$T/gtk-4.0/gtk.css" "$T/gnome-shell/gnome-shell.css"
echo "=== does gtk-3.0 gtk.css import gtk-dark.css? ==="
head -5 "$T/gtk-3.0/gtk.css"
head -5 "$T/gtk-3.0/gtk-dark.css"
echo "=== icons src/apps subdirs ==="
ls "$T/../../WhiteSur-icon-theme-master/src/apps" 2>/dev/null | head -8
ls /home/builder/work/themes/WhiteSur-icon-theme-master/src/apps/16x16 2>/dev/null | head -5
echo "=== cursors dist listing ==="
ls /home/builder/work/themes/WhiteSur-cursors-master/dist
ls /home/builder/work/themes/WhiteSur-cursors-master/dist/cursors | grep -c .
echo "=== done ==="