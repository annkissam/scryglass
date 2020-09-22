# frozen_string_literal: true

module Scryglass
  class Config
    using ClipStringRefinement

    attr_accessor :tab_length
    attr_accessor :include_empty_associations,
                  :include_through_associations, :include_scoped_associations,
                  :show_association_types
    attr_accessor :cursor_tracking
    attr_accessor :lenses
    attr_accessor :tree_view_key_string_clip_length,
                  :tree_view_value_string_clip_length
    attr_accessor :dot_coloring

    def initialize
      ## Display
      self.tab_length = 2 # You can make it 0, but please don't make it 0.
      self.tree_view_key_string_clip_length = 200
      self.tree_view_value_string_clip_length = 500
      self.dot_coloring = true

      ## UX
      self.cursor_tracking = [:flexible_range, :dead_center][0] # One or the other
      self.lenses = [ # Custom lenses can easily be added as name+lambda hashes! Or comment some out to turn them off.
        { name: 'Amazing Print (`ap`)',
          lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { ap o } } }, # This has colors!
        { name: 'Pretty Print (`pp`)',
          lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { pp o } } },
        { name: 'Inspect (`.inspect`)',
          lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { puts o.inspect } } },
        { name: 'Yaml Print (`y`)',
          lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { require 'yaml' ; y o } } }, # OR: `puts o.to_yaml`
        { name: 'Puts (`puts`)',
          lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { puts o } } },
        # { name: 'Method Showcase',
        #   lambda: ->(o) { Scryglass::LensHelper.method_showcase_for(o) } },
      ]

      ## AmazingPrint defaults, if the user has not set their own:
      ::AmazingPrint.defaults ||= {
        index: false,  # (Don't display array indices).
        raw:   true,   # (Recursively format instance variables).
      }
      # See https://github.com/amazing-print/amazing_print

      ## Building ActiveRecord association sub-rows:
      self.include_empty_associations = true
      self.include_through_associations = false
      self.include_scoped_associations = false
      self.show_association_types = true
    end

    def validate!
      validate_boolean_attrs!
      validate_positive_integer_attrs!
      validate_cursor_tracking_options!
      validate_lenses!
    end

    private

    def validate_boolean_attrs!
      bool_attrs = [
        :include_empty_associations,
        :include_through_associations,
        :include_scoped_associations,
        :dot_coloring,
      ]
      bool_attrs.each do |bool_attr|
        value = send(bool_attr)
        unless [true, false].include?(value)
          raise ArgumentError, "#{bool_attr} must be true or false."
        end
      end
    end

    def validate_positive_integer_attrs!
      positive_integer_attrs = [
        :tab_length,
        :tree_view_key_string_clip_length,
        :tree_view_value_string_clip_length,
      ]
      positive_integer_attrs.each do |int_attr|
        value = send(int_attr)
        unless value.integer? && value.positive?
          raise ArgumentError, "#{value} is not a positive integer."
        end
      end
    end

    def validate_cursor_tracking_options!
      cursor_tracking_options = [:flexible_range, :dead_center]
      unless cursor_tracking_options.include?(cursor_tracking)
        raise ArgumentError, "#{cursor_tracking.inspect} not in " \
                             "[#{cursor_tracking_options.map(&:inspect).join(', ')}]."
      end
    end

    def validate_lenses!
      raise ArgumentError, 'lenses cannot be empty' unless lenses.any?

      lenses.each do |lens|
        unless lens.is_a?(Hash) && lens[:name].is_a?(String) && lens[:lambda].lambda?
          raise ArgumentError, "Lens #{lens.inspect} must be a hash of the form:" \
                               '{ name: String, lambda: lambda }'
        end
      end
    end
  end
end
