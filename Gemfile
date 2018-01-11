source 'https://rubygems.org'

gemspec
gem 'hashie'
gem 'json'
gem 'kitchen-sync'
gem 'test-kitchen'

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

group :git do
  gem 'git'
end
# vi: set ft=ruby :
