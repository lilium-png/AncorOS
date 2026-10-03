#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
ORIG="$W/original.iso"
LOG="$W/pack-iso2.log"

exec > >(tee -a "$LOG") 2>&1

step() { echo; echo "############ $*  $(date -Is)"; }

step "cleanup merged tree"
sudo rm -rf "$R/var/lib/snapd/seed"
sudo rm -rf "$R/usr/share/doc" "$R/usr/share/man" "$R/usr/share/info" "$R/usr/share/mythes"
sudo find "$R/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'ru*' -exec rm -rf {} + 2>/dev/null || true
sudo find "$R/usr/share/locale-langpack" -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'ru*' -exec rm -rf {} + 2>/dev/null || true
sudo rm -rf "$R/usr/share/backgrounds/contest"
sudo find "$R/usr/lib" -maxdepth 4 -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
sudo find "$R/usr/lib/python3" -maxdepth 3 -type d -name '__pycache__' -prune -exec rm -rf {} + 2>/dev/null || true
sudo rm -rf "$R/var/cache/apt" "$R/var/lib/apt/lists" "$R/var/log"/* 2>/dev/null || true
sudo du -sh "$R"
sudo du -sh "$R/usr/lib" "$R/usr/share" "$R/var" "$R/opt" 2>/dev/null

step "rebuild layers"
mkdir -p "$LAYERS"
rm -f "$LAYERS"/*.squashfs
mkdir -p "$LAYERS/empty"
mksquashfs "$LAYERS/empty" "$LAYERS/minimal.squashfs" -noappend -no-progress -comp zstd -Xcompression-level 1

SQ_OPTS="-noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M -xattrs -xattrs-exclude ^trusted\.overlay\..*"

cd "$R" || exit 1
echo "--- layer 1: usr/lib ---"
sudo mksquashfs usr/lib "$LAYERS/minimal.standard.squashfs" -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -4
echo "--- layer 2: usr/share ---"
sudo mksquashfs usr/share "$LAYERS/minimal.standard.live.squashfs" -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -4
echo "--- layer 3: rest ---"
ENTRIES=$(ls -A . | grep -v -E '^(usr|var)$' | tr '\n' ' ')
USRREST=$(ls -A usr | grep -v -E '^(lib|share)$' | sed 's|^|usr/|' | tr '\n' ' ')
echo "entries: $ENTRIES"
echo "usr rest: $USRREST"
sudo mksquashfs $ENTRIES $USRREST "$LAYERS/minimal.standard.live.extra.squashfs" -noappend -no-progress -processors 6 -comp zstd -Xcompression-level 15 -b 1M -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -4
cd "$W" || exit 1

ls -la "$LAYERS"/*.squashfs
for f in "$LAYERS"/*.squashfs; do
  s=$(stat -c %s "$f")
  if [ "$s" -ge 4000000000 ]; then
    echo "FATAL: $f is $s bytes, ISO9660 limit is 4 GiB"
    exit 1
  fi
  echo "ok $f $s bytes"
done

step "update iso tree"
test -d "$TREE/casper" || { echo "FATAL: iso tree missing"; exit 1; }
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
cp "$LAYERS/minimal.standard.live.extra.squashfs" "$TREE/casper/minimal.standard.live.extra.squashfs"
rm -f "$TREE"/casper/minimal*.manifest* "$TREE"/casper/minimal*.size
ls -la "$TREE/casper" | head -8

SIZE=$(stat -c %s "$TREE/casper/minimal.standard.live.extra.squashfs")
cat > "$TREE/casper/install-sources.yaml" <<EOF
version: 2
sources:
- default: true
  id: ubuntu-desktop
  variant: desktop
  type: fsimage-layered
  path: minimal.standard.live.extra.squashfs
  size: $SIZE
  locale_support: langpack
  preinstalled_langs: []
  name:
    en: AncorOS Desktop
  description:
    en: AncorOS Desktop, GNOME 50, Wayland only, Angelcore look
  variations:
    standard:
      path: minimal.standard.live.extra.squashfs
      size: $SIZE
kernel:
  default: linux-generic-hwe-24.04
EOF
cat "$TREE/casper/install-sources.yaml" | head -12
cp /home/builder/user-data "$TREE/user-data"
cp /home/builder/meta-data "$TREE/meta-data"
cp /home/builder/autoinstall.yaml "$TREE/autoinstall.yaml"
cp /home/builder/grub.cfg "$TREE/boot/grub/grub.cfg"

step "extract boot structures"
sudo dd if="$ORIG" of="$W/mbr.bin" bs=512 count=16 status=none
sudo dd if="$ORIG" of="$W/efi_part.img" bs=512 skip=12649996 count=10296 status=none
sudo chown builder:builder "$W/mbr.bin" "$W/efi_part.img"
ls -la "$W/mbr.bin" "$W/efi_part.img"

step "build iso"
rm -f "$OUT"
xorriso -as mkisofs \
  -r \
  -V "AncorOS 26.04.1 LTS amd64" \
  -o "$OUT" \
  -J -joliet-long \
  --grub2-mbr "$W/mbr.bin" \
  --protective-msdos-label \
  -partition_cyl_align off \
  -partition_offset 16 \
  --mbr-force-bootable \
  -append_partition 2 0xef "$W/efi_part.img" \
  -appended_part_as_gpt \
  -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
  -c boot.catalog \
  -b boot/grub/i386-pc/eltorito.img \
  -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
  -eltorito-alt-boot \
  -e '--interval:appended_partition_2_start_0s_size_10296d:all::' \
  -no-emul-boot -boot-load-size 10296 \
  "$TREE" 2>&1 | tail -18
if [ ! -s "$OUT" ]; then
  echo "FATAL: iso not created"
  exit 1
fi
ls -la "$OUT"

step "el torito report"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -16

step "checksum"
sha256sum "$OUT" | tee "$OUT.sha256"

step "done"
du -h "$OUT"
df -h /home/builder | tail -1
echo "PACK-ISO2-OK"