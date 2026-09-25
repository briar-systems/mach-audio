#!/usr/bin/env bash
# per-leg checks on test/consumer and demo/play, which link the library the way
# an external project does. the subprojects phase already built both in every
# profile, since the library declares no binary
set -euo pipefail

consumer=test/consumer/out
play=demo/play/out

# the consumer prints one success line when it can open and drive the library
smoke() {
  "$1" | tee "$2"
  grep -q '^consumer smoke ok$' "$2"
  echo "$1: consumer smoke ok"
}

pe_check() {
  for profile in $MACH_CI_PROFILES; do
    tools/check-windows-pe.sh \
      "$play/windows/$profile/vendor/miniaudio/miniaudio.o" \
      "$play/windows/$profile/bin/play.exe" \
      "$consumer/windows/$profile/bin/audio-consumer.exe"
    echo "windows $profile: PE imports and relocations ok"
  done
}

case "$MACH_CI_LEG" in
  x86_64-linux)
    for profile in $MACH_CI_PROFILES; do
      exe="$consumer/linux-x86_64/$profile/bin/audio-consumer"
      smoke "$exe" "$RUNNER_TEMP/audio-consumer-$profile.log"
      if ldd "$exe" | grep -qiE 'miniaudio|mach-audio'; then
        echo "::error::$exe retains a dynamic mach-audio dependency"
        exit 1
      fi
      echo "$exe: no dynamic mach-audio"
    done
    ;;
  windows-cross)
    pe_check
    ;;
  x86_64-windows)
    for profile in $MACH_CI_PROFILES; do
      smoke "$consumer/windows/$profile/bin/audio-consumer.exe" "$RUNNER_TEMP/audio-consumer-native-$profile.log"
    done
    pe_check
    ;;
  x86_64-darwin)
    for profile in $MACH_CI_PROFILES; do
      smoke "$consumer/darwin/$profile/bin/audio-consumer" "$RUNNER_TEMP/audio-consumer-darwin-$profile.log"
    done
    for profile in $MACH_CI_PROFILES; do
      tools/check-darwin-macho.sh \
        "$play/darwin/$profile/vendor/miniaudio/miniaudio.o" \
        "$play/darwin/$profile/bin/play" \
        "$consumer/darwin/$profile/bin/audio-consumer"
      echo "darwin $profile: Mach-O imports ok"
    done
    ;;
esac
