Gem::Specification.new do |spec|
  spec.name = 'yaml_tools'
  spec.version = '1.0.2'
  spec.required_ruby_version = '>= 3.2.0'
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']
  spec.summary = 'Tools for comparing and combining YAML files.'
  spec.author = 'Atlas Systems, Inc.'
end
