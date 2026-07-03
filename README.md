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
[deps.mach-audio]
git = "https://github.com/briar-systems/mach-audio"
ref = "branch/main"
```

## Status

Early, but the pure-mach layer has taken shape. Implemented with display-free
tests: the interleaved-`f32` buffer/format currency (`audio.buffer`), a
RIFF/WAVE decoder for PCM 16/24/32-bit and IEEE float32 in mono and stereo
(`audio.wav`), the mixer core — per-source-gain mixdown with a saturating
clamp plus mono↔stereo conversion (`audio.mix`) — and a linear-interpolation
resampler (`audio.resample`). The native device layer and the effect graph
described below remain the roadmap. The device layer deliberately links nothing
today.

## Design

mach-audio is two strictly-separated layers.

### Device layer — the only native code

The device layer is the **sole** exception to the ecosystem's pure-Mach rule.
It is [miniaudio](https://miniaud.io/), vendored as a single C translation
unit and used **exclusively** at the `ma_device` level: device enumeration,
the audio callback, and raw sample buffers in and out. miniaudio's own mixer,
decoders, resampler, node graph, and high-level engine are explicitly **not**
compiled in and **not** used.

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

## Native dependency and linking

The device layer follows [mach-glfw](https://github.com/briar-systems/mach-glfw)'s
manifest pattern for native dependencies: once miniaudio is vendored, its
per-OS backend libraries are declared in `mach.toml` under `[os.<name>]
libs = [...]`, and the link requirement cascades to consumers through the
manifest. Until then, the pure-Mach layer links nothing, mirroring
[mach-gl](https://github.com/briar-systems/mach-gl).

The backends miniaudio selects per platform:

| OS | Backends |
|---|---|
| Linux | ALSA, PulseAudio, JACK (PipeWire via its PulseAudio-compatible server) |
| Windows | WASAPI (DirectSound / WinMM fallback) |
| macOS | CoreAudio |

## Targets

mach-audio's pure-Mach layer builds for every target the Mach compiler
supports. The device layer's per-OS backends are validated as they land.

| Target | ISA | Pure-Mach layer | Device layer |
|---|---|---|---|
| linux | x86_64 | yes | planned (ALSA / PulseAudio / PipeWire) |
| windows | x86_64 | yes | planned (WASAPI) |
| darwin | x86_64 | yes | planned (CoreAudio) |

## Tests

`test` blocks live beside the code they cover and are display-free: the sample
primitives are exercised directly, with no device open and no audio hardware.
Paths that need a live device — enumeration, the callback, real playback — are
verified by running examples, not by `mach test`.
