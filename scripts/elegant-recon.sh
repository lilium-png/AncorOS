#!/bin/bash
cd /home/builder/Elegant-grub2-themes || exit 1
echo "=== top level ==="
ls
echo "=== config ==="
ls config | head -20
echo "=== themes dir? ==="
ls -d themes 2>/dev/null || echo "no themes dir"
echo "=== find theme.txt ==="
find . -name 'theme.txt' | head -10
echo "=== install.sh present? ==="
ls install.sh 2>/dev/null || echo "no install.sh"
echo "=== readme usage ==="
head -40 README.md
echo "=== config file sample ==="
ls config/*.txt 2>/dev/null | head -5
head -20 config/*.txt 2>/dev/null | head -30
echo "=== background files ==="
ls backgrounds | head -10
echo "=== assets ==="
ls assets | head -10