# Device validation

The automated native probe verifies the miniaudio context, device, audio
thread, render callback, stop, and cleanup path with the explicit null backend.
It proves the ABI and lifecycle without requiring hosted CI to have speakers.
It does not prove that samples reached a physical output.

Normal `audio.open` rejects the null backend. A successful `play` run therefore
proves that one of the real backends compiled for that target initialized.

## Hardware checklist

Use a short, known-good PCM WAV and test both profiles on the physical machine:

```sh
mach dep pull
mach build . --profile debug
mach build . --profile release
./out/<target>/debug/bin/play sample.wav
./out/<target>/release/bin/play sample.wav
```

On Windows, the executable path is `bin/play.exe`.

For each run:

1. Select the intended physical output in the operating system and begin at a
   safe volume.
2. Confirm `play` prints the expected sample rate, channel count, and frame
   count rather than `cannot open device`.
3. Confirm the complete source is audible from that output, with the expected
   channel placement and no initial silence, truncation, repetition, underrun,
   distortion, or output on a different device.
4. Confirm the process exits successfully after the source duration plus its
   short drain tail, and that the OS no longer reports an active audio stream.
5. Record the OS version, output hardware, sample, profile, result, and any
   backend diagnostics in the evidence table below.

Target-specific checks:

- Linux enables ALSA, PulseAudio, and JACK; PipeWire is reached through its
  PulseAudio-compatible server. Record which server and sink were selected.
- Windows enables only WASAPI plus the test-only null backend. Because normal
  playback rejects null, a successful `play` open selects WASAPI. Test on a
  physical Windows installation; Wine is useful ABI evidence but is not a
  Windows hardware substitute.
- macOS enables only CoreAudio plus the test-only null backend. Build on macOS
  itself; Linux cross-compilation is unsupported because the Apple SDK headers
  are not redistributable. Verify `otool -L` lists CoreFoundation, CoreAudio,
  and AudioToolbox and then perform the speaker check on a physical Mac.

## Evidence

| Date | Environment | Backend/output | Debug | Release | Audible hardware result | Notes |
|---|---|---|---|---|---|---|
| 2026-08-05 | Linux x86_64, PipeWire 1.6.8 with PulseAudio compatibility | SteelSeries Arctis Nova Pro Wireless USB default sink | open/start/stop passed | open/start/stop passed | not independently observed | `/usr/share/sounds/alsa/Front_Center.wav`; process ran for the source duration and exited 0 |
| 2026-08-05 | Wine 11.14 on Linux | Wine WASAPI | open/start/stop passed | open/start/stop passed | not a physical Windows validation | only WASAPI and null were compiled; normal playback rejects null |
| pending | Physical Windows x86_64 | WASAPI / record device | pending | pending | pending | required before claiming Windows hardware support |
| pending | Physical Intel macOS | CoreAudio / record device | pending | pending | pending | required before claiming macOS hardware support |
