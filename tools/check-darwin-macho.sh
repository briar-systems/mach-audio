#!/bin/sh
# verify the measured miniaudio imports and final macOS dependency set.
set -eu

[ "$#" -gt 1 ] || {
    echo "usage: tools/check-darwin-macho.sh <miniaudio.o> <exe>..." >&2
    exit 2
}

object=$1
shift
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/expected-object-imports" <<'EOF'
_AudioComponentFindNext
_AudioComponentInstanceDispose
_AudioComponentInstanceNew
_AudioObjectAddPropertyListener
_AudioObjectGetPropertyData
_AudioObjectGetPropertyDataSize
_AudioObjectRemovePropertyListener
_AudioObjectSetPropertyData
_AudioOutputUnitStart
_AudioOutputUnitStop
_AudioUnitAddPropertyListener
_AudioUnitGetProperty
_AudioUnitGetPropertyInfo
_AudioUnitInitialize
_AudioUnitRender
_AudioUnitSetProperty
_CFRelease
_CFStringGetCString
____chkstk_darwin
___assert_rtn
___bzero
___stack_chk_fail
___stack_chk_guard
_exp
_free
_gettimeofday
_malloc
_memcpy
_memset
_pthread_attr_destroy
_pthread_attr_getschedparam
_pthread_attr_init
_pthread_attr_setinheritsched
_pthread_attr_setschedparam
_pthread_attr_setschedpolicy
_pthread_attr_setstacksize
_pthread_cond_destroy
_pthread_cond_init
_pthread_cond_signal
_pthread_cond_wait
_pthread_create
_pthread_join
_pthread_mutex_destroy
_pthread_mutex_init
_pthread_mutex_lock
_pthread_mutex_unlock
_realloc
_sched_get_priority_max
_sched_get_priority_min
_select$1050
_sin
_strcmp
_strlen
_vsnprintf
EOF

sort -u "$tmp/expected-object-imports" >"$tmp/expected-object-imports-sorted"
nm -u "$object" | sed '/^$/d' | sort -u >"$tmp/actual-object-imports"
if ! diff -u "$tmp/expected-object-imports-sorted" "$tmp/actual-object-imports"; then
    echo "check-darwin-macho: miniaudio's measured import surface changed" >&2
    exit 1
fi

for exe in "$@"; do
    otool -L "$exe" >"$tmp/dependencies"
    for dependency in \
        '/usr/lib/libSystem.B.dylib' \
        '/System/Library/Frameworks/CoreFoundation.framework/' \
        '/System/Library/Frameworks/CoreAudio.framework/' \
        '/System/Library/Frameworks/AudioToolbox.framework/'; do
        grep -q "$dependency" "$tmp/dependencies" || {
            echo "check-darwin-macho: missing $dependency in $exe" >&2
            exit 1
        }
    done
    count=$(tail -n +2 "$tmp/dependencies" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    [ "$count" -eq 4 ] || {
        echo "check-darwin-macho: expected 4 dependencies in $exe, found $count" >&2
        cat "$tmp/dependencies" >&2
        exit 1
    }
    echo "PASS $exe: exact CoreAudio dependency set"
done
