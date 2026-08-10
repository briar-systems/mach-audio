#!/bin/sh
# verify the measured miniaudio imports and the final Windows dependency set.
set -eu

[ "$#" -gt 1 ] || {
    echo "usage: tools/check-windows-pe.sh <miniaudio.o> <exe>..." >&2
    exit 2
}

object=$1
shift
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/expected-object-imports" <<'EOF'
___chkstk_ms
__imp_CloseHandle
__imp_CreateEventA
__imp_CreateSemaphoreA
__imp_CreateThread
__imp_FreeLibrary
__imp_GetLastError
__imp_GetProcAddress
__imp_LoadLibraryA
__imp_QueryPerformanceCounter
__imp_QueryPerformanceFrequency
__imp_ReleaseSemaphore
__imp_ResetEvent
__imp_SetEvent
__imp_SetThreadPriority
__imp_Sleep
__imp_WaitForSingleObject
__imp_WideCharToMultiByte
exp
free
malloc
memcpy
memset
realloc
sin
strlen
vsnprintf
wcslen
EOF

llvm-nm --undefined-only "$object" | awk '$1 == "U" { print $2 }' | sort -u \
    >"$tmp/actual-object-imports"
if ! diff -u "$tmp/expected-object-imports" "$tmp/actual-object-imports"; then
    echo "check-windows-pe: miniaudio's measured import surface changed" >&2
    exit 1
fi

runtime_dir=$(dirname "$object")/mingw
llvm-nm --defined-only "$runtime_dir/compiler_rt.lib" >"$tmp/compiler-rt"
llvm-nm --defined-only "$runtime_dir/libmingw32.lib" >"$tmp/mingw32"
for symbol in ___chkstk_ms exp memcpy memset sin strlen; do
    grep -Eq " [TW] $symbol$" "$tmp/compiler-rt" || {
        echo "check-windows-pe: compiler_rt does not provide $symbol" >&2
        exit 1
    }
done
grep -Eq ' [TW] vsnprintf$' "$tmp/mingw32" || {
    echo "check-windows-pe: libmingw32 does not provide vsnprintf" >&2
    exit 1
}

cat >"$tmp/expected-dlls" <<'EOF'
advapi32.dll
api-ms-win-core-synch-l1-2-0.dll
api-ms-win-crt-heap-l1-1-0.dll
api-ms-win-crt-stdio-l1-1-0.dll
api-ms-win-crt-string-l1-1-0.dll
kernel32.dll
ws2_32.dll
EOF

for exe in "$@"; do
    imports="$tmp/imports"
    relocs="$tmp/relocs"
    llvm-readobj --coff-imports "$exe" >"$imports"
    llvm-readobj --coff-basereloc "$exe" >"$relocs"
    sed -n 's/^  Name: //p' "$imports" | sort -u >"$tmp/actual-dlls"
    if ! diff -u "$tmp/expected-dlls" "$tmp/actual-dlls"; then
        echo "check-windows-pe: unexpected import dependency set in $exe" >&2
        exit 1
    fi
    if grep -Eq '^  Symbol: (__imp_|exp |memcpy |memset |sin |strlen |vsnprintf )' "$imports"; then
        echo "check-windows-pe: static symbol leaked into imports in $exe" >&2
        exit 1
    fi
    for symbol in malloc free realloc wcslen __stdio_common_vsprintf; do
        grep -q "^  Symbol: $symbol " "$imports" || {
            echo "check-windows-pe: missing dynamic CRT import $symbol in $exe" >&2
            exit 1
        }
    done
    for symbol in CloseHandle CreateEventA CreateSemaphoreA CreateThread \
        FreeLibrary GetLastError GetProcAddress LoadLibraryA \
        QueryPerformanceCounter QueryPerformanceFrequency ReleaseSemaphore \
        ResetEvent SetEvent SetThreadPriority Sleep WaitForSingleObject \
        WideCharToMultiByte; do
        grep -q "^  Symbol: $symbol " "$imports" || {
            echo "check-windows-pe: missing kernel32 import $symbol in $exe" >&2
            exit 1
        }
    done
    dir64=$(grep -c '^    Type: DIR64$' "$relocs")
    [ "$dir64" -gt 0 ] || {
        echo "check-windows-pe: no DIR64 base relocations in $exe" >&2
        exit 1
    }
    if grep '^    Type: ' "$relocs" | grep -Ev '^    Type: (ABSOLUTE|DIR64)$'; then
        echo "check-windows-pe: unexpected base relocation type in $exe" >&2
        exit 1
    fi
    echo "PASS $exe: 7 DLLs, $dir64 DIR64 relocations"
done
