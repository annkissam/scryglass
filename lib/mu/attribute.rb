# frozen_string_literal: true

module Mu
  class Attribute
    using AnsilessStringRefinement

    attr_accessor :mu_session # set with session<<attribute
    attr_accessor :handle, # / 'symbol' / 'name'
                  :data_type,
                  # attribute_type: instance_variable, ar_field, ar_relation???,
                  :attribute_type,
                  :get_lambda, :set_lambda,
                  :original_value, :value_has_changed, :staged_value, :valid,
                  :original_value_show_string, :staged_value_show_string

    # EDIT_PROMPT = "\e[36m>_\e[0m"

    # FIELD_INTERPRETER_OPTIONS = [
    #   ["\e[36m<NoChange>\e[0m", nil], # TODO: setup the proper logic for this  with [false, nil] etc
    #   ['Boolean', :boolean],
    #   ['Trilean', :trilean],
    #   ['Checklist', :checklist],
    #   ['Dropdown', :checklist],
    #   ['Eval Edit (the default)', nil],
    # ].freeze
    FIELD_INTERPRETER_OPTIONS = [
      { string: "\e[36m<NoChange>\e[0m",   object: nil }, # TODO: setup the proper logic for this  with [false, nil] etc
      { string: 'Boolean',                 object: :boolean },
      { string: 'Trilean',                 object: :trilean },
      { string: 'Checklist',               object: :checklist },
      { string: 'Dropdown',                object: :dropdown },
      { string: 'Eval Edit (the default)', object: nil },
    ].freeze

    def default_get_lambda
      {
        instance_variable: ->(target, attr_handle) { target.instance_variable_get(attr_handle) }
      }
    end

    def default_set_lambda
      {
        instance_variable: ->(target, attr_handle, val) { target.instance_variable_set(attr_handle, val) }
      }
    end

    def initialize(mu_session:,
                   handle:,
                   attribute_type:,
                   # data_type:,
                   get_lambda: nil, # maybe has a default value based on attribute type?
                   set_lambda: nil) # maybe has a default value based on attribute type?
      self.mu_session = mu_session
      self.handle = handle
      self.attribute_type = attribute_type
      self.data_type = data_type
      self.value_has_changed = false
      self.staged_value = nil
      self.valid = true

      self.get_lambda = get_lambda || default_get_lambda[attribute_type]
      self.set_lambda = set_lambda || default_set_lambda[attribute_type]
      self.original_value = self.get_lambda.call(mu_session.target_object, handle)
      self.original_value_show_string = self.class.summary_string_from(original_value)
      self.staged_value_show_string = nil
    end

    def self.summary_string_from(object)
      Hexes.capture_io(char_limit: 100) { puts object.inspect }.chomp.gsub("\n", "\\n")
    end

    def reset_show_string
      if value_has_changed
        self.staged_value_show_string = self.class.summary_string_from(staged_value)
      else
        self.original_value_show_string = self.class.summary_string_from(original_value)
      end
    end

    def self.from_specifications(attribute_specifications, **args)
      case attribute_specifications[:type]
      when nil # non-specified, unknown type. Use general "edit" attribute
        Mu::Attribute.new(
          **args,
          # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
        )
      when :dropdown
        Mu::Dropdown.new(
          **args,
          # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
          options: attribute_specifications[:options],
          get_lambda: attribute_specifications[:get_lambda],
          set_lambda: attribute_specifications[:set_lambda],
        )
      when :boolean
        Mu::Boolean.new(
          **args,
          # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
          get_lambda: attribute_specifications[:get_lambda],
          set_lambda: attribute_specifications[:set_lambda],
        )
      when :trilean
        Mu::Trilean.new(
          **args,
          attribute_type: :instance_variable,
          # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
          get_lambda: attribute_specifications[:get_lambda],
          set_lambda: attribute_specifications[:set_lambda],
        )
      when :checklist
        Mu::Checklist.new(
          **args,
          # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
          get_lambda: attribute_specifications[:get_lambda],
          set_lambda: attribute_specifications[:set_lambda],
        )
      else # base Mu::Attribute type
        Mu::Attribute.new(
          **args,
          # data_type: attr_object.class, # this could be nil for things that might sometimes be other classes... Should be customizable
          get_lambda: attribute_specifications[:get_lambda],
          set_lambda: attribute_specifications[:set_lambda],
        )
      end
    end

    def current_value
      if value_has_changed
        staged_value
      else
        original_value
      end
    end

    def to_s(is_selected)
      key = handle.to_s.rjust(mu_session.max_handle_length, ' ')
      spacer = value_has_changed ? ' --> ' : '  :  '


      # Note: `.inspect` may return *true newlines* for objects with a custom
      #   `.inspect`, which will sabotage the display, so we gsub thusly:
      value =
        if value_has_changed
          staged_value_show_string
        else
          original_value_show_string
        end
      value = "\e[7m#{value}\e[0m" if is_selected

      key + spacer + value
    end

    def edit_prompt
      base_to_s_method = Kernel.instance_method(:to_s)
      base_to_s_method_for_object = base_to_s_method.bind(mu_session.target_object)
      self_string = base_to_s_method_for_object.call

      "(\`self\` is #{self_string})\n\e[36m>_\e[0m"
    end

    # Different types of Attributes will have their own 'edit_ui'
    def edit_ui(coordinates: [1, 1])
      $stdout.write "\e[#{coordinates[1]};#{coordinates[0]}H"
      # $stdout.print EDIT_PROMPT
      $stdout.print edit_prompt

      user_input = $stdin.gets.chomp
      return [false, nil] if user_input.empty?

      mu_session.target_object.instance_eval do
        begin
          eval_result = eval(user_input)
          return [true, eval_result]
        rescue => e
          # Rescuing and raising allows the rescue in
          #   Mu::Session#edit_selected_attribute to capture all errors.
          #   Otherwise, eval('nil.nil') will be caught, but eval('abc123') will
          #   NOT and will break the mu session.
          raise e
        end
      end
    end

    def self.bare_list(highlighted_index:, options:)
      options.map.with_index do |item_hash, i|
        item_string = item_hash[:string]
        item_string = "\e[7m#{item_string}\e[0m" if highlighted_index == i
        potential_check_indicator =
          if item_hash[:checked].nil?
            ''
          elsif item_hash[:checked]
            "\e[36m*\e[0m "
          else
            '  '
          end

        potential_check_indicator + item_string
      end
    end

    def self.dropdown_string(highlighted_index:, options:)
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

    def field_interpreter_ui(attribute)
      in_ui = true
      selected_index = 0
      field_options = FIELD_INTERPRETER_OPTIONS

      while in_ui
        $stdout.write "\e[1;1H"

        print Attribute.dropdown_string(
                highlighted_index: selected_index,
                options: field_options,
              )

        # TODO: could extract everything below, and have it call to a "dropdown_enter_action" method
        user_keypress = $stdin.getch

        case user_keypress
        when "\u0003" # Ctrl + c
          raise IRB::Abort, 'Ctrl+C Detected'
        when *Mu::Session::CURSOR_UP_KEYS
          selected_index = (selected_index - 1) % field_options.count
        when *Mu::Session::CURSOR_DOWN_KEYS
          selected_index = (selected_index + 1) % field_options.count
        when "\r"
          return [false, nil] if selected_index.zero?

          selected_object = field_options[selected_index][:object]
          return [true, selected_object]
        end
      end
    end
  end
end
