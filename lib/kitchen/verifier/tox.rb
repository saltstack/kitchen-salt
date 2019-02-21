# -*- encoding: utf-8 -*-

require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Tox < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :testingdir, '/testing'
      default_config :tests, []
      default_config :transport, false
      default_config :save, {}
      default_config :windows, false
      default_config :verbose, false
      default_config :run_destructive, false
      default_config :ssh_tests, true
      default_config :proxy_tests, false
      default_config :pytest, false
      default_config :coverage, false
      default_config :junitxml, false
      default_config :from_filenames, []
      default_config :enable_filenames, false
      default_config :passthrough_opts, []
      default_config :output_columns, 120
      default_config :sysinfo, true

      def call(state)
        info("[#{name}] Verify on instance #{instance.name} with state=#{state}")
        root_path = (config[:windows] ? '%TEMP%\\kitchen' : '/tmp/kitchen')
        if ENV['KITCHEN_TESTS']
          ENV['KITCHEN_TESTS'].split(' ').each{|test| config[:tests].push(test)}
        end
        toxenv = instance.suite.name
        if config[:pytest]
          toxenv = "#{toxenv}-pytest"
          tests = config[:tests].join(' ')
        else
          toxenv = "#{toxenv}-runtests"
          tests = config[:tests].collect{|test| "-n #{test}"}.join(' ')
        end
        if config[:coverage]
          toxenv = "#{toxenv}-coverage"
        end

        if config[:enable_filenames] and ENV['CHANGE_TARGET'] and ENV['BRANCH_NAME']
          require 'git'
          repo = Git.open(Dir.pwd)
          config[:from_filenames] = repo.diff("origin/#{ENV['CHANGE_TARGET']}",
                                              "origin/#{ENV['BRANCH_NAME']}").name_status.keys.select{|file| file.end_with?('.py')}
        end

        if config[:junitxml]
          junitxml = File.join(root_path, config[:testingdir], 'artifacts', 'xml-unittests-output')
          if config[:pytest]
            junitxml = "--junitxml=#{File.join(junitxml, 'test-results.xml')}"
          else
            junitxml = "--xml=#{junitxml}"
          end
        end

        # Be sure to copy the remote artifacts directory to the local machine
        save = {
          "#{File.join(root_path, config[:testingdir], 'artifacts')}" => "#{Dir.pwd}/"
        }
        # Hash insert order matters, that's why we define a new one and merge
        # the one from config
        save.merge!(config[:save])

        command = [
          'tox -c',
          File.join(root_path, config[:testingdir], 'tox.ini'),
          "-e #{toxenv}",
          '--',
          "--output-columns=#{config[:output_columns]}",
          (config[:sysinfo] ? '--sysinfo' : ''),
          (config[:junitxml] ? junitxml : ''),
          (config[:windows] ? "--names-file=#{root_path}\\testing\\tests\\whitelist.txt" : ''),
          (config[:transport] ? "--transport=#{config[:transport]}" : ''),
          (config[:verbose] ? '-vv' : '-v'),
          (config[:run_destructive] ? "--run-destructive" : ''),
          (config[:ssh_tests] ? "--ssh-tests" : ''),
          (config[:proxy_tests] ? "--proxy-tests" : ''),
          config[:passthrough_opts].join(' '),
          (config[:from_filenames].any? ? "--from-filenames=#{config[:from_filenames].join(',')}" : ''),
          tests,
          '2>&1',
        ].join(' ')
        if config[:windows]
           command = "cmd.exe /c \"#{command}\" 2>&1"
        end
        info("Running Command: #{command}")
        instance.transport.connection(state) do |conn|
          begin
            if config[:windows]
              conn.execute('$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")')
              conn.execute("$env:PythonPath = [Environment]::ExpandEnvironmentVariables(\"#{root_path}\\testing\")")
            else
              begin
                conn.execute(sudo("chown -R $USER #{root_path}"))
              rescue => e
                error("Failed to chown #{root_path} :: #{e}")
              end
            end
            begin
              conn.execute(sudo(command))
            rescue => e
              info("Verify command failed :: #{e}")
            end
          ensure
            save.each do |remote, local|
              unless config[:windows]
                begin
                  conn.execute(sudo("chmod -R +r #{remote}"))
                rescue => e
                  error("Failed to chown #{remote} :: #{e}")
                end
              end
              begin
                info("Copying #{remote} to #{local}")
                conn.download(remote, local)
              rescue => e
                error("Failed to copy #{remote} to #{local} :: #{e}")
              end
            end
          end
        end
        debug("[#{name}] Verify completed.")
      end
    end
  end
end
