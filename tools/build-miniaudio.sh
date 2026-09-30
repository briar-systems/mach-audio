#!/bin/sh
# compile the vendored device shim for the active Mach target.
set -eu
cd "$(dirname "$0")/.."

out=${1:?usage: tools/build-miniaudio.sh <output>}
isa=${MACH_TARGET_ISA:-x86_64}
os=${MACH_TARGET_OS:-linux}
flags=

case $(uname -s) in
Linux) host=linux ;;
Darwin) host=darwin ;;
MINGW*|MSYS*|CYGWIN*) host=windows ;;
*) host=other ;;
esac

# mach isa names for the host machine
case $(uname -m) in
arm64|aarch64) host_isa=aarch64 ;;
x86_64|amd64) host_isa=x86_64 ;;
*) host_isa=$(uname -m) ;;
esac

case $os in
linux)
    defs="-DMA_ENABLE_ONLY_SPECIFIC_BACKENDS -DMA_ENABLE_ALSA -DMA_ENABLE_PULSEAUDIO -DMA_ENABLE_JACK -DMA_ENABLE_NULL"
    if [ "$host" = linux ] && [ "$host_isa" = "$isa" ]; then
        cc=${CC:-cc}
        target=
    else
        cc=${CC:-zig cc}
        target="-target $isa-linux-gnu"
    fi
    pic=-fPIC
    # outline atomics call libgcc helpers the link never pulls in
    case $isa in aarch64) flags="-mno-outline-atomics" ;; esac
    ;;
windows)
    defs="-DMA_ENABLE_ONLY_SPECIFIC_BACKENDS -DMA_ENABLE_WASAPI -DMA_ENABLE_NULL"
    cc=${CC:-zig cc}
    target="-target $isa-windows-gnu"
    pic=
    ;;
darwin)
    if [ "$host" != darwin ]; then
        echo "build-miniaudio: darwin requires a native macOS host and Apple SDK" >&2
        exit 1
    fi
    defs="-DMA_ENABLE_ONLY_SPECIFIC_BACKENDS -DMA_ENABLE_COREAUDIO -DMA_ENABLE_NULL -DMA_NO_RUNTIME_LINKING"
    cc=${CC:-cc}
    # apple clang names aarch64 arm64
    case $isa in
    aarch64) target="-arch arm64" ;;
    *) target="-arch $isa" ;;
    esac
    # mach#2973: keep clang from emitting unsupported SUBTRACTOR relocation pairs.
    # mach#2974: emit tentative globals into BSS instead of unsupported common symbols.
    flags="-fno-jump-tables -fno-common"
    pic=
    ;;
*)
    echo "build-miniaudio: unsupported target os '$os'" >&2
    exit 1
    ;;
esac

mkdir -p "$(dirname "$out")"
$cc $target -c -O2 -w $flags $pic $defs vendor/mad.c -o "$out"
