# encoding: utf-8

$:.unshift File.expand_path('../lib', __FILE__)
require 'kitchen-salt/version'

Gem::Specification.new do |s|
  s.name          = "kitchen-salt"
  s.version       = Kitchen::Salt::VERSION
  s.authors       = ["Simon McCartney"]
  s.email         = ["simon@mccartney.ie"]
  s.homepage      = "https://github.com//kitchen-salt"
  s.summary       = "salt provisioner for test-kitchen"
  s.licenses      = "Apache-2.0"
  s.description   = "salt provisioner for test-kitchen so that you can test all the things"

  s.files         = `git ls-files app lib`.split("\n")
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.rubyforge_project = '[none]'

  s.add_runtime_dependency 'test-kitchen', '~> 1.4'

  s.add_development_dependency 'rspec', '~> 3.2'
  s.add_development_dependency 'pry', '~> 0.10.1'
  s.add_development_dependency 'gem-release', '~> 0.7.3'
end
