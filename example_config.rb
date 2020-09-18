# frozen_string_literal: true

Scryglass.configure do |config|
  ## Display
  # config.tab_length = 2 # Default: 2
  # config.tree_view_key_string_clip_length = 200 # Default: 200
  # config.tree_view_value_string_clip_length = 500 # Default: 500
  # config.dot_coloring = true # Default: true

  ## UX
  # config.cursor_tracking = [:flexible_range, :dead_center][0] # Default: [0]
  # config.lenses = [ # Custom lenses can easily be added as name+lambda hashes! Or comment some out to turn them off.
  #   { name: 'Pretty Print (`pp`)',
  #     lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { pp o } } },
  #   { name: 'Inspect (`.inspect`)',
  #     lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { puts o.inspect } } },
  #   { name: 'Yaml Print (`y`)',
  #     lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { require 'yaml' ; y o } } }, # OR: `puts o.to_yaml`
  #   { name: 'Puts (`puts`)',
  #     lambda: ->(o) { Hexes.capture_io(char_limit: 20_000) { puts o } } },
  #   # { name: 'Method Showcase',  # Not included by default
  #   #   lambda: ->(o) { Scryglass::LensHelper.method_showcase_for(o) } },
  # ]

  ## Building ActiveRecord association sub-rows:
  # config.include_empty_associations = true # Default: true
  # config.include_through_associations = false # Default: false
  # config.include_scoped_associations = false # Default: false
  # config.show_association_types = true # Default: true
end
