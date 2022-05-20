# frozen_string_literal: true

module Mu
  class Dropdown < Attribute
    using ClipStringRefinement

    attr_accessor :options

    def initialize(mu_session:,
                   handle:,
                   attribute_type:,
                   # data_type:,
                   get_lambda:, # maybe has a default value based on attribute type?
                   set_lambda:, # maybe has a default value based on attribute type?
                   options:)
      unless options.is_a?(Array) &&
             options.any? &&
             options.all? { |o| o.is_a?(Hash) && o[:string] && o[:object] }
        raise ArgumentError, '`options:` must be an array of hashes with {string:, object:} keys.'
      end

      # TODO: clip and gsub options
      # .clip_at(80, ignore_ansi_codes: true).gsub("\n", "\\n")

      super(mu_session: mu_session,
            handle: handle,
            attribute_type: attribute_type,
            # data_type: data_type,
            get_lambda: get_lambda, # maybe has a default value based on attribute type?
            set_lambda: set_lambda) # maybe has a default value based on attribute type?

      clipped_options = options.map do |item_hash|
        {
          string: item_hash[:string].clip_at(80, ignore_ansi_codes: true).gsub("\n", "\\n"),
          object: item_hash[:object],
        }
      end
      self.options = clipped_options.prepend({ string: "\e[36m<NoChange>\e[0m", object: nil })
    end

    def self.dropdown_options_array_from(object)
      object.to_a.map do |item|
        {
          string: item.inspect.clip_at(80, ignore_ansi_codes: true).gsub("\n", "\\n"),
          object: item,
        }
      end
    end

    def edit_ui(coordinates: [1, 1])
      in_ui = true
      selected_index = 0

      while in_ui
        # $stdout.write "\e[#{coordinates[1]};#{coordinates[0]}H"
        $stdout.write "\e[1;1H"

        # $stdout.print EDIT_PROMPT

        print self.class.dropdown_string(highlighted_index: selected_index, options: options)

        # TODO: could extract everything below, and have it call to a "dropdown_enter_action" method
        user_keypress = $stdin.getch

        case user_keypress
        when "\u0003" # Ctrl + c
          raise IRB::Abort, 'Ctrl+C Detected'
        when *Mu::Session::CURSOR_UP_KEYS
          selected_index = (selected_index - 1) % options.count
        when *Mu::Session::CURSOR_DOWN_KEYS
          selected_index = (selected_index + 1) % options.count
        when "\r"
          return [false, nil] if selected_index.zero?

          selected_object = options[selected_index][:object]
          return [true, selected_object]
        end
      end
    end

    private


  end
end
