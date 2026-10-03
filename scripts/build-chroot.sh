#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
T="$W/themes"
LOG="$W/build-chroot.log"
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
df -h /home/builder | tail -1
sudo mountpoint -q "$R/proc" && echo "proc bind ok"

step "apt sources"
sudo rm -f "$R/etc/apt/sources.list.d/cdrom.sources"
sudo rm -f "$R/etc/apt/sources.list"
cat > /home/builder/work/99-ancoros.sources <<'EOF'
Types: deb
URIs: http://archive.ubuntu.com/ubuntu/
Suites: resolute resolute-updates resolute-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: resolute-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
sudo cp /home/builder/work/99-ancoros.sources "$R/etc/apt/sources.list.d/99-ancoros.sources"
sudo rm -f "$R/etc/apt/sources.list.d/ubuntu.sources"

step "apt update"
c /usr/bin/apt-get $APT_OPTS update || echo "apt update had errors"

step "xterm for steam dependency"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends xterm || echo "xterm install failed"

step "desktop and cli tooling"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends \
  git ca-certificates curl wget gnupg apt-transport-https software-properties-common \
  build-essential python3 python3-pip python3-venv python-is-python3 \
  nodejs npm neovim htop tmux zsh fzf ripgrep bat jq yq tree unzip p7zip-full rsync \
  xorriso dosfstools gdisk fontconfig gnome-tweaks flatpak \
  gnome-shell-extension-user-theme fonts-comfortaa fonts-inter || echo "main tooling had errors"

step "optional cli extras"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends neofetch || c /usr/bin/apt-get $APT_OPTS install --no-install-recommends fastfetch || echo "no neofetch/fastfetch"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends exa || c /usr/bin/apt-get $APT_OPTS install --no-install-recommends eza || echo "no exa/eza"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends lazygit || echo "no lazygit"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends httpie || echo "no httpie"

step "messaging and streaming"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends telegram-desktop obs-studio || echo "telegram/obs had errors"

step "docker"
if curl -fsSL -o /dev/null "https://download.docker.com/linux/ubuntu/dists/resolute/Release"; then
  echo "docker repo supports resolute"
  c /usr/bin/bash -c 'install -m 0755 -d /etc/apt/keyrings; curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc; chmod a+r /etc/apt/keyrings/docker.asc; echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu resolute stable" > /etc/apt/sources.list.d/docker.list'
  c /usr/bin/apt-get $APT_OPTS update
  c /usr/bin/apt-get $APT_OPTS install --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || echo "docker-ce had errors"
else
  echo "docker repo has no resolute suite"
  c /usr/bin/apt-get $APT_OPTS install --no-install-recommends docker.io docker-compose-v2 || echo "docker.io had errors"
fi

step "microsoft repository"
c /usr/bin/bash -c 'curl -fsSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb && dpkg -i /tmp/packages-microsoft-prod.deb && rm -f /tmp/packages-microsoft-prod.deb' || echo "ms prod deb failed"
c /usr/bin/apt-get $APT_OPTS update
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends powershell windows-terminal || echo "powershell/winterm had errors"

step "deb payloads"
sudo mkdir -p "$R/tmp/ancoros-debs"
sudo cp -a "$W/debs/." "$R/tmp/ancoros-debs/" 2>/dev/null || echo "deb copy failed"
sudo mv -f "$R/tmp/ancoros-debs/chrome.deb" "$R/tmp/ancoros-debs/google-chrome-stable_current_amd64.deb" 2>/dev/null || true
sudo mv -f "$R/tmp/ancoros-debs/steam.deb" "$R/tmp/ancoros-debs/steam_latest.deb" 2>/dev/null || true
sudo mv -f "$R/tmp/ancoros-debs/tgwsproxy.deb" "$R/tmp/ancoros-debs/TgWsProxy_linux_amd64.deb" 2>/dev/null || true
sudo mv -f "$R/tmp/ancoros-debs/incy.deb" "$R/tmp/ancoros-debs/incy-linux-x64.deb" 2>/dev/null || true
sudo mv -f "$R/tmp/ancoros-debs/vscode.deb" "$R/tmp/ancoros-debs/code_linux-deb-x64.deb" 2>/dev/null || true
for d in google-chrome-stable_current_amd64.deb steam_latest.deb TgWsProxy_linux_amd64.deb incy-linux-x64.deb code_linux-deb-x64.deb; do
  if [ -f "$R/tmp/ancoros-debs/$d" ]; then
    echo "--- dpkg -i $d ---"
    c /usr/bin/dpkg -i "/tmp/ancoros-debs/$d" || echo "dpkg failed: $d"
  else
    echo "missing deb: $d"
  fi
done
c /usr/bin/apt-get $APT_OPTS -f install || echo "apt -f had errors"
c /usr/bin/apt-get $APT_OPTS install --no-install-recommends libgtk-3-0t64 libayatana-appindicator3-1 python3-tk || echo "extra deps had errors"

step "tg-ws-proxy systemd user unit"
sudo tee "$R/usr/lib/systemd/user/tg-ws-proxy.service" > /dev/null <<'UNIT'
[Unit]
Description=Telegram Desktop WebSocket bridge proxy
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/tg-ws-proxy
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
UNIT
sudo mkdir -p "$R/etc/systemd/user/default.target.wants"
sudo ln -sf /usr/lib/systemd/user/tg-ws-proxy.service "$R/etc/systemd/user/default.target.wants/tg-ws-proxy.service"

step "oh-my-zsh system copy"
if [ ! -d "$R/usr/share/oh-my-zsh" ]; then
  sudo git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$R/usr/share/oh-my-zsh" || echo "ohmyzsh clone failed"
fi

step "whitesur gtk theme"
sudo rm -rf "$R/usr/share/themes/WhiteSur-Dark"
sudo cp -a "$T/extracted/WhiteSur-Dark" "$R/usr/share/themes/WhiteSur-Dark"
ls "$R/usr/share/themes/WhiteSur-Dark" | tr '\n' ' '
echo

step "whitesur darker overrides"
for ver in gtk-3.0 gtk-4.0; do
  f="$R/usr/share/themes/WhiteSur-Dark/$ver/gtk.css"
  if [ -f "$f" ]; then
    cat >> "$f" <<'CSS'

@define-color theme_bg_color #1b1a22;
@define-color bg_color #1b1a22;
@define-color content_view_bg #131218;
@define-color insensitive_base_color #131218;
@define-color theme_unfocused_bg_color #17161d;
@define-color theme_unfocused_base_color #131218;
@define-color theme_fg_color #ece9f5;
@define-color fg_color #ece9f5;
@define-color text_color #ece9f5;
@define-color theme_text_color #ece9f5;
@define-color theme_unfocused_fg_color #b9b5c6;
@define-color theme_unfocused_text_color #b9b5c6;
@define-color borders rgba(255,255,255,0.08);
@define-color unfocused_borders rgba(255,255,255,0.05);
@define-color placeholder_text_color #ffb782;
@define-color selected_bg_color #5b7cfa;
@define-color theme_selected_bg_color #5b7cfa;
@define-color accent_color #5b7cfa;
@define-color accent_bg_color #5b7cfa;
@define-color accent_fg_color #ffffff;
@define-color wm_bg #1e1d26;
@define-color wm_bg_unfocused mix(black,#1e1d26,0.99);
@define-color wm_border_focused #0a0a0e;
@define-color wm_border_unfocused #0d0d11;
@define-color wm_highlight #3b3948;
@define-color wm_shadow rgba(0,0,0,0.55);
@define-color window_bg_color #1b1a22;
@define-color window_fg_color #ece9f5;
@define-color headerbar_bg_color #1e1d26;
@define-color headerbar_fg_color #ece9f5;
@define-color headerbar_border_color #0d0d11;
@define-color headerbar_backdrop_color #1b1a22;
@define-color sidebar_bg_color rgba(27,26,34,0.96);
@define-color sidebar_fg_color #ece9f5;
@define-color sidebar_border_color #0d0d11;
@define-color sidebar_backdrop_color #1b1a22;
@define-color card_bg_color #131218;
@define-color card_fg_color #ece9f5;
@define-color dialog_bg_color alpha(#131218,0.96);
@define-color dialog_fg_color #ece9f5;
@define-color popover_bg_color rgba(31,30,40,0.96);
@define-color popover_fg_color #ece9f5;
@define-color menu_bg_color #1b1a22;
@define-color menu_fg_color #ece9f5;
@define-color osd_bg_color rgba(24,22,32,0.92);
@define-color osd_fg_color #ece9f5;
@define-color view_bg_color #1b1a22;
@define-color view_fg_color #ece9f5;
@define-color text_view_bg_color #131218;
@define-color backdrop_base_color #17161d;
@define-color backdrop_bg_color #17161d;
@define-color backdrop_fg_color #b9b5c6;
@define-color backdrop_text_color #b9b5c6;
@define-color link_color #7aa2ff;
CSS
    echo "darker overrides appended to $ver/gtk.css"
  else
    echo "missing $f"
  fi
done

step "whitesur gnome-shell theme"
shell_css="$R/usr/share/themes/WhiteSur-Dark/gnome-shell/gnome-shell.css"
if [ -f "$shell_css" ]; then
  cat >> "$shell_css" <<'CSS'

stage {
  --window-background: rgba(27, 26, 34, 0.98);
  --window-unfocused-background: rgba(23, 22, 29, 0.98);
  --headerbar-background: rgba(30, 29, 38, 0.96);
  --headerbar-dark-background: rgba(30, 29, 38, 0.96);
  --headerbar-border-color: rgba(255, 255, 255, 0.06);
  --headerbar-backdrop-color: rgba(27, 26, 34, 0.98);
  --headerbar-highlight-color: rgba(255, 255, 255, 0.08);
  --headerbar-hover-highlight-color: rgba(255, 255, 255, 0.06);
  --panel-bgcolor: rgba(22, 21, 29, 0.55);
  --panel-border-color: rgba(255, 255, 255, 0.06);
  --panel-headerbar-highlight-color: rgba(255, 255, 255, 0.06);
  --panel-headerbar-hover-highlight-color: rgba(255, 255, 255, 0.04);
  --panel-menu-bg-color: rgba(27, 26, 34, 0.9);
  --card-background: rgba(24, 23, 31, 0.96);
  --card-fg-color: #ece9f5;
  --popover-background: rgba(24, 23, 31, 0.94);
  --menu-background: rgba(24, 23, 31, 0.92);
  --osd-background: rgba(24, 22, 32, 0.92);
  --osd-fg-color: #ece9f5;
  --osd-shadow-color: rgba(0, 0, 0, 0.6);
  --divider-color: rgba(255, 255, 255, 0.07);
  --text-color: #ece9f5;
  --secondary-text-color: #b9b5c6;
  --accent-color: #7aa2ff;
  --accent-fg-color: #ffffff;
  --accent-bg-color: #5b7cfa;
  --workspace-background: rgba(27, 26, 34, 0.9);
  --dnd-background: rgba(27, 26, 34, 0.98);
  --app-menu-background-color: rgba(24, 23, 31, 0.94);
  --quick-toggle-menu-background: rgba(24, 23, 31, 0.9);
  --input-slider-background-color: #3b3948;
  --scrollbar-slider-background-color: #3b3948;
  --scrollbar-slider-active-background-color: #565368;
  --scrollbar-slider-border-color: rgba(255, 255, 255, 0.08);
  --tooltip-background-color: rgba(40, 38, 50, 0.95);
  --tooltip-color: #ece9f5;
  --window-picker-background-color: #4c4a5e;
  --outer-shadow-color: rgba(0, 0, 0, 0.6);
  --dark-theme: true;
}
CSS
  echo "shell darker overrides appended"
else
  echo "shell css missing"
fi

step "whitesur icons"
sudo rm -rf "$R/usr/share/icons/WhiteSur-Dark"
sudo cp -a "$T/WhiteSur-icon-theme-master/src" "$R/usr/share/icons/WhiteSur-Dark"
ls "$R/usr/share/icons/WhiteSur-Dark" | tr '\n' ' '
echo

step "whitesur cursors"
sudo rm -rf "$R/usr/share/icons/WhiteSur-cursors"
sudo cp -a "$T/WhiteSur-cursors-master/dist" "$R/usr/share/icons/WhiteSur-cursors"
ls "$R/usr/share/icons/WhiteSur-cursors" | tr '\n' ' '
echo

step "wallpapers"
sudo mkdir -p "$R/usr/share/backgrounds"
for f in /home/builder/assets/*.png; do
  [ -e "$f" ] || continue
  sudo cp -f "$f" "$R/usr/share/backgrounds/$(basename "$f")"
done
sudo tee "$R/usr/share/gnome-background-properties/ancoros.xml" > /dev/null <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE wallpapers SYSTEM "gnome-wp-list.dtd">
<wallpapers>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore Dark</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-dark-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#1b1a22</pcolor>
    <scolor>#1b1a22</scolor>
  </wallpaper>
  <wallpaper deleted="false">
    <name>AncorOS Angelcore Light</name>
    <filename>/usr/share/backgrounds/ancoros-angelcore-light-3840x2160.png</filename>
    <options>zoom</options>
    <shade_type>solid</shade_type>
    <pcolor>#f6d6e2</pcolor>
    <scolor>#f6d6e2</scolor>
  </wallpaper>
</wallpapers>
XML
ls "$R/usr/share/backgrounds" | grep ancoros | tr '\n' ' '
echo

step "dconf system defaults"
sudo tee "$R/usr/share/glib-2.0/schemas/99-ancoros.gschema.override" > /dev/null <<'OVR'
[org.gnome.desktop.interface]
gtk-theme='WhiteSur-Dark'
color-scheme='prefer-dark'
icon-theme='WhiteSur-Dark'
cursor-theme='WhiteSur-cursors'
cursor-size=uint32 24
font-name='Comfortaa 11'
document-font-name='Comfortaa 11'
monospace-font-name='Ubuntu Mono 13'
enable-animations=true

[org.gnome.desktop.wm.preferences]
theme='Adwaita'
button-layout='close,minimize,maximize:'

[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/ancoros-angelcore-dark-1920x1080.png'
picture-uri-dark='file:///usr/share/backgrounds/ancoros-angelcore-dark-1920x1080.png'

[org.gnome.shell.extensions.dash-to-dock]
dock-position='BOTTOM'
dash-max-icon-size=64
icon-size-fixed=true
intellihide=true
intellihide-mode='ALL_WINDOWS'
dock-fixed=false
autohide=false
extend-height=false
force-straight-corner=false
apply-glossy-effect=false
custom-background-color=true
background-color='rgba(24,22,32,0.55)'
transparency-mode='FIXED'
show-trash=false
show-mounts=true
show-mounts-network=true
animation-time=0.15
click-action='focus-or-appspread'
scroll-action='switch-workspace'

[org.gnome.shell]
disabled-extensions=['tiling-assistant@ubuntu.com']

[org.gnome.desktop.a11y.interface]
tooltips=1
OVR
c /usr/bin/glib-compile-schemas /usr/share/glib-2.0/schemas && echo "schemas compiled" || echo "schema compile failed"

step "branding"
sudo sed -i 's/^NAME="Ubuntu"/NAME="AncorOS"/' "$R/etc/os-release" 2>/dev/null || true
sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="AncorOS 26.04.1 LTS"/' "$R/etc/os-release" 2>/dev/null || true
sudo sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="AncorOS"/' "$R/etc/lsb-release" 2>/dev/null || true
sudo sed -i 's/^DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION="AncorOS 26.04.1 LTS"/' "$R/etc/lsb-release" 2>/dev/null || true
printf 'AncorOS 26.04.1 LTS \\n \\l\n\n' > /home/builder/work/issue.tmp
sudo cp /home/builder/work/issue.tmp "$R/etc/issue"
rm -f /home/builder/work/issue.tmp
sudo tee "$R/etc/motd" > /dev/null <<'MOTD'

AncorOS 26.04.1 LTS - GNOME 50, Wayland only
Angelcore look powered by WhiteSur

MOTD
head -3 "$R/etc/os-release"

step "first boot scripts"
sudo cp -f /home/builder/ancoros-firstboot.sh "$R/usr/local/bin/ancoros-firstboot.sh"
sudo cp -f /home/builder/ancoros-apply-look.sh "$R/usr/local/bin/ancoros-apply-look.sh"
sudo chmod 0755 "$R/usr/local/bin/ancoros-firstboot.sh" "$R/usr/local/bin/ancoros-apply-look.sh"
sudo mkdir -p "$R/etc/xdg/autostart"
sudo tee "$R/etc/xdg/autostart/ancoros-apply-look.desktop" > /dev/null <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=AncorOS Look
Exec=/usr/local/bin/ancoros-apply-look.sh
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Phase=Applications
DESKTOP
sudo tee "$R/etc/systemd/system/ancoros-firstboot.service" > /dev/null <<'UNIT'
[Unit]
Description=AncorOS first boot configuration
After=network-online.target snapd.service
Wants=network-online.target

[Service]
Type=oneshot
Environment=DEBIAN_FRONTEND=noninteractive
ExecStart=/usr/local/bin/ancoros-firstboot.sh
TimeoutStartSec=0
RemainAfterExit=yes
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
UNIT
sudo mkdir -p "$R/etc/systemd/system/multi-user.target.wants"
sudo ln -sf /etc/systemd/system/ancoros-firstboot.service "$R/etc/systemd/system/multi-user.target.wants/ancoros-firstboot.service"

step "flatpak sober system wide"
if [ -x "$R/usr/bin/flatpak" ]; then
  sudo chroot "$R" /usr/bin/env DEBIAN_FRONTEND=noninteractive HOME=/root /usr/bin/bash -c 'flatpak remote-add --if-not-exists --system flathub https://dl.flathub.org/repo/flathub.flatpakrepo && flatpak install --system -y --noninteractive flathub org.vinegarhq.Sober' || echo "sober system install failed"
fi

step "final package check"
c /usr/bin/dpkg --audit || true
c /usr/bin/dpkg -l | grep -E '^i[^i]' | awk '{print $2, $3}' | head -40 || true

step "cleanup inside chroot"
c /usr/bin/apt-get $APT_OPTS clean || true
sudo rm -rf "$R/var/lib/apt/lists/"* || true
sudo rm -rf "$R/var/cache/apt/archives/"*.deb 2>/dev/null || true
sudo rm -rf "$R/tmp/ancoros-debs" || true
sudo rm -rf "$R/tmp/"* 2>/dev/null || true

step "theme verification"
ls -d "$R/usr/share/themes/WhiteSur-Dark" "$R/usr/share/icons/WhiteSur-Dark" "$R/usr/share/icons/WhiteSur-cursors" 2>&1
ls "$R/usr/share/gnome-shell/extensions" | tr '\n' ' '
echo

step "done"
du -sh --apparent-size "$R" 2>/dev/null | tail -1 || true
df -h /home/builder | tail -1
echo "BUILD-CHROOT-OK"