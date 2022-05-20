# frozen_string_literal: true

module Mu
  class Session
    using AnsilessStringRefinement

    attr_accessor :target_object, :modifiable_attributes, :optional_save_lambda
    attr_accessor :max_handle_length, :selected_attribute_handle
    attr_accessor :user_signals
    attr_accessor :last_full_error

    CSI = "\e[".freeze # "(C)ontrol (S)equence (I)ntroducer" for ANSI sequences

    CURSOR_DOWN_KEYS = [
      'B',
      'j',
      "\t",
    ].freeze

    CURSOR_UP_KEYS = [
      'A',
      'k',
      'Z', # shift+tab
    ].freeze

    def initialize(target_object, optional_save_lambda: nil)
      self.target_object = target_object
      self.optional_save_lambda = optional_save_lambda
      self.modifiable_attributes = []
      self.user_signals = []
      self.last_full_error = nil

      self.modifiable_attributes = []
      target_object.instance_variables.each do |instance_variable|
        next if instance_variable == :@mu_session

        attr_object = target_object.instance_variable_get(instance_variable)

        # if instance_variable == :@cursor_tracking
        #   self << Mu::Dropdown.new(
        #     handle: instance_variable,
        #     attribute_type: :instance_variable,
        #     # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
        #     options: [['option 1', :option_1], ['The Second Option', :the_second_option], ['Wozers how many are there', :wowzers]],
        #   )
        #   next
        # end
        # self << Mu::Attribute.new(
        #   handle: instance_variable,
        #   attribute_type: :instance_variable,
        #   # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
        # )

        # TODO: should mu_attribute_interpreter be defined in the add_kernel_method ? as {} by default?
        object_has_interpreter = target_object.respond_to?(:mu_attribute_interpreter)
        interpreter =
          if object_has_interpreter
            target_object.mu_attribute_interpreter
          else
            {}
          end
        attribute_specifications = interpreter[instance_variable] || {}

        mu_attribute =
          Mu::Attribute.from_specifications(
            attribute_specifications,
            mu_session: self,
            handle: instance_variable,
            attribute_type: :instance_variable,
          )

        self << mu_attribute
      end

      self.max_handle_length = modifiable_attributes.map(&:handle).map(&:length).max
      self.selected_attribute_handle = modifiable_attributes.first.handle

      ## TODO: AR attributes?
    end

    def <<(mu_attribute)
      self.modifiable_attributes << mu_attribute
      # mu_attribute.mu_session = self (would like it to work this way...)
    end

    def run_mu_ui # TODO: (coordinates: [1, 1])
      in_ui = true

      while in_ui
        # $stdout.write "#{CSI}1;1H" # Moves terminal cursor to top left corner
        screen_string = menu_string_array.join("\n")
        Hexes.overwrite_screen(
          Hexes.opacify_screen_string(
            Hexes.simple_screen_slice(
              screen_string
            )
          )
        )
        $stdout.write "#{CSI}1;1H" # Moves terminal cursor to top left corner

        new_signal = fetch_user_signal

        case new_signal
        when nil
        # TODO: tab and shift tab?
        when 'esc'
          in_ui = false
          print "\n" * (menu_string_array.count + 3)
          if last_full_error
            puts [last_full_error.message, *last_full_error.backtrace].join("\n")
            puts "\n\n    FULL ERROR INFO ABOVE ^\n\n"
          end
        when *CURSOR_UP_KEYS
          move_cursor_up
        when *CURSOR_DOWN_KEYS
          move_cursor_down
        when "\r"
          edit_selected_attribute
        when 's'
          apply_staged_changes
        when 'i' # TODO: decide
          field_interpreter(selected_attribute)
        when "\u0003" # Ctrl + c
          raise IRB::Abort, 'Ctrl+C Detected'
        end
      end
    end

    # TODO: I don't really like these being here just for field_interpreter_ui
    def bare_list(highlighted_index:, options:)
      options.map.with_index do |pair_array, i|
        item_string = pair_array.first
        item_string = "\e[7m#{item_string}\e[0m" if highlighted_index == i
        item_string
      end
    end

    # TODO: I don't really like these being here just for field_interpreter_ui
    def dropdown_string(highlighted_index:, options:)
      list = bare_list(highlighted_index: highlighted_index, options: options)
      bare_list_width = list.map { |string| string.ansiless_length }.max
      filled_list = list.map do |string|
        pad = ' ' * (bare_list_width - string.ansiless_length) # We do it this way because ljust doesn't account for ANSI length
        string + pad
      end

      ## Apply frame
      # filled_list = filled_list.map { |string| "|#{string}|" }
      # cap_bar = '+' + ('—' * bare_list_width) + '+'
      # filled_list = [cap_bar, *filled_list, cap_bar]

      # filled_list = filled_list.map { |string| " |#{string}| " }
      # cap_bar = ' +' + ('—' * bare_list_width) + '+ '
      # blank_bar = ' ' * (bare_list_width + 4)
      # filled_list = [blank_bar, cap_bar, *filled_list, cap_bar, blank_bar]

      filled_list = filled_list.map { |string| " \e[36m|\e[0m#{string}\e[36m|\e[0m " }
      cap_bar = ' +' + ('–' * bare_list_width) + '+ '
      cap_bar = "\e[36m#{cap_bar}\e[0m"
      blank_bar = ' ' * (bare_list_width + 4)
      filled_list = [blank_bar, cap_bar, *filled_list, cap_bar, blank_bar]

      filled_list.join("\n")
    end

    def field_interpreter(attribute)
      begin
        field_type_ui_result = attribute.field_interpreter_ui(coordinates: [1, 1])
        input_was_received = field_type_ui_result[0]
        return unless input_was_received

        chosen_field_type = field_type_ui_result[1]
        attempt_field_interpretation(selected_attribute, chosen_field_type)

        # selected_attribute.valid = true # (Can reset an invalid Mu::Attribute)
      rescue => e
        self.last_full_error = e
        selected_attribute.staged_value = e
        selected_attribute.value_has_changed = true
        selected_attribute.reset_show_string
        selected_attribute.valid = false

      end
    end

    def attempt_field_interpretation(attribute, chosen_field_type)
      attribute_specifications = { type: chosen_field_type }

      case chosen_field_type
      when :dropdown
        converted_options =
          Mu::Dropdown.dropdown_options_array_from(attribute.original_value)
        attribute_specifications[:options] = converted_options
      when :checklist
        converted_options =
          Mu::Checklist.checklist_options_array_from(attribute.original_value)
        attribute_specifications[:options] = converted_options
      end


      new_mu_attribute = Mu::Attribute.from_specifications(
                          attribute_specifications,
                          mu_session: self,
                          handle: attribute.handle,
                          attribute_type: :instance_variable,
                        )
      current_attribute_index = modifiable_attributes.index(selected_attribute)
      modifiable_attributes.delete_at(current_attribute_index)
      modifiable_attributes.insert(current_attribute_index, new_mu_attribute)
    end



    def menu_string_array
      string_array = <<~'TOP_BAR'.split("\n")
        +------------------------------------------------------------------------------+
        |  Move with arrow keys  |  `ENTER` to edit  |  `s` to save  |  `Esc` to exit  |
        +------------------------------------------------------------------------------+
      TOP_BAR

      modifiable_attributes.each do |mu_attribute|
        is_selected = mu_attribute.handle == selected_attribute_handle
        string_array << mu_attribute.to_s(is_selected)
      end

      string_array << <<~'BOTTOM_BAR'.split("\n")
        +------------------------------------------------------------------------------+
      BOTTOM_BAR
    end

    def selected_attribute
      modifiable_attributes.find do |mu_attribute|
        mu_attribute.handle == selected_attribute_handle
      end
    end

    def move_cursor_down
      current_index = modifiable_attributes.index(selected_attribute)
      next_index = current_index + 1
      return if next_index >= modifiable_attributes.count

      next_mu_attribute = modifiable_attributes[next_index]
      self.selected_attribute_handle = next_mu_attribute.handle
    end

    def move_cursor_up
      current_index = modifiable_attributes.index(selected_attribute)
      return if current_index.zero?

      previous_index = current_index - 1

      previous_mu_attribute = modifiable_attributes[previous_index]
      self.selected_attribute_handle = previous_mu_attribute.handle
    end

    def edit_selected_attribute
      begin
        edit_ui_result = selected_attribute.edit_ui(coordinates: [1, menu_string_array.count + 1])
        input_was_received = edit_ui_result.first
        return unless input_was_received

        # user_input = edit_ui_result.last
        # object_received = eval(user_input)
        object_received = edit_ui_result.last
        selected_attribute.valid = true # (Can reset an invalid Mu::Attribute)
      rescue => e
        object_received = e
        self.last_full_error = e
        selected_attribute.valid = false
      end

      selected_attribute.staged_value = object_received # Yeah, even if the value was "the same"
      selected_attribute.value_has_changed = true # Yeah, even if the value was "the same"
      selected_attribute.reset_show_string
    end

    def apply_staged_changes
      unless modifiable_attributes.all?(&:valid)
        print "\a" # Audio "beep"
        return
      end

      modifiable_attributes.each do |mu_attribute|
        next unless mu_attribute.value_has_changed

        # begin
        #   mu_attribute.set_lambda.call(target_object, mu_attribute.handle, mu_attribute.staged_value)
        #   mu_attribute.valid = true
        # rescue => e
        #   mu_attribute.value_has_changed = true
        #   mu_attribute.valid = false
        #   mu_attribute.staged_value = "ERROR: #{e.message}"
        # end

        # next unless mu_attribute.valid

        mu_attribute.set_lambda.call(target_object, mu_attribute.handle, mu_attribute.staged_value)


        mu_attribute.original_value = mu_attribute.staged_value
        mu_attribute.value_has_changed = false
        mu_attribute.staged_value = nil
        mu_attribute.reset_show_string
      end
    end

    def fetch_user_signal
      previous_signal = user_signals.last
      new_signal =
        begin
          Timeout.timeout(0.3) { $stdin.getch }
        rescue Timeout::Error
          nil
        end

      ## Since many keys, including arrow keys, result in several signals being
      ##   sent (e.g. DOWN: "\e" then "[" then "B" in RAPID succession), the
      ##   *pause* after a genuine escape key press (also "\e") is the only way
      ##   to distinguish it precisely.
      genuine_escape_key_press = new_signal.nil? && previous_signal == "\e"
      if genuine_escape_key_press
        new_signal = 'esc'
      end

      user_signals << new_signal unless new_signal.nil? && previous_signal.nil?

      new_signal
    end

    # def last_keypress
    #   last_two_signals = user_signals.last(2)
    #   last_two_signals.last || last_two_signals.first
    # end
  end
end
