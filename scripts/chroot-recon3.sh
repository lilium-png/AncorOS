#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
echo "=== coreutils package files (bin) ==="
grep -E '^/usr/bin/' "$R/var/lib/dpkg/info/coreutils.list" 2>/dev/null | head -15
echo "=== rust-coreutils package files (bin) ==="
grep -E '^/usr/bin/' "$R/var/lib/dpkg/info/rust-coreutils.list" 2>/dev/null | head -15
echo "=== gnu binaries anywhere ==="
find "$R/usr" -maxdepth 3 -name 'gnu-*' -type f 2>/dev/null | head -20
echo "=== finalrd --help ==="
sudo chroot "$R" /usr/bin/finalrd --help 2>&1 | head -40
echo "=== finalrd-static.conf ==="
cat "$R/usr/lib/finalrd/finalrd-static.conf" 2>/dev/null
echo "=== packages with 'installer' in name ==="
grep -E '^Package: .*install' "$R/var/lib/dpkg/status" | sort -u | head -20
echo "=== strings in finalrd binary: assets/branding/slides ==="
strings "$R/usr/bin/finalrd" 2>/dev/null | grep -Ei 'branding|slides|install-sources|ubuntu-desktop-installer|flutter|assets' | head -30
echo "=== cubic availability ==="
sudo apt-get install -y -qq software-properties-common >/dev/null 2>&1 || true
sudo add-apt-repository -y ppa:cubic-dev/cubic-nightly 2>&1 | tail -3
sudo apt-get update -qq 2>&1 | tail -5
apt-cache policy cubic 2>&1 | head -10
echo "=== done ==="