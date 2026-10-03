#!/bin/bash
set -u
S=/home/builder/work/bsnap
echo "=== curtin fsimage-layered ==="
grep -rn --binary-files=without-match 'fsimage-layered' "$S" 2>/dev/null | head -20
echo "=== curtin layer handling ==="
grep -rn --binary-files=without-match 'layer' "$S/bin/subiquity/subiquitycore"? 2>/dev/null | head -5
find "$S" -name 'extract.py' | head -5
echo "=== find curtin dirs ==="
find "$S" -maxdepth 4 -type d -name 'curtin' | head -10
echo "=== done ==="