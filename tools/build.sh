#!/usr/bin/env bash
set -e
PAIDEIA_AS="${PAIDEIA_AS:-/home/snunez/Development/PaideiaOS/tools/paideia-as/target/release/paideia-as}"
mkdir -p build-out
fail=0; ok=0
for src in src/*.pdx tests/*.pdx; do
  [ -f "$src" ] || continue
  if $PAIDEIA_AS build --emit elf64 -o "build-out/$(basename "$src" .pdx).o" "$src" 2>&1 | tail -8; then ok=$((ok+1)); else fail=$((fail+1)); fi
done
echo "[build] $ok source(s), $fail failure(s)"
[ $fail -eq 0 ] && exit 0 || exit 1
