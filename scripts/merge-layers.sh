#!/bin/bash
set -eu
W=/home/builder/work
mkdir -p "$W/mnt/iso" "$W/upper" "$W/work" "$W/mnt/l0" "$W/mnt/l1" "$W/mnt/l2" "$W/mnt/merged"

if ! mountpoint -q "$W/mnt/iso"; then
  sudo mount -o loop,ro /dev/sr0 "$W/mnt/iso"
fi
if ! mountpoint -q "$W/mnt/l0"; then
  sudo mount -t squashfs -o loop,ro "$W/mnt/iso/casper/minimal.squashfs" "$W/mnt/l0"
fi
if ! mountpoint -q "$W/mnt/l1"; then
  sudo mount -t squashfs -o loop,ro "$W/mnt/iso/casper/minimal.standard.squashfs" "$W/mnt/l1"
fi
if ! mountpoint -q "$W/mnt/l2"; then
  sudo mount -t squashfs -o loop,ro "$W/mnt/iso/casper/minimal.standard.live.squashfs" "$W/mnt/l2"
fi
if ! mountpoint -q "$W/mnt/merged"; then
  sudo mount -t overlay overlay -o lowerdir="$W/mnt/l2:$W/mnt/l1:$W/mnt/l0",upperdir="$W/upper",workdir="$W/work" "$W/mnt/merged"
fi

sudo mkdir -p "$W/mnt/merged/proc" "$W/mnt/merged/sys" "$W/mnt/merged/dev" "$W/mnt/merged/run"
mountpoint -q "$W/mnt/merged/proc" || sudo mount --bind /proc "$W/mnt/merged/proc"
mountpoint -q "$W/mnt/merged/sys" || sudo mount --bind /sys "$W/mnt/merged/sys"
mountpoint -q "$W/mnt/merged/dev" || sudo mount --bind /dev "$W/mnt/merged/dev"
mountpoint -q "$W/mnt/merged/run" || sudo mount --bind /run "$W/mnt/merged/run"

echo "=== mounts ==="
mount | grep -E 'iso|l0|l1|l2|merged' | sed 's/lowerdir=[^,)]*/lowerdir=.../'
echo "=== merged apparent size ==="
sudo du -sh --apparent-size "$W/mnt/merged" 2>/dev/null | tail -1
echo "OK"