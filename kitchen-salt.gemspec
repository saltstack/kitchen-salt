require File.expand_path('../lib/kitchen-salt/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name          = 'kitchen-salt'
  spec.version       = Kitchen::Salt::VERSION
  spec.authors       = ['SaltStack Inc']
  spec.email         = ['daniel@gtmanfred.com']
  spec.homepage      = 'https://github.com/saltstack/kitchen-salt'
  spec.summary       = 'salt provisioner for test-kitchen'
  spec.licenses      = 'Apache-2.0'
  spec.description   = 'salt provisioner for test-kitchen so that you can test all the things'

  spec.files         = `git ls-files lib`.split("\n")
  spec.platform      = Gem::Platform::RUBY
  spec.require_paths = ['lib']
  spec.rubyforge_project = '[none]'

  spec.add_runtime_dependency 'hashie', '>= 3.5'
  spec.add_runtime_dependency 'test-kitchen', '>= 1.4'

  spec.add_development_dependency 'coderay'
  spec.add_development_dependency 'gem-release', '~> 0.7.3'
  spec.add_development_dependency 'kitchen-sync', '~> 2.2'
  spec.add_development_dependency 'maruku'
  spec.add_development_dependency 'pry', '~> 0.10.1'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'yard'
end
