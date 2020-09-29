module Scryglass
  class BindingTracker
    attr_accessor :console_binding, :user_named_variables

    def initialize(console_binding:)
      self.console_binding = console_binding
      self.user_named_variables = []
    end

    def receiver
      console_binding.receiver
    end
  end
end
