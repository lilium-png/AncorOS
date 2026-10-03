#!/bin/bash
set -u
L=/home/builder/work/layers
LOG=/home/builder/work/check-layers.log
exec > >(tee -a "$LOG") 2>&1

for f in minimal minimal.standard minimal.standard.live; do
  echo "########## $f.squashfs ##########"
  sudo unsquashfs -ll "$L/$f.squashfs" 2>/dev/null > /tmp/list-$f.txt
  echo "entries: $(wc -l < /tmp/list-$f.txt)"
  echo "--- top level dirs ---"
  sed 's|^||' /tmp/list-$f.txt | awk -F/ '{print $1}' | sort -u | head -40
  echo "--- probes ---"
  for p in usr/bin/mktemp usr/sbin/debconf-communicate usr/lib/systemd/systemd usr/share/gnome-shell usr/share/debconf/confmodule sbin/init bin/mktemp usr/sbin/install-keymap; do
    c=$(grep -c "/$p\$" /tmp/list-$f.txt)
    echo "$p -> $c"
  done
  echo
done
echo "CHECK-LAYERS-DONE"