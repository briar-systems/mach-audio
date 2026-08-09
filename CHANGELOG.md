# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
