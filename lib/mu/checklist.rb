# frozen_string_literal: true

module Mu
  class Checklist < Attribute
    using AnsilessStringRefinement
    using ClipStringRefinement

    attr_accessor :options

    def initialize(mu_session:,
                   handle:,
                   attribute_type:,
                   # data_type:,
                   get_lambda:, # maybe has a default value based on attribute type?
                   set_lambda:, # maybe has a default value based on attribute type?
                   options: nil) # optional for checklist? # TODO: do I utilize this arg anywhere right now?
      super(mu_session: mu_session,
            handle: handle,
            attribute_type: attribute_type,
            # data_type: data_type,
            get_lambda: get_lambda, # maybe has a default value based on attribute type?
            set_lambda: set_lambda) # maybe has a default value based on attribute type?

      # TODO: allow checklist to work on a hash as well?
      self.options = options || Checklist.checklist_options_array_from(original_value)

      self.options.prepend(
        { checked: false, string: "\e[36m<NoChange>\e[0m",       object: nil },
        { checked: false, string: "\e[36m<ApplyChecklist>\e[0m", object: nil },
      )
    end

    def self.checklist_options_array_from(object)
      object.to_a.map do |item|
        {
          checked: true,
          string: item.inspect.clip_at(80, ignore_ansi_codes: true).gsub("\n", "\\n"),
          object: item,
        }
      end
    end

    # # TODO: redundant now maybe
    # def options_from_original_value
    #   self.original_value.map do |object|
    #     {
    #       checked: true,
    #       string: object.inspect.clip_at(80, ignore_ansi_codes: true).gsub("\n", "\\n"),
    #       object: object,
    #     }
    #   end
    # end

    def edit_ui(coordinates: [1, 1])
      in_ui = true
      selected_index = 0

      while in_ui
        # $stdout.write "\e[#{coordinates[1]};#{coordinates[0]}H"
        $stdout.write "\e[1;1H"

        # $stdout.print EDIT_PROMPT

        print self.class.dropdown_string(highlighted_index: selected_index,
                              options: options)

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
          return [true, object_array_from_options] if selected_index == 1

          selected_item_is_checked = self.options[selected_index][:checked]
          self.options[selected_index][:checked] = !selected_item_is_checked
        end
      end
    end

    # def self.bare_list(highlighted_index:, options:)
    #   options.map.with_index do |item_hash, i|
    #     item_string = item_hash[:string]
    #     item_string = "\e[7m#{item_string}\e[0m" if highlighted_index == i
    #     check_indicator = item_hash[:checked] ? "\e[36m*\e[0m " : '  '
    #
    #     check_indicator + item_string
    #   end
    # end

    private

    def object_array_from_options
      checked_items = options.select { |item_hash| item_hash[:checked] }
      checked_items.map { |item_hash| item_hash[:object] }
    end
  end
end
