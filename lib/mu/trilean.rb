# frozen_string_literal: true

module Mu
  class Trilean < Attribute
    using AnsilessStringRefinement

    # OPTIONS = [
    #   ["\e[36m<NoChange>\e[0m", nil],
    #   ['true', true],
    #   ['false', false],
    #   ['nil', nil]
    # ].freeze
    OPTIONS = [
      { string: "\e[36m<NoChange>\e[0m", object: nil },
      { string: 'true',                  object: true },
      { string: 'false',                 object: false },
      { string: 'nil',                   object: nil },
    ].freeze

    # *This* could maybe safely modify value_has_changed...
    def edit_ui(coordinates: [1, 1])
      in_ui = true
      selected_index = [:no_change_placeholder, true, false, nil].index(current_value) || 0

      while in_ui
        # $stdout.write "\e[#{coordinates[1]};#{coordinates[0]}H"
        $stdout.write "\e[1;1H"

        # $stdout.print EDIT_PROMPT

        print self.class.dropdown_string(highlighted_index: selected_index, options: OPTIONS)

        user_keypress = $stdin.getch

        case user_keypress
        when "\u0003" # Ctrl + c
          raise IRB::Abort, 'Ctrl+C Detected'
        when *Mu::Session::CURSOR_UP_KEYS
          selected_index = (selected_index - 1) % OPTIONS.count
        when *Mu::Session::CURSOR_DOWN_KEYS
          selected_index = (selected_index + 1) % OPTIONS.count
        when "\r"
          return [false, nil] if selected_index.zero?

          selected_object = OPTIONS[selected_index][:object]
          return [true, selected_object]
        end
      end
    end

    private

  end
end
