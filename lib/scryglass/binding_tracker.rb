module Scryglass
  class BindingTracker
    attr_accessor :console_binding, :user_named_variables

    def initialize(console_binding:)
      self.user_named_variables = []
      self.console_binding = console_binding
    end
  end
end
