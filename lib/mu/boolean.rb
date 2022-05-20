# frozen_string_literal: true

module Mu
  class Boolean < Attribute
    # *This* could safely flip value_has_changed each time...
    def edit_ui(*)
      # value =
      #   if value_has_changed
      #     staged_value
      #   else
      #     original_value
      #   end
      [true, !current_value]
    end
  end
end
