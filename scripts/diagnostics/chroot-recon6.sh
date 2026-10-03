#!/bin/bash
set -u
S=/home/builder/work/bsnap/bin/subiquity
echo "=== source.py ==="
sed -n '1,140p' "$S/subiquity/server/controllers/source.py"
echo "=== sizes.py ==="
cat "$S/subiquity/common/filesystem/sizes.py" 2>/dev/null | head -60
echo "=== grep install-sources in whole subiquity tree ==="
grep -rn --binary-files=without-match 'install-sources' "$S/subiquity" 2>/dev/null | head -20
echo "=== grep fsimage-layered ==="
grep -rn --binary-files=without-match 'fsimage-layered\|fsimage-layered' "$S/subiquity" 2>/dev/null | head -20
echo "=== done ==="