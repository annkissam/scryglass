# frozen_string_literal: true

module Scryglass
  module LensHelper
    def self.method_showcase_for(object)
      method_list = object.methods - Object.methods
      label_space = [method_list.map(&:length).max, 45].min
      method_list.sort.map do |method_name|
        label = method_name.to_s.ljust(label_space, ' ')
        label = "\e[1;34m#{label}\e[0m" # make blue and bold
        begin
          method = object.method(method_name)
          label + '  :  ' +
            "\e[4m#{method.source_location.to_a.join(':')}\e[0m" + "\n" +
            Hexes.capture_io { puts method.source }
        rescue => e
          label + '  :  ' +
            "Error: \e[31m#{e.message}\n\e[0m" # red
        end
      end.join("\n")
    end
  end
end
