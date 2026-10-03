#!/bin/bash
T=/tmp/sqtest
rm -rf $T
mkdir -p $T/src
echo hi > $T/src/a.txt
echo "--- test A: -xattrs -xattrs-exclude=regex ---"
mksquashfs $T/src $T/a.sq -noappend -no-progress -comp zstd -Xcompression-level 15 -b 1M -xattrs '-xattrs-exclude=^trusted\.overlay\..*' 2>&1 | head -4
echo "--- test B: -xattrs -xattrs-exclude regex ---"
mksquashfs $T/src $T/b.sq -noappend -no-progress -comp zstd -Xcompression-level 15 -b 1M -xattrs -xattrs-exclude '^trusted\.overlay\..*' 2>&1 | head -4
echo "--- test C: no xattrs ---"
mksquashfs $T/src $T/c.sq -noappend -no-progress -comp zstd -Xcompression-level 15 -b 1M 2>&1 | head -4
echo "--- test D: processors ---"
mksquashfs $T/src $T/d.sq -noappend -no-progress -comp zstd -processors 6 2>&1 | head -3
ls -la $T/*.sq 2>&1
rm -rf $T