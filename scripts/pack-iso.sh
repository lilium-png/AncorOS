#!/bin/bash
set -u
W=/home/builder/work
R="$W/mnt/merged"
TREE="$W/isotree"
LAYERS="$W/layers"
OUT="$W/AncorOS-26.04-amd64.iso"
LOG="$W/pack-iso.log"
SRCDEV=/dev/sr0

exec > >(tee -a "$LOG") 2>&1

step() {
  echo
  echo "############ $*  $(date -Is)"
}

step "unbind pseudo filesystems"
for m in run dev sys proc; do
  if mountpoint -q "$R/$m"; then
    sudo umount -l "$R/$m" && echo "unmounted $m"
  fi
done
mount | grep -c "on $R/" || true

step "empty base layers"
mkdir -p "$LAYERS/empty"
rm -f "$LAYERS/minimal.squashfs" "$LAYERS/minimal.standard.squashfs"
mksquashfs "$LAYERS/empty" "$LAYERS/minimal.squashfs" -noappend -no-progress -comp zstd -Xcompression-level 1
mksquashfs "$LAYERS/empty" "$LAYERS/minimal.standard.squashfs" -noappend -no-progress -comp zstd -Xcompression-level 1
ls -la "$LAYERS" | head

step "pack top layer"
rm -f "$LAYERS/minimal.standard.live.squashfs"
sudo mksquashfs "$R" "$LAYERS/minimal.standard.live.squashfs" \
  -comp zstd -Xcompression-level 15 -b 1M -noappend -no-progress -processors 6 \
  -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | tail -25
if [ ! -s "$LAYERS/minimal.standard.live.squashfs" ]; then
  echo "FATAL: top layer was not created"
  exit 1
fi
ls -la "$LAYERS/minimal.standard.live.squashfs"

step "iso tree copy"
rm -rf "$TREE"
mkdir -p "$TREE"
cp -a "$W/mnt/iso/." "$TREE/"
du -sh "$TREE"

step "swap layers in tree"
rm -f "$TREE"/casper/minimal*.squashfs
cp "$LAYERS/minimal.squashfs" "$TREE/casper/minimal.squashfs"
cp "$LAYERS/minimal.standard.squashfs" "$TREE/casper/minimal.standard.squashfs"
cp "$LAYERS/minimal.standard.live.squashfs" "$TREE/casper/minimal.standard.live.squashfs"
rm -f "$TREE"/casper/minimal*.manifest* "$TREE"/casper/minimal*.size
ls -la "$TREE/casper" | head -12

step "install-sources.yaml"
SIZE=$(stat -c %s "$TREE/casper/minimal.standard.live.squashfs")
echo "layer size: $SIZE"
cat > "$TREE/casper/install-sources.yaml" <<EOF
version: 2
sources:
- default: true
  id: ubuntu-desktop
  variant: desktop
  type: fsimage-layered
  path: minimal.standard.live.squashfs
  size: $SIZE
  locale_support: langpack
  preinstalled_langs: []
  name:
    en: AncorOS Desktop
  description:
    en: AncorOS Desktop, GNOME 50, Wayland only, Angelcore look
  variations:
    standard:
      path: minimal.standard.live.squashfs
      size: $SIZE
kernel:
  default: linux-generic-hwe-24.04
EOF
cat "$TREE/casper/install-sources.yaml"

step "cloud-init and autoinstall files"
cp /home/builder/user-data "$TREE/user-data"
cp /home/builder/meta-data "$TREE/meta-data"
cp /home/builder/autoinstall.yaml "$TREE/autoinstall.yaml"
cp /home/builder/ancoros-firstboot.sh "$TREE/ancoros-firstboot.sh"
ls -la "$TREE/user-data" "$TREE/meta-data" "$TREE/autoinstall.yaml"

step "boot menu branding"
cp /home/builder/grub.cfg "$TREE/boot/grub/grub.cfg"
head -12 "$TREE/boot/grub/grub.cfg"

step "drop stale md5sum.txt"
rm -f "$TREE/md5sum.txt"

step "recover source build options"
REPORT=""
if REPORT=$(xorriso -indev "$SRCDEV" -report_el_torito as_mkisofs 2>/dev/null | grep -m1 'mkisofs'); then
  :
else
  echo "report from block device failed, copying iso"
  cp "$SRCDEV" "$W/original.iso" || exit 1
  REPORT=$(xorriso -indev "$W/original.iso" -report_el_torito as_mkisofs 2>/dev/null | grep -m1 'mkisofs')
fi
printf '%s\n' "$REPORT" | tee "$W/xorriso-report.txt"

step "build iso"
eval "set -- $REPORT"
args=("${@:2}")
newargs=()
skip=0
for a in "${args[@]}"; do
  if [ "$skip" -eq 1 ]; then
    skip=0
    continue
  fi
  case "$a" in
    -o|-outdev|-output|-indev) skip=1; continue ;;
  esac
  if [ -d "$a" ]; then
    continue
  fi
  newargs+=("$a")
done
printf 'xorriso %s -o %s %s\n' "${newargs[*]}" "$OUT" "$TREE" | tee "$W/xorriso-final-cmd.txt"
xorriso "${newargs[@]}" -o "$OUT" "$TREE" 2>&1 | tail -30
ls -la "$OUT"

step "el torito report of new iso"
xorriso -indev "$OUT" -report_el_torito plain 2>&1 | tail -30

step "checksums"
sha256sum "$OUT" | tee "$OUT.sha256"

step "done"
du -sh "$OUT"
df -h /home/builder | tail -1
echo "PACK-ISO-OK"