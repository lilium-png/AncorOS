#!/bin/bash
echo "=== initrd: casper scripts that mount squashfs ==="
lsinitramfs /home/builder/work/original.iso 2>/dev/null | grep -i casper | head -5 || true
echo "=== extract initrd from original iso and grep layerfs ==="
cd /home/builder/work
rm -rf /home/builder/initrd-x
mkdir -p /home/builder/initrd-x
sudo dd if=/home/builder/work/original.iso of=/home/builder/initrd.img bs=1M skip=1 count=200 status=none 2>/dev/null || true
ls -la /home/builder/initrd.img 2>/dev/null | head -2
if [ -f /home/builder/initrd.img ]; then
  cd /home/builder/initrd-x
  cpio -idm --quiet < /home/builder/initrd.img 2>/dev/null || zstd -dc /home/builder/initrd.img 2>/dev/null | cpio -idm --quiet 2>/dev/null || true
  echo "--- extracted entries: ---"
  ls | head -10
  echo "--- default-layer.conf ---"
  cat conf/conf.d/default-layer.conf 2>/dev/null || echo "MISSING default-layer.conf"
  echo "--- casper.conf ---"
  cat etc/casper.conf 2>/dev/null | head -10
  echo "--- grep LAYERFS in scripts ---"
  grep -rn 'LAYERFS_PATH' scripts 2>/dev/null | head -10
  echo "--- grep minimal.standard ---"
  grep -rn 'minimal.standard\|install-sources' scripts etc conf 2>/dev/null | head -15
fi
echo "=== what casper looks for: full casper script section ==="
sed -n '595,650p' /home/builder/initrd-x/scripts/casper 2>/dev/null | head -60
echo CMP-INITRD-DONE