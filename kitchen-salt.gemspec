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
  s.description   = "salt provisioner for test-kitchen"

  s.files         = `git ls-files app lib`.split("\n")
  s.platform      = Gem::Platform::RUBY
  s.require_paths = ['lib']
  s.rubyforge_project = '[none]'
end
