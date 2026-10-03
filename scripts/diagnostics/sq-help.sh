#!/bin/bash
mksquashfs -help > /tmp/mh.txt 2>&1
echo "=== help lines: $(wc -l < /tmp/mh.txt) ==="
grep -in "list" /tmp/mh.txt | head -20
echo "=== keep-as / root-becomes / pseudo ==="
grep -in "keep-as" /tmp/mh.txt | head -5
grep -in "root-becomes" /tmp/mh.txt | head -5
grep -in "pseudo" /tmp/mh.txt | head -5
echo "=== usage line ==="
head -40 /tmp/mh.txt
echo "HELP-DONE"