require 'rake'
require 'rake/testtask'
require 'bundler/setup'

Rake::Task.define_task(:environment)

desc 'Run Test Kitchen integration tests'
namespace :integration do
  desc 'Run integration tests with kitchen-docker'
  task :docker, [:taskname] => [:environment] do |task, args|
    require 'kitchen'
    Kitchen.logger = Kitchen.default_file_logger
    @loader = Kitchen::Loader::YAML.new(local_config: '.kitchen.docker.yml')
    threads = []
    Kitchen::Config.new(loader: @loader).instances.each do |instance|
      if instance.name.include?(args.taskname)
        instance.test(:always)
      end
    end
  end
end
