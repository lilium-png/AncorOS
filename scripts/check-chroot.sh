#!/bin/bash
LOG=/home/builder/work/finish-chroot.log
echo "=== package audit ==="
grep -n "############ package audit" "$LOG" | head -1
awk '/############ package audit/{flag=1;next}/############ cleanup/{flag=0}flag' "$LOG"
echo "=== flatpak ==="
awk '/############ flatpak sober/{flag=1;next}/############ package audit/{flag=0}flag' "$LOG" | tail -14
echo "=== verification ==="
awk '/############ verification/{flag=1;next}/############ size/{flag=0}flag' "$LOG"
echo "=== interim repair ==="
awk '/############ interrupted install repair/{flag=1;next}/############ fonts/{flag=0}flag' "$LOG"
echo "=== chrome sandbox caps ==="
R=/home/builder/work/mnt/merged
sudo ls -la "$R/opt/google/chrome/chrome-sandbox" 2>&1
sudo getfattr -d -m - "$R/opt/google/chrome/chrome-sandbox" 2>&1 | head -3
echo "=== toolkits present ==="
for p in /usr/bin/google-chrome /usr/bin/steam /usr/bin/tg-ws-proxy /opt/incy/bin/incy /usr/bin/code /usr/bin/pwsh /usr/bin/wt /usr/bin/docker /usr/bin/nvim /usr/bin/node /usr/bin/python3 /usr/bin/obs /usr/bin/telegram-desktop; do
  if [ -e "$R$p" ] || [ -L "$R$p" ]; then echo "OK   $p"; else echo "MISS $p"; fi
done