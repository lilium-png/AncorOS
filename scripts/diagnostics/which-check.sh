#!/bin/bash
echo "=== command -v (inside VM) ==="
for c in qemu-system-x86_64 cubic xorriso debootstrap proot fakeroot unsquashfs mksquashfs dpkg apt-get; do
  p=$(command -v "$c" 2>/dev/null)
  if [ -n "$p" ]; then
    echo "$c -> $p"
  else
    echo "$c -> (empty) NOT INSTALLED"
  fi
done
echo "=== dpkg-query for build tools ==="
for p in cubic proot fakeroot debootstrap xorriso squashfs-tools; do
  v=$(dpkg-query -W -f='${Version}' "$p" 2>/dev/null)
  echo "$p ${v:-NOT INSTALLED}"
done
echo "=== df -h / ==="
df -h /
echo "=== whoami / sudo ==="
whoami
sudo -n id -u
echo "=== chroot test as non-root (this VM user) ==="
sudo mkdir -p /home/builder/work/chroottest
sudo mount --bind /home/builder/work/mnt/merged /home/builder/work/chroottest 2>/dev/null || true
chroot /home/builder/work/chroottest /bin/bash -c 'echo CHROOT_AS_USER_OK' 2>&1 | head -2
sudo umount /home/builder/work/chroottest 2>/dev/null || true
echo "=== chroot test as root (sudo) ==="
sudo chroot /home/builder/work/chroottest /bin/bash -c 'echo CHROOT_AS_ROOT_OK; cat /etc/os-release | head -2' 2>&1 | head -4
sudo umount /home/builder/work/chroottest 2>/dev/null || true
echo "=== done ==="