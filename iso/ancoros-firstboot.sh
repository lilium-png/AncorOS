#!/usr/bin/env bash
set -uo pipefail

LOGFILE=/var/log/ancoros-firstboot.log
MARKER=/var/lib/ancoros-firstboot.done
mkdir -p /var/lib
if [ -f "$MARKER" ]; then
  exit 0
fi
exec >>"$LOGFILE" 2>&1
echo "=== ancoros firstboot start $(date -Is) ==="

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
export NEEDRESTART_SUSPEND=1
APT_OPTS="-y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -o Acquire::Retries=5"

TARGET_USER="ubuntu"
for u in $(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}'); do
  TARGET_USER="$u"
done
echo "target user: $TARGET_USER"

as_user() {
  runuser -u "$TARGET_USER" -- bash -lc "$1"
}

step() {
  echo "--- $* [$(date -Is)] ---"
}

wait_for_network() {
  local i
  for i in $(seq 1 60); do
    if getent hosts archive.ubuntu.com >/dev/null 2>&1; then
      echo "network ready after ${i} tries"
      return 0
    fi
    sleep 5
  done
  echo "network timeout"
  return 1
}

wait_for_network

step "apt update"
apt-get $APT_OPTS update

step "base packages"
apt-get $APT_OPTS install --no-install-recommends \
  ca-certificates curl wget gnupg apt-transport-https software-properties-common \
  git build-essential python3 python3-pip python3-venv python-is-python3 \
  nodejs npm \
  neovim htop tmux zsh fzf ripgrep bat jq yq tree unzip p7zip-full rsync xorriso \
  dosfstools gdisk flatpak gnome-tweaks fontconfig \
  gnome-shell-extension-user-theme \
  fonts-comfortaa fonts-inter \
  xterm \
  xdg-utils

step "optional cli tools"
apt-get $APT_OPTS install --no-install-recommends neofetch || apt-get $APT_OPTS install --no-install-recommends fastfetch || true
apt-get $APT_OPTS install --no-install-recommends exa || apt-get $APT_OPTS install --no-install-recommends eza || true
apt-get $APT_OPTS install --no-install-recommends lazygit || true
apt-get $APT_OPTS install --no-install-recommends httpie || true

step "telegram and obs"
apt-get $APT_OPTS install --no-install-recommends telegram-desktop obs-studio || echo "telegram/obs stage finished with errors"

step "docker repository"
if curl -fsSL -o /dev/null "https://download.docker.com/linux/ubuntu/dists/resolute/Release"; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu resolute stable" > /etc/apt/sources.list.d/docker.list
  apt-get $APT_OPTS update
  apt-get $APT_OPTS install --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || echo "docker-ce stage failed"
else
  echo "docker repo has no resolute suite, using archive packages"
  apt-get $APT_OPTS install --no-install-recommends docker.io docker-compose-v2 || echo "docker.io stage failed"
fi

step "microsoft repository"
curl -fsSL -o /tmp/packages-microsoft-prod.deb https://packages.microsoft.com/config/ubuntu/26.04/packages-microsoft-prod.deb && dpkg -i /tmp/packages-microsoft-prod.deb || echo "ms prod deb failed"
apt-get $APT_OPTS update
apt-get $APT_OPTS install --no-install-recommends powershell windows-terminal || echo "powershell/winterm stage failed"

step "deb packages"
mkdir -p /tmp/ancoros-debs
cd /tmp/ancoros-debs || exit 0
curl -fsSL -o google-chrome-stable_current_amd64.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb || echo "chrome download failed"
curl -fsSL -o steam_latest.deb https://repo.steampowered.com/steam/archive/stable/steam_latest.deb || echo "steam download failed"
curl -fsSL -o TgWsProxy_linux_amd64.deb https://github.com/Flowseal/tg-ws-proxy/releases/latest/download/TgWsProxy_linux_amd64.deb || echo "tgwsproxy download failed"
curl -fsSL -o incy-linux-x64.deb https://github.com/INCY-DEV/incy-platforms/releases/latest/download/incy-linux-x64.deb || echo "incy download failed"
curl -fsSL -o code_linux-deb-x64.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" || echo "vscode download failed"
for d in *.deb; do
  [ -e "$d" ] || continue
  echo "dpkg -i $d"
  dpkg -i "$d" || echo "dpkg failed on $d"
done
apt-get $APT_OPTS -f install || echo "apt-get -f install finished with errors"
apt-get $APT_OPTS install --no-install-recommends libgtk-3-0 libayatana-appindicator3-1 python3-tk || true

step "tg-ws-proxy service"
if [ -x /usr/bin/tg-ws-proxy ]; then
  cat > /usr/lib/systemd/user/tg-ws-proxy.service <<'UNIT'
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
  systemctl --global enable tg-ws-proxy.service || echo "systemctl --global enable failed"
fi

step "flatpak sober"
if command -v flatpak >/dev/null 2>&1; then
  as_user "flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" || true
  as_user "flatpak install --user -y --noninteractive flathub org.vinegarhq.Sober" || echo "sober install failed"
fi

step "oh-my-zsh"
if [ ! -d /usr/share/oh-my-zsh ]; then
  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh || echo "ohmyzsh clone failed"
fi
if [ -d /usr/share/oh-my-zsh ]; then
  for u in $(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}'); do
    h=$(getent passwd "$u" | cut -d: -f6)
    if [ -d "$h" ]; then
      cp -f /usr/share/oh-my-zsh/templates/zshrc.zsh-template "$h/.zshrc" 2>/dev/null || true
      chown "$u:$u" "$h/.zshrc" 2>/dev/null || true
    fi
  done
fi

step "user groups"
usermod -aG docker "$TARGET_USER" || true
usermod -aG video "$TARGET_USER" || true
usermod -aG render "$TARGET_USER" || true

step "oh-my-zsh default shell"
chsh -s /usr/bin/zsh "$TARGET_USER" || true

step "look for $TARGET_USER"
if [ -x /usr/local/bin/ancoros-apply-look.sh ]; then
  as_user "/usr/local/bin/ancoros-apply-look.sh" || echo "apply-look failed"
fi

step "first login polish"
for u in $(getent passwd | awk -F: '$3>=1000 && $3<65534 {print $1}'); do
  h=$(getent passwd "$u" | cut -d: -f6)
  [ -d "$h" ] || continue
  mkdir -p "$h/.config"
  touch "$h/.config/gnome-initial-setup-pending"
  chown -R "$u:$u" "$h/.config" 2>/dev/null || true
done

step "cleanup"
apt-get $APT_OPTS autoremove --purge || true
apt-get $APT_OPTS clean || true
rm -rf /var/lib/apt/lists/* || true
rm -rf /tmp/ancoros-debs || true

date -Is > "$MARKER"
echo "=== ancoros firstboot done $(date -Is) ==="
exit 0