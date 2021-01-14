# frozen_string_literal: true

module Scryglass
  module LensHelper
    def self.method_showcase_for(object)
      # method_list = object.methods - Object.methods
      method_list = object.methods - Object.methods
      return '' if method_list.empty?

      label_space = [method_list.map(&:length).max, 45].min
      method_list.sort.map do |method_name|
        label = method_name.to_s
        label_padding = ' ' * [(label_space - label.length), 0].max
        label = "\e[1;34m#{label}\e[0m" # make blue and bold

        begin
          method = object.method(method_name)

          method_source_location = method.source_location.to_a.join(':')
          source_location_line =
            unless method_source_location.empty?
              "  \e[36m\e[4m#{method_source_location}\e[0m\n" # Cyan, underlined
            end

          highlighted_space = "\e[7m\s\e[0m"
          method_lines = Hexes.capture_io { puts method.source }.split("\n")
          method_lines.prepend('')
          method_source = method_lines.map do |line|
                            '    ' + highlighted_space + line
                          end.join("\n")

          translated_parameters = method.parameters.map do |pair|
            arg_type = pair[0]
            arg_name = pair[1]

            case arg_type
            when :req
              "#{arg_name}"
            when :opt
              "#{arg_name} = ?"
            when :keyreq
              "#{arg_name}:"
            when :key
              "#{arg_name}: ?"
            when :rest
              "*#{arg_name}"
            when :keyrest
              "**#{arg_name}"
            when :block
              "&#{arg_name}"
            end
          end

          arg_preview = "(#{translated_parameters.join(', ')})"

          "#{label} #{arg_preview}\n" +
            source_location_line +
            "#{method_source}\n"
        rescue => e
          "#{label}#{label_padding}  :  " \
            "Error: \e[31m#{e.message}\n\e[0m" +
            (source_location_line || '')
        end
      end.join("\n")
    end
  end
end
