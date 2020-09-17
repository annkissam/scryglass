# frozen_string_literal: true

module Scryglass
  module LensHelper
    def method_showcase_for(object)
      method_list = object.methods - Object.methods
      label_space = [method_list.map(&:length).max, 45].min
      method_list.sort.map do |method_name|
        label = method_name.to_s.ljust(label_space, ' ')
        begin
          method = object.method(method_name)
          label + '  :  ' +
            method.source_location.to_a.join(':') + "\n" +
            Hexes.capture_io { puts method.source }
        rescue => e
          label + '  :  Error: ' +
            e.message + "\n"
        end
      end.join("\n")
    end
  end
end
