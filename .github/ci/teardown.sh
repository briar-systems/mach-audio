#!/usr/bin/env bash
# a darwin link that failed after miniaudio compiled is almost always a
# SUBTRACTOR relocation, so print those sections for any profile that stopped there
set -euo pipefail

case "$MACH_CI_LEG" in
  x86_64-darwin) target=darwin ;;
  aarch64-darwin) target=darwin-aarch64 ;;
  *) exit 0 ;;
esac
for profile in $MACH_CI_PROFILES; do
  out="demo/play/out/$target/$profile"
  object="$out/vendor/miniaudio/miniaudio.o"
  if [ -f "$object" ] && [ ! -f "$out/bin/play" ]; then
    otool -rv "$object" | awk '/^Relocation information/{section=$0} /SUBTRACTOR/{print section; print}'
  fi
done
