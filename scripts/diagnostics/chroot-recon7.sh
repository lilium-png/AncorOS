#!/bin/bash
set -u
S=/home/builder/work/bsnap/bin/subiquity
echo "=== models/source.py ==="
cat "$S/subiquity/models/source.py" 2>/dev/null
echo "=== grep variations usage ==="
grep -rn --binary-files=without-match 'variations' "$S/subiquity" 2>/dev/null | grep -v test | head -30
echo "=== grep .path usage for source ==="
grep -rn --binary-files=without-match 'current.path\|source.*\.path' "$S/subiquity" 2>/dev/null | head -20
echo "=== done ==="