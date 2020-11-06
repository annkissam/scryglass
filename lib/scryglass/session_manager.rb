# frozen_string_literal: true

module Scryglass
  class SessionManager
    using AnsilessStringRefinement
    using ArrayFitToRefinement
    using ClipStringRefinement

    attr_accessor :scry_sessions
    attr_accessor :binding_trackers_by_receiver
    attr_accessor :current_binding_receiver
    attr_accessor :unused_tab_icons

    SESSION_CLOSED_MESSAGE = '(Exited scry! Resume session with just `scry`)'

    NAMED_VARIABLES_MESSAGE = "\nCustom instance variables:"

    def initialize
      self.scry_sessions = []
      self.binding_trackers_by_receiver = {}
      self.current_binding_receiver = nil

      alphabet = ('A'..'Z').to_a
      digits = ('2'..'9').to_a
      self.unused_tab_icons =
        alphabet + digits.product(alphabet).map { |pair| pair.reverse.join }
    end

    # For consistency, we reference the same binding tracker (and thus
    #   console_binding) every time for a given receiver.
    def track_binding!(console_binding)
      self.current_binding_receiver = console_binding.receiver
      self.binding_trackers_by_receiver[current_binding_receiver] ||=
        Scryglass::BindingTracker.new(console_binding: console_binding)
    end

    def <<(session)
      set_current_session!(session)
      session.session_manager = self
      session.tab_icon = unused_tab_icons.shift
      # TODO: name that session?
      self.scry_sessions << session
    end

    def session_tabs_bar
      _screen_height, screen_width = $stdout.winsize

      tab_indicators = scry_sessions.map do |session|
        session.tab_string.clip_at(screen_width / 3, ignore_ansi_codes: true)
      end

      compressed_tab_indicators = tab_indicators.compress_to(screen_width, ignore_ansi_codes: true)

      packed_tabs = compressed_tab_indicators.join
      pad_length = screen_width - packed_tabs.ansiless_length
      packed_tabs + ('#' * pad_length) + "\n" + ('#' * screen_width)
    end

    def current_session
      scry_sessions.find(&:session_is_current)
    end

    def current_console_binding
      current_binding_tracker.console_binding
    end

    def run_scry_ui
      while current_session
        session_return = current_session.run_scry_ui

        case current_session.signal_to_manager
        when :return
          visually_close_ui
          return session_return
        when :quit
          visually_close_ui
          return
        when :quit_from_help
          visually_close_ui(floor_the_cursor: true)
          return
        when :delete
          old_session = current_session
          visually_close_ui
          if scry_sessions.index(old_session) > 0
            change_session_left!
          else
            change_session_right!
          end
          delete_session!(old_session)
        when :change_session_left # and if there's only one session?
          change_session_left!
        when :change_session_right # and if there's only one session?
          change_session_right!
        end
      end
    end

    def current_binding_tracker
      binding_trackers_by_receiver[current_binding_receiver]
    end

    def current_user_named_variables
      current_binding_tracker.user_named_variables
    end

    private

    def visually_close_ui(floor_the_cursor: false)
      _screen_height, screen_width = $stdout.winsize
      current_session.set_console_cursor_below_content(
        floor_the_cursor: floor_the_cursor
      )
      puts '·' * screen_width, "\n"
      puts SESSION_CLOSED_MESSAGE
      puts user_named_variables_outro if current_user_named_variables.any?
    end

    def user_named_variables_outro
      puts NAMED_VARIABLES_MESSAGE
      puts current_user_named_variables.map { |s| "  #{s}\n" }
    end

    def delete_session!(session)
      scry_sessions.delete(session)
    end

    def session_right_of(session)
      return scry_sessions.first if session == scry_sessions.last

      index_of_session = scry_sessions.index(session)
      scry_sessions[index_of_session + 1]
    end

    def session_left_of(session)
      index_of_session = scry_sessions.index(session)
      scry_sessions[index_of_session - 1]
    end

    def change_session_left!
      next_session = session_left_of(current_session)
      set_current_session!(next_session)
    end

    def change_session_right!
      next_session = session_right_of(current_session)
      set_current_session!(next_session)
    end

    def set_current_session!(session)
      scry_sessions.each { |session| session.session_is_current = false }
      session.session_is_current = true
    end
  end
end
