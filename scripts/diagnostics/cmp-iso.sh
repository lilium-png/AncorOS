#!/bin/bash
mkdir -p /home/builder/cmp
if ! mountpoint -q /home/builder/cmp/orig; then
  sudo mkdir -p /home/builder/cmp/orig /home/builder/cmp/mine
  sudo cp /home/builder/work/original.iso /home/builder/work/AncorOS-26.04-amd64.iso /home/builder/cmp/ 2>/dev/null || true
  sudo mount -o loop,ro /home/builder/cmp/original.iso /home/builder/cmp/orig
  sudo mount -o loop,ro /home/builder/cmp/AncorOS-26.04-amd64.iso /home/builder/cmp/mine
fi
echo "=== casper: ORIGINAL ==="
ls -la /home/builder/cmp/orig/casper | head -14
echo "=== casper: MINE ==="
ls -la /home/builder/cmp/mine/casper | head -14
echo "=== boot/grub/i386-pc sizes ==="
ls -la /home/builder/cmp/orig/boot/grub/i386-pc/eltorito.img /home/builder/cmp/mine/boot/grub/i386-pc/eltorito.img 2>&1
echo "=== md5 of eltorito.img ==="
md5sum /home/builder/cmp/orig/boot/grub/i386-pc/eltorito.img /home/builder/cmp/mine/boot/grub/i386-pc/eltorito.img 2>&1
echo "=== vmlinuz / initrd ==="
ls -la /home/builder/cmp/orig/casper/vmlinuz /home/builder/cmp/mine/casper/vmlinuz /home/builder/cmp/orig/casper/initrd /home/builder/cmp/mine/casper/initrd 2>&1
echo "=== grub.cfg diff ==="
diff /home/builder/cmp/orig/boot/grub/grub.cfg /home/builder/cmp/mine/boot/grub/grub.cfg
echo "=== El Torito catalog sector compare ==="
sudo dd if=/home/builder/cmp/original.iso of=/home/builder/cmp/orig.cat bs=2048 skip=672 count=1 status=none
sudo dd if=/home/builder/cmp/AncorOS-26.04-amd64.iso of=/home/builder/cmp/mine.cat bs=2048 skip=628 count=1 status=none
xxd /home/builder/cmp/orig.cat | head -6
echo "--- mine ---"
xxd /home/builder/cmp/mine.cat | head -6
echo "=== LAYERFS_PATH in initrd (original vs mine) ==="
for iso in original AncorOS-26.04-amd64; do
  echo "--- $iso ---"
  sudo dd if=/home/builder/cmp/$iso.iso of=/tmp/i-$iso.cpio bs=2048 skip=0 count=0 status=none
  lsinitramfs /home/builder/cmp/$iso.iso 2>/dev/null | head -1 || echo "cannot read initrd from iso directly"
done
echo "CMP-DONE"