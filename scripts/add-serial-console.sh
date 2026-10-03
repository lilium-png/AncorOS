#!/bin/bash
set -u
W=/home/builder/work
TREE="$W/isotree"
LOG="$W/serial-console.log"

exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*  $(date -Is)"; }

step "current grub.cfg"
sudo cat "$TREE/boot/grub/grub.cfg"

step "add serial console to kernel command line"
sudo chown "$(id -un):$(id -gn)" "$TREE/boot/grub/grub.cfg" 2>/dev/null || sudo chmod u+w "$TREE/boot/grub/grub.cfg"
sudo sed -i 's| --- quiet splash| console=tty0 console=ttyS0,115200n8 --- quiet splash|g' "$TREE/boot/grub/grub.cfg"
grep 'vmlinuz' "$TREE/boot/grub/grub.cfg"

step "rebuild iso"
sudo rm -f "$W/AncorOS-26.04-amd64.iso"
xorriso -as mkisofs \
  -r -V "AncorOS 26.04.1 LTS amd64" -o "$W/AncorOS-26.04-amd64.iso" \
  -J -joliet-long \
  --grub2-mbr "$W/mbr.bin" \
  --protective-msdos-label \
  -partition_cyl_align off -partition_offset 16 --mbr-force-bootable \
  -append_partition 2 0xef "$W/efi_part.img" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2_start_0s_size_10296d:all::' \
  -no-emul-boot -boot-load-size 10296 \
  "$TREE" 2>&1 | tail -3
ls -la "$W/AncorOS-26.04-amd64.iso"

step "checksum"
sha256sum "$W/AncorOS-26.04-amd64.iso" | sudo tee "$W/AncorOS-26.04-amd64.iso.sha256"
echo "SERIAL-CONSOLE-OK"