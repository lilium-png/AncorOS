#!/bin/bash
ISO=/home/builder/work/AncorOS-26.04-amd64.iso
echo "=== xorriso -report_el_torito plain ==="
xorriso -indev "$ISO" -report_el_torito plain 2>&1 | tail -18
echo "=== sha256 from build ==="
cat "${ISO}.sha256"
echo "=== mount verify ==="
sudo mkdir -p /mnt/verify
sudo mount -o loop,ro "$ISO" /mnt/verify || { echo "MOUNT FAILED"; exit 1; }
ls /mnt/verify
echo "--- layers ---"
ls -la /mnt/verify/casper/*.squashfs
echo "--- install-sources ---"
head -12 /mnt/verify/casper/install-sources.yaml
echo "--- user-data head ---"
head -4 /mnt/verify/user-data
echo "--- autoinstall head ---"
head -4 /mnt/verify/autoinstall.yaml
echo "--- grub.cfg ---"
head -14 /mnt/verify/boot/grub/grub.cfg
echo "--- efi dir ---"
ls /mnt/verify/EFI/boot
sudo umount /mnt/verify
echo "VERIFY-DONE"