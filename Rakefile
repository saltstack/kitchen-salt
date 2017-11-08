require 'bundler/setup'
require 'bundler/gem_tasks'
require 'rake'
require 'rake/testtask'
require 'yard'

Rake::Task.define_task(:environment)

desc 'Run Test Kitchen integration tests'
namespace :integration do
  desc 'Run integration tests with kitchen-docker'
  task :verify, [:taskname] => [:environment] do |task, args|
    args.with_defaults(taskname: 'all')
    require 'kitchen'
    Kitchen.logger = Kitchen.default_file_logger
    @loader = Kitchen::Loader::YAML.new(local_config: '.kitchen.docker.yml')
    Kitchen::Config.new(loader: @loader).instances.each do |instance|
      if args.taskname == 'all' or instance.name.include?(args.taskname)
        instance.verify()
      end
    end
  end

  desc 'destroy instances with kitchen-docker'
  task :destroy, [:taskname] => [:environment] do |task, args|
    args.with_defaults(taskname: 'all')
    require 'kitchen'
    Kitchen.logger = Kitchen.default_file_logger
    @loader = Kitchen::Loader::YAML.new(local_config: '.kitchen.docker.yml')
    Kitchen::Config.new(loader: @loader).instances.each do |instance|
      if args.taskname == 'all' or instance.name.include?(args.taskname)
        instance.destroy()
      end
    end
  end

  desc 'default task'
  task :test, [:taskname] => [:environment] do |task, args|
    args.with_defaults(taskname: 'all')
    Rake::Task['integration:verify'].invoke(args.taskname)
    Rake::Task['integration:destroy'].invoke(args.taskname)
  end
end

desc 'Run yarddoc for the source'
YARD::Rake::YardocTask.new do |yard|
  yard.files = ['lib/**/*.rb', '-', 'INTRODUCTION.md', 'provisioner_options.md', 'docs/**'] # optional
  yard.options = ['--output-dir', 'html/']
end

task :default => ['integration:test']
