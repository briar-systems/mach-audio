# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- test: The `test/consumer` fixture declares std by range, `version = "^5.7.1"`,
  pinned by its own committed `test/consumer/dep/std` gitlink, and requires
  Mach 5.8.0, where `mach dep pull` initializes a nested gitlink from a range.
  The root's compiler range is unchanged (#55).

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
