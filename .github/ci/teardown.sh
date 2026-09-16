#!/usr/bin/env bash
# a darwin link that failed after miniaudio compiled is almost always a
# SUBTRACTOR relocation, so print those sections for any profile that stopped there
set -euo pipefail

[ "$MACH_CI_LEG" = x86_64-darwin ] || exit 0
for profile in $MACH_CI_PROFILES; do
  object="out/darwin/$profile/vendor/miniaudio/miniaudio.o"
  if [ -f "$object" ] && [ ! -f "out/darwin/$profile/bin/play" ]; then
    otool -rv "$object" | awk '/^Relocation information/{section=$0} /SUBTRACTOR/{print section; print}'
  fi
done
