Gem::Specification.new do |spec|
  spec.name = 'yaml_tools'
  spec.version = '1.0.5'
  spec.required_ruby_version = ['>=2.5', '<4']
  spec.add_development_dependency 'rspec', '~> 3.12'
  spec.files = Dir['lib/**/*.rb']
  spec.require_paths = ['lib']
  spec.summary = 'Tools for YAML files.'
  spec.author = 'Atlas Systems, Inc.'
  spec.homepage = 'https://github.com/AtlasSystems/yaml_tools'
  spec.license = 'MIT'
end
