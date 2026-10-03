#!/bin/bash
set -u
R=/home/builder/work/mnt/merged
echo "=== flathub sober via api ==="
curl -s -A 'Mozilla/5.0' -o /dev/null -w 'appstream: %{http_code}\n' https://flathub.org/api/v2/appstream/org.vinegarhq.Sober
curl -s -A 'Mozilla/5.0' -o /dev/null -w 'summary: %{http_code}\n' https://flathub.org/api/v2/summary/org.vinegarhq.Sober
echo "=== flathub repo reachability ==="
curl -s -o /dev/null -w 'flathub repo: %{http_code}\n' https://dl.flathub.org/repo/flathub.flatpakrepo
echo "=== nodesource ==="
curl -s -o /dev/null -w 'ns deb 24.x: %{http_code}\n' -L https://deb.nodesource.com/node_24.x/nodesource-release_24.x.deb
curl -s -o /dev/null -w 'ns deb 22.x: %{http_code}\n' -L https://deb.nodesource.com/node_22.x/nodesource-release_22.x.deb
echo "=== ptyxis provides ==="
grep -E '^(Package|Provides|Depends|Recommends):' "$R/var/lib/dpkg/info/ptyxis.control" 2>/dev/null
cat "$R/var/lib/dpkg/info/ptyxis.control" 2>/dev/null | head -25
echo "=== ptyxis desktop Exec spec ==="
grep -Rhs 'Exec=' "$R/usr/share/applications/"*ptyxis* 2>/dev/null | head -5
ls "$R/usr/share/applications" | grep -i -E 'terminal|ptyxis'
echo "=== flatpak remotes in image ==="
ls "$R/var/lib/flatpak/repo" 2>/dev/null || echo "no system flatpak repo"
cat "$R/etc/flatpak/remotes.d"/* 2>/dev/null | head -5
echo "=== gnome-software flatpak plugin ==="
dpkg-query --admindir="$R/var/lib/dpkg" -W -f='${Package} ${Version}\n' gnome-software-plugin-flatpak flatpak 2>/dev/null
echo "=== x-terminal-emulator alternative ==="
ls -la "$R/etc/alternatives/" | grep -i -E 'terminal|editor' | head -5
echo "=== fonts-comfortaa / fonts-inter in archive? ==="
grep -E '^Package: fonts-(comfortaa|inter)' -A2 "$R/var/lib/apt/lists/"*Packages 2>/dev/null | head -20
echo "=== done ==="