#!/bin/bash
set -u
L=/home/builder/work/layers
LOG=/home/builder/work/verify-wrapper.log
exec > >(tee -a "$LOG") 2>&1

probe() {
  local img="$1" label="$2"
  local tmp=/tmp/probe-$$.txt
  sudo unsquashfs -ll "$img" 2>/dev/null > "$tmp"
  echo "===== $label ====="
  echo "entries: $(wc -l < "$tmp")"
  echo "squashfs-root lines: $(grep -c 'squashfs-root' "$tmp")"
  echo "squashfs-root/usr/lib/: $(grep -c 'squashfs-root/usr/lib/' "$tmp")"
  echo "squashfs-root/usr/share/: $(grep -c 'squashfs-root/usr/share/' "$tmp")"
  echo "squashfs-root/usr/bin/: $(grep -c 'squashfs-root/usr/bin/' "$tmp")"
  echo "squashfs-root/etc/: $(grep -c 'squashfs-root/etc/' "$tmp")"
  echo "squashfs-root/var/: $(grep -c 'squashfs-root/var/' "$tmp")"
  echo "squashfs-root/boot/: $(grep -c 'squashfs-root/boot/' "$tmp")"
  echo "systemd binary: $(grep -c 'squashfs-root/usr/lib/systemd/systemd$' "$tmp")"
  echo "bash binary:     $(grep -c 'squashfs-root/usr/bin/bash$' "$tmp")"
  echo "gnome-shell:     $(grep -c 'squashfs-root/usr/share/gnome-shell$' "$tmp")"
  echo "bin_1 entries:   $(grep -c '/bin_1/' "$tmp")"
  echo "bare usr/ lines: $(grep -c ' usr/' "$tmp")"
  sudo rm -f "$tmp"
}

sudo mkdir -p /tmp/ubiso
sudo mount -o loop,ro /dev/sr0 /tmp/ubiso 2>/dev/null

probe /tmp/ubiso/casper/minimal.squashfs "UBUNTU original minimal.squashfs"
probe /tmp/ubiso/casper/minimal.standard.squashfs "UBUNTU original minimal.standard.squashfs"
probe /tmp/ubiso/casper/minimal.standard.live.squashfs "UBUNTU original minimal.standard.live.squashfs"
probe "$L/minimal.squashfs" "MY minimal.squashfs"
probe "$L/minimal.standard.squashfs" "MY minimal.standard.squashfs"
probe "$L/minimal.standard.live.squashfs" "MY minimal.standard.live.squashfs"
echo "VERIFY-DONE"