# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2020-09-21

## Added

- Added ability to distinguish genuine escape key presses, and added escape key functionality.
- Added ability (AnsiSliceStringRefinement) to slice strings while effectively maintaining their ANSI formatting, as our eyes would expect.
- Added some dynamic header items to Tree View that track the following:
  - Multiple targets count and message
  - Last search text (what will be searched again by hitting 'n')
  - Number-to-move, if digits are typed
  - ('?' controls reminder now only displays when header is otherwise empty)

## Changed

- Now inputs check and screen redraws every 0.1 seconds even without user keypresses.
- (ArrayFitToRefinement now allows non-plural array counts)

## Removed

- Temporarily removed record/playback functionality
- Removed all dependency on activesupport

## Fixed

- Fixed issue where shrinking the console screen size enough would create a visual glitch until one of the boundary-resizing commands was received.

## [1.0.1] - 2020-09-18

### Added

- Added `require 'stringio'` for StringIO

### Removed

- Removed development_dependency 'io-console'

## [1.0.0] - 2020-09-18

### Added

- add_development_dependency 'io-console'
- Added table of contents to README

### Changed

- Bumped required_ruby_version from '>= 2.4.4' to '>= 2.5.3'
- Bumped rake version from '~> 10.0' to '~> 12.0'

## [0.1.0] - 2020-09-17

### Added

- The First Commit!
