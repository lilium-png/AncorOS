#!/bin/bash
set -u
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq libglib2.0-dev-bin > /dev/null 2>&1 || true
command -v gresource || echo "gresource missing"
T=/home/builder/work/themes/extracted/WhiteSur-Dark
mkdir -p /home/builder/work/gres
cd /home/builder/work/gres
echo "=== list resources gtk3 ==="
gresource list "$T/gtk-3.0/gtk.gresource" 2>/dev/null | head -10
echo "=== list resources gtk4 ==="
gresource list "$T/gtk-4.0/gtk.gresource" 2>/dev/null | head -10
gresource extract "$T/gtk-3.0/gtk.gresource" /org/gnome/theme/gtk-dark.css > gtk3-dark.css 2>/dev/null || echo "extract failed"
gresource extract "$T/gtk-4.0/gtk.gresource" /org/gnome/theme/gtk-dark.css > gtk4-dark.css 2>/dev/null || echo "extract failed"
wc -c gtk3-dark.css gtk4-dark.css 2>/dev/null
echo "=== define-color names ==="
grep -o '@define-color [a-zA-Z0-9_]*' gtk3-dark.css 2>/dev/null | awk '{print $2}' | sort -u | tr '\n' ' '
echo
echo "=== main surface colors ==="
grep -E '@define-color (theme_bg_color|theme_fg_color|window_bg_color|window_fg_color|headerbar_bg_color|headerbar_fg_color|sidebar_bg_color|popover_bg_color|menu_bg_color|borders|accent_bg_color|accent_color|wm_bg|wm_border|wm_title|wm_unfocused_title|wm_icons_hover|wm_icons_focused|content_view_bg|osd_bg_color|osd_fg_color|view_bg_color|view_fg_color|insensitive_bg_color|insensitive_fg_color|insensitive_base_color|backdrop_base_color|backdrop_bg_color|backdrop_fg_color|card_bg_color|card_fg_color|dialog_bg_color|dialog_fg_color|placeholder_text_color|text_view_bg_color|selected_bg_color|selected_fg_color)' gtk3-dark.css 2>/dev/null | head -45
echo "=== gtk4 dark define-colors (subset) ==="
grep -E '@define-color (theme_bg_color|window_bg_color|headerbar_bg_color|sidebar_bg_color|popover_bg_color|accent_color|accent_bg_color|wm_bg|wm_title|card_bg_color|dialog_bg_color|backdrop_bg_color)' gtk4-dark.css 2>/dev/null | head -30
echo "=== done ==="