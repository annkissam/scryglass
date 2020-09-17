# frozen_string_literal: true

module Scryglass
  class ViewWrapper
    attr_accessor :model, :string, :string_lambda

    def initialize(model, string: nil, string_lambda: nil)
      unless !!string ^ !!string_lambda
        raise ArgumentError, 'Must provide either `string` or `string_lambda`, ' \
                             'but not both.'
      end

      self.model = model
      self.string = string
      self.string_lambda = string_lambda
    end

    def to_s
      return string if string
      return string_lambda.call(model) if string_lambda
    end
  end
end
