# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- device: Build and link the vendored shim for Windows WASAPI and native macOS CoreAudio, with exact foreign-import attribution and exported dependency steps.
- test: Exercise the native null-device lifecycle directly and through an external consuming project on every supported host.

### Changed
- manifest: Re-touched `mach.toml` to RFC-exact totality per mach#1964/mach#1979.
- ci: Verify the real `mach build .` / `mach test .` flow and drop the obsolete `libminiaudio.so` Makefile shim; the `[step.build-miniaudio]` step compiles and links the vendored object in-tree.
- device: Reject the null backend from normal playback so a missing hardware backend cannot report false success.
- windows: Remove the unused `ole32.dll` link; miniaudio loads it at runtime for WASAPI.

## [0.2.0] - 2026-07-07

### Changed
- manifest: Migrated manifest layout (`mach.toml`) and dependencies to the V2 manifest specification.
- build: Added a custom step to build the miniaudio shim statically and link it locally.
