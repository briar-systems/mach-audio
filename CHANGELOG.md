# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- layout: The library surface moves from `src/audio.mach` to
  `src/lib/audio.mach`, following the family layout for artifact entries
  (#65). A bare `use audio;` is unaffected, since it binds the default
  artifact's entry wherever that lives, and every other module path
  (`audio.buffer`, `audio.mix`, `audio.device`, ...) is unchanged. The entry
  module's own full path becomes `audio.lib.audio` in place of `audio.audio`.
  `src/lib/` is the artifact that builds a compiled library to ship, not the
  surface a direct dependency names, so a consumer imports the bare
  `use audio;`. `mach test . --list` collects the same 49 tests as before.
- play: The `play` example leaves the library for `demo/play/`, its own project
  with its own std pin and a path dependency on the repository root, so the
  library declares no binary (#65). `[artifact.play]` and
  `[artifact.play-windows]` are gone, and the one `[artifact.play]` in the
  example's manifest writes `bin/play` or, on windows, `bin/play.exe` through
  `{artifact.suffix}`. It imports the bare `use audio;` like any consumer. The
  miniaudio object and every platform link stay with the library and cascade
  to consumers as before, so a consumer still declares nothing beyond the
  dependency. `mach run . --bin play` becomes `mach run demo/play`. CI builds
  the example as a subproject on every leg beside `test/consumer` and runs the
  same PE and Mach-O checks on it.

### Fixed
- readme: The dependency stanza selects releases with `version = "^0.9.0"`, as
  `mach dep add` writes it, in place of following `branch/main`, and shows the
  `mach dep add` command first. The requirement line names Mach 5.12 and std
  8.1 in place of the stale Mach 5.9 and std 6.0 (#61).

## [0.9.0] - 2026-09-25

### Changed
- build: **Breaking.** Require std 8.1 and Mach 5.12. std is declared
  `version = "^8.1"` in the root and in `test/consumer`, each pinned at v8.1.0
  by its committed gitlink, and `[project].mach` is `^5.12`. Resolution is
  flat, so a consumer must move to std 8 and Mach 5.12 with this release, and
  anything that links std has to be rebuilt. 8.1 is the floor because std 7.5
  through 8.0 overwrite libc's thread pointer at startup, which crashes
  miniaudio in `malloc` on linux (briar-systems/mach-std#915). No source
  change was needed, and the std types this library exposes are unchanged
  (#62).
- ci: Seed Mach v5.12.0 on every leg, ahead of the family default. Mach 5.12
  builds only the default artifact, so the verify hook selects the `play`
  example with `--bin` on every leg, as the plain build did before (#62).

## [0.8.0] - 2026-09-19

### Changed
- build: Require std 6.0 and Mach 5.9. std is declared `version = "^6.0"` in
  the root and in `test/consumer`, each pinned at v6.0.0 by its committed
  gitlink. No source change was needed: std 6.0 reshapes `sort`, `heap`,
  `map`, `set`, `crypto.ct` and `buffers.open_account`, none of which this
  library uses, and the std types it exposes are unchanged (#57).
- test: The `test/consumer` fixture declares std by range like the root,
  pinned by its own committed `test/consumer/dep/std` gitlink, instead of an
  exact tag. `mach dep pull` initializes a nested gitlink from a range since
  Mach 5.8.1 (#55).

## [0.7.0] - 2026-09-19

### Changed
- build: Require std 5.7 and Mach 5.5.2. std is declared by range,
  `version = "^5.7.1"`, with the `dep/std` gitlink as the pin, so a later
  std minor resolves beside a root that declares one. A root project pinning std 5.x
  overrides every dependency's std, so a library left on std 4 no longer
  resolves under it. No source change was needed: the library's own
  `mixer.Source` is unrelated to std's `buffers.Source`, and nothing here uses
  `std.time`. The std types this library exposes are unchanged (#49).
- license: Copyright is held by Briar Systems LLC (#41).
- build: Declare the compiler range in `[project].mach`, first as `^5.3` (#43),
  now `^5.5.2` (#49).

## [0.6.1] - 2026-09-16

### Changed
- build: Require std 4.0 and Mach 5.2. No public type changes, since the std
  types this library exposes are unchanged in 4.0 (#35).

## [0.6.0] - 2026-09-16

### Changed
- build: Require std 3.2. Windows binaries now also import `advapi32.dll`,
  which std uses to protect owner-only files (#31).
- build: Require Mach 5.0 and std 2.1. The dependency is `[dep.std]`, pinned by
  the committed `dep/std` gitlink, and `mach.lock` is gone. Consumers declare
  this project as `[dep.audio]`.
- build: The vendored shim and MinGW runtime now build under
  `{project.out}/vendor/miniaudio/`, clear of the compiler's reserved object tree.
- buffer: `init` returns `res[Buffer, BufferError]` (`channels`, `overflow`,
  `alloc`), `dnit` returns `err[allocator.Error]`, and `at` returns `opt[*f32]`.
- wav: `decode` returns `res[Buffer, DecodeError]`, one case per rejection,
  carrying the offending channel count, format tag or bit depth.
- device: `open` returns `res[Device, DeviceError]`, `start` and `stop` return
  `err[DeviceError]`, and `close` returns nothing. `DeviceError` separates a
  missing real backend (`unavailable`) from a backend refusal (`backend`, with
  miniaudio's result code), which the shim's `mad_device_open` now reports.
- play: Read the input through `std.filesystem.read_bytes` (#19).

## [0.5.0] - 2026-08-09

### Added
- device: Build and link the vendored shim for Windows WASAPI and native macOS CoreAudio, with exact foreign-import attribution and exported dependency steps.
- test: Exercise the native null-device lifecycle directly and through an external consuming project on every supported host.

### Changed
- device: Reject the null backend from normal playback so a missing hardware backend cannot report false success.
- build: Require Mach 4.18.1 or newer for the native foreign-object link path.
- windows: Remove the unused `ole32.dll` link; miniaudio loads it at runtime for WASAPI.

## [0.4.1] - 2026-08-09

### Fixed
- audio: re-export `mix_add_pan`, `stream_set_rate`, `RATE_MIN` and `RATE_MAX`
  from the surface module. 0.4.0 added them to their own modules and never
  forwarded them, so a consumer reaching them the documented way could not.

## [0.4.0] - 2026-08-09

### Added
- stream: `Stream.rate`, a playback speed with a fractional cursor and linear
  interpolation between neighbouring frames. `stream_set_rate` clamps to
  `RATE_MIN`..`RATE_MAX`, because a rate at or below zero never advances, which
  is an audible hang rather than an error. Rate 1 keeps a dedicated copy path so
  a clip nobody retuned cannot drift.
- mix: `mix_add_pan`, accumulating a source with a separate gain per channel.
  The pan law itself stays with the caller: choosing it is mixing policy, and
  computing it here would put a square root in a module with no float maths.

### Changed
- **Breaking.** `Stream` gained `frac` and `rate`. Code that builds a `Stream`
  field by field rather than through `stream_over` must set both, or playback
  runs at whatever the uninitialized memory held. `stream_over` sets them.

## [0.3.0] - 2026-08-09

### Changed
- manifest: Re-touched `mach.toml` to RFC-exact totality per mach#1964/mach#1979.
- ci: Verify the real `mach build .` / `mach test .` flow and drop the obsolete `libminiaudio.so` Makefile shim; the `[step.build-miniaudio]` step compiles and links the vendored object in-tree.

## [0.2.0] - 2026-07-07

### Changed
- manifest: Migrated manifest layout (`mach.toml`) and dependencies to the V2 manifest specification.
- build: Added a custom step to build the miniaudio shim statically and link it locally.
