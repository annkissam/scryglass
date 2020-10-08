
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "scryglass/version"

Gem::Specification.new do |spec|
  spec.name          = "scryglass"
  spec.version       = Scryglass::VERSION
  spec.authors       = ["Gavin Myers"]
  spec.email         = ["gavin.myers@annkissam.com"]
  spec.licenses      = ['MIT']

  spec.summary       = 'Scryglass is a ruby console tool for visualizing ' \
    'and actively exploring objects.'
  spec.description   = 'Scryglass is a ruby console tool for visualizing ' \
    'and actively exploring objects (large, nested, interrelated, ' \
    'or unfamiliar). You can navigate nested arrays, hashes, instance variables, ' \
    'ActiveRecord relations, and unknown Enumerable types like an' \
    "expandable/collapsable file tree in an intuitive UI.\n\n" \
    'Objects and child objects can also be inspected through a variety of ' \
    'display lenses, returned directly to the console, and more!'
  spec.homepage      = "https://github.com/annkissam/scryglass"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = 'https://rubygems.org/'
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.5.3'

  spec.add_development_dependency 'bundler', '~> 2.1'
  spec.add_development_dependency 'rake', '~> 12.0'
  spec.add_development_dependency 'pry-rescue'
  spec.add_runtime_dependency 'amazing_print'
  spec.add_runtime_dependency 'method_source'
  spec.add_runtime_dependency 'binding_of_caller'
end
