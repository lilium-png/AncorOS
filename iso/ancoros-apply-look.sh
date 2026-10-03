#!/usr/bin/env bash
set -u
LOG=/var/log/ancoros-apply-look.log
exec >>"$LOG" 2>&1
echo "=== ancoros apply-look start $(date -Is) user=$(id -un) ==="

THEME=WhiteSur-Dark
USER_THEME_EXT=user-theme@gnome-shell-extensions.gcampax.github.com
WALL_DARK=/usr/share/backgrounds/ancoros-angelcore-02-angelcore-1920x1080.png

g() {
  gsettings "$@" 2>/dev/null || true
}

g set org.gnome.desktop.interface gtk-theme "$THEME"
g set org.gnome.desktop.interface color-scheme 'prefer-dark'
g set org.gnome.desktop.interface icon-theme "$THEME"
g set org.gnome.desktop.interface cursor-theme WhiteSur-cursors
g set org.gnome.desktop.interface cursor-size 24
g set org.gnome.desktop.interface font-name 'Comfortaa 11'
g set org.gnome.desktop.interface document-font-name 'Comfortaa 11'
g set org.gnome.desktop.interface monospace-font-name 'Ubuntu Mono 13'
g set org.gnome.desktop.interface enable-animations true
g set org.gnome.desktop.interface color-scheme 'prefer-dark'

g set org.gnome.desktop.wm.preferences theme 'Adwaita'
g set org.gnome.desktop.wm.preferences titlebar-font 'Unifraktur Cook 13'
g set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
g set org.gnome.desktop.a11y.interface tooltips 1

g set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
g set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 64
g set org.gnome.shell.extensions.dash-to-dock icon-size-fixed true
g set org.gnome.shell.extensions.dash-to-dock intellihide true
g set org.gnome.shell.extensions.dash-to-dock intellihide-mode 'ALL_WINDOWS'
g set org.gnome.shell.extensions.dash-to-dock dock-fixed false
g set org.gnome.shell.extensions.dash-to-dock autohide false
g set org.gnome.shell.extensions.dash-to-dock extend-height false
g set org.gnome.shell.extensions.dash-to-dock force-straight-corner false
g set org.gnome.shell.extensions.dash-to-dock apply-glossy-effect false
g set org.gnome.shell.extensions.dash-to-dock custom-background-color true
g set org.gnome.shell.extensions.dash-to-dock background-color 'rgba(24,22,32,0.55)'
g set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
g set org.gnome.shell.extensions.dash-to-dock show-trash false
g set org.gnome.shell.extensions.dash-to-dock show-mounts true
g set org.gnome.shell.extensions.dash-to-dock animation-time 0.15
g set org.gnome.shell.extensions.dash-to-dock click-action 'focus-or-appspread'
g set org.gnome.shell.extensions.dash-to-dock show-apps-always-in-the-edge false
g set org.gnome.shell.extensions.dash-to-dock workspace-agnostic-urgent-windows false
g set org.gnome.shell.extensions.dash-to-dock pressure-threshold -1

if [ -f "$WALL_DARK" ]; then
  g set org.gnome.desktop.background picture-uri "file://$WALL_DARK"
  g set org.gnome.desktop.background picture-uri-dark "file://$WALL_DARK"
fi

if [ -d "/usr/share/gnome-shell/extensions/$USER_THEME_EXT" ] || [ -d "$HOME/.local/share/gnome-shell/extensions/$USER_THEME_EXT" ]; then
  python3 - <<'PY'
import subprocess

ext = "user-theme@gnome-shell-extensions.gcampax.github.com"
try:
    out = subprocess.run(
        ["gsettings", "get", "org.gnome.shell", "enabled-extensions"],
        capture_output=True, text=True, check=False,
    ).stdout.strip()
except Exception:
    out = ""
cur = [item.strip().strip("'") for item in out.strip("[]").split(",") if item.strip()]
if ext not in cur:
    cur.append(ext)
value = "[" + ", ".join("'" + item + "'" for item in cur) + "]"
subprocess.run(["gsettings", "set", "org.gnome.shell", "enabled-extensions", value], check=False)
PY
  g set org.gnome.shell.extensions.user-theme name "$THEME"
fi

mkdir -p "$HOME/.config"
touch "$HOME/.config/gnome-initial-setup-pending"

echo "=== ancoros apply-look done $(date -Is) ==="
exit 0