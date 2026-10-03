#!/bin/bash
set -u
D=/home/builder/work/bsnap/bin/subiquity/doc
echo "=== providing-autoinstall.rst ==="
cat "$D/tutorial/providing-autoinstall.rst" 2>/dev/null
echo "=== zero-touch-autoinstall.rst ==="
cat "$D/explanation/zero-touch-autoinstall.rst" 2>/dev/null
echo "=== cloudinit-autoinstall-interaction.rst ==="
cat "$D/explanation/cloudinit-autoinstall-interaction.rst" 2>/dev/null
echo "=== done ==="