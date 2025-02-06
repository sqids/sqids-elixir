# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- Elixir 1.18 to CI
- OTP 27.2 to CI
- latest blocklist tweaks

### Fixed

- compilation warning on Elixir 1.18

## [0.2.0] - 2024-10-12

### Added

- Elixir 1.17 to CI
- OTP 27.1 to CI

### Changed

- [BREAKING] in supervised Sqids, if you had some non-default options declared
  but only the module's name defined as the supervisor child (as was
  recommended by docs), the options wouldn't work. Sqids now raises if this
  situation is detected to nudge users towards fixing it in the way that's best
  for each individual.

### Fixed

- documentation on supervised Sqids: intended options were not passed
- compilation warnings on Elixir 1.17

## [0.1.3] - 2024-02-08

### Added

- Elixir 1.16 to CI
- OTP 26.2 to CI

### Fixed

- decoding exception when ExUnit wasn't imported by caller (thanks to
  https://github.com/tshakah)
- typos in README (thanks to https://github.com/hanifanazka)
- Credo warnings about [predicate function
  names](https://hexdocs.pm/credo/Credo.Check.Readability.PredicateFunctionNames.html)

## [0.1.2] - 2023-11-04

### Added

- workaround for Dialyzer warnings when placing context in module attribute
- oldest `sqids` version in which each function, type and callback is available

### Fixed

- Dialyzer warnings for suggestion of `sqids` context under module attribute

## [0.1.1] - 2023-10-29

### Added

- `new!/0` and `new!/1` to ease storing context in module attributes

### Fixed

- unwarranted risk of new future warnings breaking the builds of sqids
  dependents

## [0.1.0] - 2023-10-28

### Added

- Elixir implementation of [Sqids](https://sqids.org/)
