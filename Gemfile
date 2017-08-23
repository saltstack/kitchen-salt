source 'https://rubygems.org'

gemspec
gem 'codeclimate-test-reporter', group: :test, require: nil
gem 'rake'
gem 'berkshelf'
gem 'test-kitchen'
gem 'kitchen-sync'

group :vagrant do
  gem 'vagrant-wrapper'
  gem 'kitchen-vagrant'
end

group :windows do
  gem 'winrm', '~>2.0'
  gem 'winrm-fs', '~>1.0'
end

group :docker do
  gem 'kitchen-docker'
end

# vi: set ft=ruby :

