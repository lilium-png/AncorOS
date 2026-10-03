#!/bin/bash
set -u
S=/home/builder/work/bsnap
echo "=== curtin extract.py 150-260 ==="
sed -n '150,260p' "$S/lib/python3.12/site-packages/curtin/commands/extract.py"
echo "=== util.py 1060-1140 ==="
sed -n '1060,1140p' "$S/lib/python3.12/site-packages/curtin/util.py"
echo "=== grep get_parent_layers / layer helpers ==="
grep -rn --binary-files=without-match 'parent_layers\|def .*layer' "$S/lib/python3.12/site-packages/curtin/" 2>/dev/null | head -20
echo "=== done ==="