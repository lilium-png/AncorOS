#!/bin/bash
L=/home/builder/work/pack-iso.log
echo "=== recover source build options ==="
awk '/recover source build options/{flag=1;next}/build iso/{if(flag){flag=0}}flag' "$L" | tail -20
echo "=== build iso ==="
awk '/############ build iso/{flag=1;next}/el torito report/{flag=0}flag' "$L" | tail -30
echo "=== final cmd file ==="
cat /home/builder/work/xorriso-final-cmd.txt 2>/dev/null | head -5
echo "=== report file ==="
cat /home/builder/work/xorriso-report.txt 2>/dev/null | head -5
echo "=== files in work ==="
ls -la /home/builder/work/*.iso* 2>/dev/null | head -10
echo "=== xorriso test on source ==="
xorriso -indev /dev/sr0 -report_el_torito as_mkisofs 2>&1 | tail -3
echo "=== xorriso version ==="
xorriso --version 2>&1 | head -2