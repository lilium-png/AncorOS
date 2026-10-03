#!/bin/bash
set -u
W=/home/builder/work
mkdir -p "$W/debs"
cd "$W/debs"
echo "=== Microsoft repo for resolute ==="
for codename in 26.04 25.10 25.04 24.04; do
  code=$(curl -s -o /dev/null -w '%{http_code}' -L "https://packages.microsoft.com/config/ubuntu/$codename/packages-microsoft-prod.deb")
  echo "$codename -> $code"
done
echo "=== download debs ==="
curl -sSL -o chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && echo chrome-ok
curl -sSL -o steam.deb https://repo.steampowered.com/steam/archive/stable/steam_latest.deb && echo steam-ok
curl -sSL -o tgwsproxy.deb https://github.com/Flowseal/tg-ws-proxy/releases/latest/download/TgWsProxy_linux_amd64.deb && echo tgws-ok
curl -sSL -o incy.deb https://github.com/INCY-DEV/incy-platforms/releases/latest/download/incy-linux-x64.deb && echo incy-ok
curl -sSL -o vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" && echo vscode-ok
ls -la
echo "=== tgwsproxy contents ==="
dpkg-deb -c tgwsproxy.deb 2>/dev/null | head -30
echo "=== tgwsproxy control ==="
dpkg-deb -I tgwsproxy.deb 2>/dev/null | head -30
echo "=== incy contents ==="
dpkg-deb -c incy.deb 2>/dev/null | head -25
echo "=== incy control ==="
dpkg-deb -I incy.deb 2>/dev/null | head -25
echo "=== steam control ==="
dpkg-deb -I steam.deb 2>/dev/null | head -20
echo "=== sober flathub ==="
curl -s -o /dev/null -w 'sober app: %{http_code}\n' https://flathub.org/api/v2/appstream/org.vinegarhq.Sober
curl -s https://flathub.org/api/v2/appstream/org.vinegarhq.Sober | head -c 400; echo
echo "=== nodesource ==="
curl -s -o /dev/null -w 'nodesource 26.x: %{http_code}\n' -L https://deb.nodesource.com/node_24.x/nodistro.list
echo "=== done ==="