source "https://rubygems.org"

gemspec
gem "codeclimate-test-reporter", group: :test, require: nil
gem 'rake'
gem 'berkshelf', '~> 4.0'

group :integration do
  gem 'test-kitchen', '~> 1.2'
  gem "kitchen-salt", :path => '../kitchen-salt'
end

group :vagrant do
  gem 'vagrant-wrapper', '~> 2.0'
  gem 'kitchen-vagrant', '~> 0.18'
end

group :docker do
  gem 'kitchen-docker', '~> 2.1.0'
end

# vi: set ft=ruby :
