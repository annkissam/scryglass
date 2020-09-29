# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## Added

- Turned on ANSI formatted/colored support with AnsiSliceStringRefinement.
- Added 'AmazingPrint' lens (colored) and gem.
- Added color formatting to (beta) method_showcase_for.
- Added "Smart Open" command 'o', which attempts to create sub-rows of the (next) most helpful type.
- README and help screen now point out that holding SHIFT will increase up/down step distance.
- Bottom and right edges of screen now indicate, with dots, when there is more beyond the view's edge.
- Added the VIM home row keybindings `h`/`j`/`k`/`l` as optional arrow keys.
- Now if the scry session hits an error, it will first ensure the error and console prompt appear below the present screen.
- Can now press `'` to give a console instance variable name to current objects without leaving scry session.

## Changed

- Changed user_signal timeout period from 0.1sec to 0.3sec to reduce number of coincidentally dropped inputs.
- Changed AnsiSliceStringRefinement syntax even closer to 'string'[args] (supporting [i, l] syntax).
- Changed the keys for switching subject type and lens from `L`/`l` to `<`/`>` (To make room for vim h/j/k/l keybindings)

## Fixed

- Some more fixes to support (BETA) method_showcase_for:
  - Added method_source gem.
  - Now requiring lens_helper.
  - Changed method to be callable externally
- Extra view margin no longer producible at far end of ANSI strings

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
