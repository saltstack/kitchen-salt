# -*- encoding: utf-8 -*-

require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Nox < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :testingdir, '/testing'
      default_config :tests, []
      default_config :save, {}
      default_config :windows, false
      default_config :verbose, false
      default_config :run_destructive, false
      default_config :pytest, false
      default_config :coverage, false
      default_config :junitxml, false
      default_config :from_filenames, []
      default_config :enable_filenames, false
      default_config :passthrough_opts, []
      default_config :output_columns, 120
      default_config :sysinfo, true
      default_config :sys_stats, false

      def call(state)
        info("[#{name}] Verify on instance #{instance.name} with state=#{state}")
        root_path = (config[:windows] ? '%TEMP%\\kitchen' : '/tmp/kitchen')
        if ENV['KITCHEN_TESTS']
          ENV['KITCHEN_TESTS'].split(' ').each{|test| config[:tests].push(test)}
        end

        if ENV['NOX_ENABLE_FROM_FILENAMES']
          config[:enable_filenames] = true
        end

        if ENV['NOX_PASSTHROUGH_OPTS']
          ENV['NOX_PASSTHROUGH_OPTS'].split(' ').each{|opt| config[:passthrough_opts].push(opt)}
        end

        if ENV['NOX_ENV_NAME']
          noxenv = ENV['NOX_ENV_NAME']
        else
          # Default to runtests-zeromq
          noxenv = "runtests-zeromq"
        end

        # Is the nox env alreay including the Python version?
        if not noxenv.match(/^(.*)-([\d]{1})(\.([\d]{1}))?$/)
          # Nox env's are not py<python-version> named, they just use the <python-version>
          # Additionally, nox envs are parametrised to enable or disable test coverage
          # So, the line below becomes something like:
          #   runtests-2(coverage=True)
          #   pytest-3(coverage=False)
          suite = instance.suite.name.gsub('py', '').gsub('2', '2.7')
          noxenv = "#{noxenv}-#{suite}"
        end
        noxenv = "#{noxenv}(coverage=#{config[:coverage] ? 'True' : 'False'})"

        if noxenv.include? "pytest"
          tests = config[:tests].join(' ')
          if config[:sys_stats]
            sys_stats = '--sys-stats'
          else
            sys_stats = ''
          end
        elsif noxenv.include? "runtests"
          tests = config[:tests].collect{|test| "-n #{test}"}.join(' ')
          sys_stats = ''
        end

        if config[:enable_filenames] and ENV['CHANGE_TARGET'] and ENV['BRANCH_NAME']
          require 'git'
          repo = Git.open(Dir.pwd)
          config[:from_filenames] = repo.diff("origin/#{ENV['CHANGE_TARGET']}",
                                              "origin/#{ENV['BRANCH_NAME']}").name_status.keys.select{|file| file.end_with?('.py')}
        end

        if config[:junitxml]
          junitxml = File.join(root_path, config[:testingdir], 'artifacts', 'xml-unittests-output')
          if noxenv.include? "pytest"
            junitxml = "--junitxml=#{File.join(junitxml, 'test-results.xml')}"
          else
            junitxml = "--xml=#{junitxml}"
          end
        end

        # Be sure to copy the remote artifacts directory to the local machine
        if config[:windows]
          save = {'$env:KitchenTestingDir/artifacts/' => "#{Dir.pwd}"}
        else
          save = {"#{File.join(root_path, config[:testingdir], 'artifacts')}/" => "#{Dir.pwd}"}
        end
        # Hash insert order matters, that's why we define a new one and merge
        # the one from config
        save.merge!(config[:save])

        command = [
          'nox',
          "-f #{File.join(root_path, config[:testingdir], 'noxfile.py')}",
          (config[:windows] ? "-e #{noxenv}" : "-e '#{noxenv}'"),
          '--',
          "--output-columns=#{config[:output_columns]}",
          sys_stats,
          (config[:sysinfo] ? '--sysinfo' : ''),
          (config[:junitxml] ? junitxml : ''),
          (config[:verbose] ? '-vv' : '-v'),
          (config[:run_destructive] ? '--run-destructive' : ''),
          config[:passthrough_opts].join(' '),
        ].join(' ')

        if tests.nil? || tests.empty?
          # If we're not targetting specific tests...
          extra_command = [
            (config[:from_filenames].any? ? "--from-filenames=#{config[:from_filenames].join(',')}" : ''),
            (config[:windows] ? "--names-file=#{root_path}\\testing\\tests\\whitelist.txt" : ''),
            # By default, always runs unit tests on windows
            # XXX: We should stop doing this logic as soon as possible
            (config[:windows] ? "--unit" : ''),
          ].join(' ')
          command = "#{command} #{extra_command}"
        else
          command = "#{command} #{tests}"
        end

        if config[:windows]
          command = "cmd.exe /c --% \"#{command}\" 2>&1"
        end
        info("Running Command: #{command}")
        instance.transport.connection(state) do |conn|
          begin
            if config[:windows]
              conn.execute('$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")')
              conn.execute("$env:PythonPath = [Environment]::ExpandEnvironmentVariables(\"#{File.join(root_path, config[:testingdir])}\")")
              conn.execute("[Environment]::SetEnvironmentVariable(\"KitchenTestingDir\", [Environment]::ExpandEnvironmentVariables(\"#{File.join(root_path, config[:testingdir])}\"), \"Machine\")")
              if ENV['CI'] || ENV['DRONE'] || ENV['JENKINS_URL']
                conn.execute('[Environment]::SetEnvironmentVariable("CI", "1", "Machine")')
              end
            else
              if ENV['CI'] || ENV['DRONE'] || ENV['JENKINS_URL']
                command = "CI=1 #{command}"
              end
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
