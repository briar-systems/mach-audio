# mach-audio

Audio for [Mach](https://github.com/briar-systems/mach): a minimal native
device-layer binding with everything above it — mixing, resampling, DSP, and
decoding — written in pure Mach. Project id is `audio`, so consumers reach
everything as `audio.*`.

```mach
use audio;

# the pure-mach mixing layer works in normalized f32 samples.
fun master(a: f32, b: f32, trim: f32) f32 {
    val bus: f32 = audio.sum(audio.gain(a, trim), b);
    ret audio.clamp(bus);
}
```

Consuming projects vendor mach-audio as a normal Mach dependency:

```toml
[dep.mach-audio]
git = "https://github.com/briar-systems/mach-audio"
ref = "branch/main"
```

## Status

The pure-mach layer and the native device layer are both in place, with
display-free tests. The pure layer: the interleaved-`f32` buffer/format
currency (`audio.buffer`), a RIFF/WAVE decoder for PCM 16/24/32-bit and IEEE
float32 in mono and stereo (`audio.wav`), the mixer core, per-source-gain
mixdown with a saturating clamp plus mono/stereo conversion (`audio.mix`), and
a linear-interpolation resampler (`audio.resample`). The device layer: an f32
playback device over miniaudio (`audio.device`) driven by a render callback,
and a real-time-safe playback cursor (`audio.stream`) for streaming a decoded
buffer to it. The effect graph described below remains the roadmap.

The complete device lifecycle is verified against real Linux hardware: the
`play` example decodes a WAV, mixes it, opens the default PipeWire-backed
device, starts its callback thread, drains the source, and closes cleanly. The
same lifecycle is exercised without hardware on every native CI host through
miniaudio's explicit null backend. Physical Windows and macOS speaker checks
remain outstanding and are not claimed; see [Targets](#targets) and the
[device validation checklist](doc/device-validation.md).

## Design

mach-audio is two strictly-separated layers.

### Device layer — the only native code

The device layer is the **sole** exception to the ecosystem's pure-Mach rule.
It is [miniaudio](https://miniaud.io/) (pinned to v0.11.25), vendored as a
single C translation unit and used **exclusively** at the `ma_device` level:
the device lifecycle (open, start, stop, close) and the audio callback, with
raw f32 sample buffers going out. miniaudio's own mixer, decoders, resampler,
node graph, and high-level engine are compiled out (`MA_NO_*`) and **not**
used. A thin C shim (`vendor/mad.c`) exposes a small, ABI-stable `mad_*`
surface over that lifecycle, so miniaudio's struct layouts never reach Mach and
a miniaudio version bump cannot break the binding.

The exception is deliberate. OS audio backends (WASAPI, CoreAudio, ALSA,
PulseAudio, PipeWire) are a maintained-zoo problem — a moving target of
platform APIs and quirks — not an algorithms problem. Rebinding that zoo by
hand buys nothing, so we lean on miniaudio for exactly the part that is
platform plumbing and nothing more. Because the boundary is drawn at
`ma_device`, the layer is peelable per-platform later: a pure-Mach Linux
backend can replace miniaudio on Linux without touching a line of the public
API.

### Pure-Mach layer — everything above the callback

Everything above the device callback is pure Mach:

- **mixer** — sum buses of normalized f32 samples, per-channel gain, master
  limiting (`audio.mix`).
- **resampler** — sample-rate conversion between the device rate and source
  material.
- **DSP / effects** — gain, pan, and an effect graph over sample buffers.
- **decoders** — WAV first; Ogg Vorbis, FLAC, and MP3 as later pure-Mach work.

The device layer hands this layer raw buffers and asks for raw buffers back;
it knows nothing about formats, mixing, or effects.

## Playback

The device feeds a consumer-supplied render callback on a separate,
high-priority OS thread. That callback fills interleaved f32 frames and returns:

```mach
use audio;

# runs on the audio thread; pulls the next frames from a borrowed Stream.
fun render(out: *f32, frames: u32, channels: u32, user: ptr) {
    audio.pull(user:~*audio.Stream, out, frames, channels);
}

# ... on the main thread: decode -> mix -> open -> start
val dev: audio.Device = /* audio.open(fmt, render, (?stream):~ptr) */ ...;
```

**Real-time contract.** The render callback runs on the audio thread and must
not allocate, take a lock, block, or do I/O; it may only fill the buffer and
return. Filling from preallocated sources (`audio.mix`) or a decoded buffer
(`audio.stream`) satisfies this; anything that can page-fault or wait does not.
The design is a plain callback hook (no ring buffer): the pure mixer already
renders synchronously and allocation-free, so a buffer-and-producer-thread
would only add latency.

The full decode-to-speakers path lives in [`src/play.mach`](src/play.mach); run
it with `mach run . --bin play -- some.wav`. On Windows, use the platform's
extension-specific artifact: `mach run . --bin play-windows -- some.wav`.

Normal playback refuses miniaudio's null backend. A successful `audio.open` or
`play` run therefore means that a real platform backend initialized; a machine
with no usable output device reports an open failure instead of silently
discarding samples.

## Native dependency and linking

The device layer follows the ecosystem's native-dependency pattern. miniaudio is
vendored as one C translation unit (`vendor/mad.c`, which includes the pinned
`vendor/miniaudio.h`). `mach` does not compile C, so `mach.toml` declares a
`[step.build-miniaudio]` that compiles the translation unit to an in-tree object
and a `[link.miniaudio-local]` entry that links that object into every artifact,
alongside the platform requirements declared as `[link.<name>]` system entries.
Both the step and the link inputs cascade to consumers through the manifest.

Because the step lives in the manifest, `mach build` (and `mach test` / `mach
run`) compiles the vendored translation unit and links it in one pass — there is
no separate shim build and no `-L` flag. A consumer that pulls mach-audio
inherits the step and the platform libs automatically and builds the vendored
object the same way; `mach` cannot compile the C for them. The pure-Mach modules
never call into the shim. The native link path requires Mach 4.18.1 or newer.

[`tools/build-miniaudio.sh`](tools/build-miniaudio.sh) selects only the intended
backend family plus the null backend used by the lifecycle probe. Linux builds
with the host `cc`. Windows builds with `zig cc` for the GNU ABI and materialize
Zig's target-matched MinGW/compiler runtime archives. Windows builds therefore
require Zig 0.16 and Bash on `PATH`. The manifest attributes the shim's measured
kernel32 and UCRT imports to their exact DLLs. `ole32.dll` is deliberately absent
from the PE import table because miniaudio loads it with `LoadLibraryA` when
WASAPI initializes.

Darwin builds are native-only: the Apple SDK framework headers are not
redistributable and do not ship with Zig. The shim defines
`MA_NO_RUNTIME_LINKING`, so CoreFoundation, CoreAudio, and AudioToolbox are
normal framework dependencies rather than notarization-hostile `dlopen` calls.
Until Mach supports paired `SUBTRACTOR` relocations and common symbols from
foreign Mach-O objects (mach#2973 and mach#2974), the Darwin shim uses
`-fno-jump-tables -fno-common`; both flags preserve the miniaudio behavior.
Linux continues to load its audio servers at run time and links only the C
runtime, threads, math, and dynamic-loader surface.

The selected backends are:

| OS | Backends |
|---|---|
| Linux | ALSA, PulseAudio, JACK (PipeWire via its PulseAudio-compatible server) |
| Windows | WASAPI |
| macOS | CoreAudio |

## Targets

The table separates implementation from validation so a cross-build or a
hosted null-device run is never presented as a physical speaker test.

| Target | ISA | Device backend | Automated validation | Physical hardware |
|---|---|---|---|---|
| linux | x86_64 | ALSA / PulseAudio / JACK | native build, 45 tests, external lifecycle probe | default PipeWire output opened/started/stopped in debug and release; audible result not independently asserted |
| windows | x86_64 | WASAPI | Linux cross-link, 45 native tests, exact PE inspection, external lifecycle probe | pending |
| darwin | x86_64 | CoreAudio | native Intel build, 45 tests, exact Mach-O inspection, external lifecycle probe | pending |

## Tests

`test` blocks live beside the code they cover and are display-free. In addition
to the pure sample primitives and playback cursor, `audio.device` initializes a
null-backend context and device, starts its native thread, waits for the render
callback, stops it, and releases both objects. The separate
[`test/consumer`](test/consumer) fixture repeats that lifecycle through a path
dependency, proving that the vendored build step and all static/dynamic link
requirements cascade to consumers.

The null probe verifies native ABI and lifecycle behavior, not sound. Audible
playback remains a manual hardware check using `play`; the exact steps and the
current evidence ledger live in
[`doc/device-validation.md`](doc/device-validation.md).

The external fixture intentionally owns its dependency lock instead of
inheriting the repository lock. This makes it exercise the exported native
build and link cascade from an independent consumer graph.
