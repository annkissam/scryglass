# frozen_string_literal: true

## Bookkeeping
require "scryglass/version"

## External tools:
require 'io/console'
require 'stringio'
require 'pp'
require 'amazing_print' # For use as a lens
require 'method_source' # For use in lens_helper
require 'binding_of_caller'
require 'timeout'

## Refinements and sub-tools:
require 'refinements/ansiless_string_refinement'
require 'refinements/clip_string_refinement'
require 'refinements/constant_defined_string_refinement'
require 'refinements/array_fit_to_refinement'
require 'scryglass/lens_helper'
require 'hexes'
require 'prog'

## Core gem components:
require 'scryglass/config'
require 'scryglass/ro'
require 'scryglass/ro_builder'
require 'scryglass/binding_tracker'
require 'scryglass/session'
require 'scryglass/session_manager'
require 'scryglass/view_wrapper'
require 'scryglass/view_panel'
require 'scryglass/tree_panel'
require 'scryglass/lens_panel'

## Testing and Demoing:
require 'example_material.rb'
#test
module Scryglass
  HELP_SCREEN = <<~"HELPSCREENPAGE"
          \e[36mq\e[0m : Quit Scry                               \e[36m?\e[0m : Cycle help panels (1/2)

    BASIC NAVIGATION: · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
      ·                                                                               ·
      ·   \e[36mUP / DOWN\e[0m : Navigate (To move further, type a number first or use \e[36mSHIFT\e[0m)    ·
      ·   \e[36mRIGHT\e[0m     : Expand   current or selected row(s)                             ·
      ·   \e[36mLEFT\e[0m      : Collapse current or selected row(s)                             ·
      ·                                                                               ·
      ·               (\e[36mh/j/k/l\e[0m  on the home row can also serve as arrow keys)         ·
      ·                                                                               ·
      ·   \e[36mENTER\e[0m : Close Scry, returning current or selected object(s) (Key or Value)  ·
      ·                                                                               ·
      · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·

    INSPECTING WITH LENS VIEW:  · · · · · · · · · · · · · ·
      ·                                                   ·
      ·   \e[36mSPACEBAR\e[0m : Toggle Lens View                     ·
      ·   \e[36m     >  \e[0m : Cycle through lens types             ·
      ·   \e[36m   <    \e[0m : Toggle subject  (Key/Value of row)   ·
      ·                                                   ·
      · · · · · · · · · · · · · · · · · · · · · · · · · · ·

    MORE NAVIGATION:  · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
      ·                                                                       ·
      ·   \e[36m   [w]   \e[0m :  Move view window           \e[36m0\e[0m : Reset view location     ·
      ·   \e[36m[a][s][d]\e[0m   (\e[36mALT\e[0m increases speed)      (Press again: reset cursor)  ·
      ·                                                                       ·
      · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
  HELPSCREENPAGE

  HELP_SCREEN_ADVANCED = <<~"HELPSCREENADVANCEDPAGE"
          \e[36mq\e[0m : Quit Scry                               \e[36m?\e[0m : Cycle help panels (2/2)

    ADVANCED: · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
      ·  DIGGING DEEPER:                                                                    ·
      ·    For current or selected row(s)...                                                ·
      ·      \e[36m@\e[0m : Build instance variable sub-rows                                           ·
      ·      \e[36m.\e[0m : Build ActiveRecord association sub-rows                                    ·
      ·      \e[36m(\e[0m : Attempt to smart-build sub-rows, if Enumerable. Usually '@' is preferable. ·
      ·      \e[36mo\e[0m : Quick Open: builds the most likely helpful sub-rows ( '.' || '@' || '(' )  ·
      ·                                                                                     ·
      ·  SELECTING ROWS:                                                                    ·
      ·    \e[36m*\e[0m : Select/Deselect ALL rows                                                     ·
      ·    \e[36m|\e[0m : Select/Deselect every sibling row under the same parent row                  ·
      ·    \e[36m-\e[0m : Select/Deselect current row                                                  ·
      ·                                                                                     ·
      ·  MANAGING MULTIPLE SESSION TABS:                                                    ·
      ·    \e[36mTab\e[0m : Change session tab (to the right)  (\e[36mShift+Tab\e[0m moves left)                  ·
      ·      \e[36mQ\e[0m : Close current session tab                                                  ·
      ·                                                                                     ·
      ·  TEXT SEARCH:                                                                       ·
      ·    \e[36m/\e[0m : Begin a text search (in tree view)                                           ·
      ·    \e[36mn\e[0m : Move to next search result                                                   ·
      ·                                                                                     ·
      ·                                                                                     ·
      ·  \e[36m=\e[0m   : Open prompt to type a console handle for current or selected row(s)            ·
      ·                                                                                     ·
      ·  \e[36mEsc\e[0m : Resets selection, last search, and number-to-move. (or returns to Tree View) ·
      ·                                                                                     ·
      · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · · ·
  HELPSCREENADVANCEDPAGE

  def self.config
    @config ||= Config.new
  end

  def self.reset_config
    @config = Config.new
  end

  def self.configure
    yield(config)
  end

  def self.load_silently
    begin
      add_kernel_method
      create_scryglass_session_manager
      { success: true, error: nil }
    rescue => e
      { success: false, error: e }
    end
  end

  def self.load
    caller_path = caller_locations.first.path

    silent_load_result = Scryglass.load_silently

    if silent_load_result[:success]
      puts "(Scryglass is loaded, from `#{caller_path}`. Use `Scryglass.help` for help getting started)"
    else
      puts "(Scryglass failed to load, from `#{caller_path}` " \
           "getting `#{silent_load_result[:error].message}`)"
    end

    silent_load_result
  end

  def self.help
    console_help = <<~"CONSOLE_HELP" # Bolded with \e[1m
      \e[1m
      |  To prep Scryglass, call `Scryglass.load`
      |  (Or add it to .irbrc & .pryrc)
      |
      |  To start a Scry Session, call:
      |  >   scry my_object   OR
      |  >   my_object.scry
      |
      |  To resume the previous session:   (in same console session)
      |  >   scry
      \e[0m
    CONSOLE_HELP

    puts console_help
  end

  private

  def self.create_scryglass_session_manager
    $scry_session_manager = Scryglass::SessionManager.new
  end

  def self.add_kernel_method
    Kernel.module_eval do
      def scry(arg = nil, _actions = nil)
        # `actions` can't be a keyword arg due to this ruby issue:
        #   https://bugs.ruby-lang.org/issues/8316

        Scryglass.config.validate!

        current_console_binding = binding.of_caller(1)

        receiver_is_just_the_console = self == current_console_binding.receiver
        receiver = self unless receiver_is_just_the_console
        # As in: `receiver.scry`,
        #   and no receiver means scry was called on 'main', (unless self is
        #   different in the because you've pry'd into something!)

        seed_object = arg || receiver

        if seed_object
          # If it's been given an arg or receiver, create new session!
          # The global variable is purposeful, and not accessible outside of
          #   the one particular console instance.
          $scry_session_manager << Scryglass::Session.new(seed_object)
        end

        unless $scry_session_manager.current_session
          raise ArgumentError,
                '`scry` requires either an argument, a receiver, or a past' \
                'session to reopen. try `Scryglass.help`'
        end

        $scry_session_manager.track_binding!(current_console_binding)

        begin
          Hexes.stdout_rescue do
            $scry_session_manager.run_scry_ui
          end
        rescue => e # Here we ensure good visibility in case of errors
          screen_height, _screen_width = $stdout.winsize
          $stdout.write "\e[#{screen_height};1H\n" # (Moves console cursor to bottom left corner)
          raise e
        end
      end
    end
  end
end
