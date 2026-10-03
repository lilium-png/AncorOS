#!/bin/bash
set -u
LOG=/home/builder/work/layerfs-script.log
exec > >(tee -a "$LOG") 2>&1
step() { echo; echo "############ $*"; }

sudo mkdir -p /tmp/ubiso /tmp/initrd
sudo mount -o loop,ro /dev/sr0 /tmp/ubiso 2>/dev/null
cd /tmp/initrd || exit 1
sudo rm -rf /tmp/initrd/*

step "split initrd into sections"
sudo cp /tmp/ubiso/casper/initrd /tmp/initrd/initrd
python3 - <<'PY'
import sys
data = open('/tmp/initrd/initrd','rb').read()
off = 0
n = 0
while off < len(data) and n < 8:
    with open(f'/tmp/initrd/sec{n}.bin','wb') as f:
        f.write(data[off:])
    magic = data[off:off+6]
    print(f'sec{n} at {off} magic={magic.hex()} ({magic})')
    if magic[:4] == b'0707':
        # walk cpio to find end
        pos = off + 6
        while pos < len(data):
            # newc header: namesize at 94, filesize at 54
            try:
                namesize = int(data[pos+94:pos+102], 16)
                filesize = int(data[pos+54:pos+62], 16)
            except ValueError:
                break
            name = data[pos+110:pos+110+namesize-1].decode('ascii','replace')
            hdr = 110 + namesize
            hdr = (hdr + 3) & ~3
            pos += hdr + ((filesize + 3) & ~3)
            if name == 'TRAILER!!!':
                break
        print(f'  cpio ends at {pos}')
        off = pos
        n += 1
    elif magic[:4] == bytes([0x28,0xb5,0x2f,0xfd]):
        print('  zstd section, cannot walk further in python; stop')
        off = len(data)
        n += 1
    else:
        print('unknown magic, stop')
        off = len(data)
        n += 1
PY

step "decompress zstd section and list casper scripts"
Z=$(ls /tmp/initrd/sec*.bin | while read f; do if [ "$(head -c4 "$f" | xxd -p)" = "28b52ffd" ]; then echo "$f"; fi; done | head -1)
echo "zstd section: $Z"
if [ -n "$Z" ]; then
  sudo zstd -d -f -o /tmp/initrd/main.cpio "$Z" 2>&1 | tail -2
  ls -la /tmp/initrd/main.cpio
  echo "--- casper layerfs scripts ---"
  sudo cpio -itv < /tmp/initrd/main.cpio 2>/dev/null | grep -iE 'layerfs|casper$' | head -10
  echo "--- extract scripts dir listing ---"
  sudo cpio -it < /tmp/initrd/main.cpio 2>/dev/null | grep -E '^scripts/casper-bottom/' | head -40
fi
echo "LAYERFS-SCAN-DONE"