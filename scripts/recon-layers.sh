#!/bin/bash
set -u
echo "=== casper listing ==="
ls -la /mnt/iso/casper | grep -E 'squashfs|vmlinuz|initrd|md5|dir'
echo "=== pool tree (dirs only, depth 5) ==="
find /mnt/iso/pool -maxdepth 6 -type d | head -40
echo "=== pool squashfs files ==="
find /mnt/iso/pool -name '*.squashfs' -printf '%s %p\n' | sort -k2 | head -40
echo "=== EFI dir ==="
find /mnt/iso/EFI -maxdepth 3 | head -20
echo "=== initrd listing: layer-related ==="
lsinitramfs /mnt/iso/casper/initrd 2>/dev/null | grep -Ei 'install-sources|overlay|layer|casper|live-rootfs|squashfs' | head -40
echo "=== done ==="