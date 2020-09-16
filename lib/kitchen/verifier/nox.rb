# -*- encoding: utf-8 -*-

require "date"
require "kitchen/errors"
require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Nox < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :testingdir, '/testing'
      default_config :tests, []
      default_config :save, {}
      default_config :windows, nil
      default_config :verbose, false
      default_config :run_destructive, false
      default_config :runtests, false
      default_config :coverage, false
      default_config :junitxml, false
      default_config :from_filenames, []
      default_config :enable_filenames, false
      default_config :passthrough_opts, []
      default_config :output_columns, 120
      default_config :sysinfo, true
      default_config :sys_stats, false
      default_config :environment_vars, {}
      default_config :zip_windows_artifacts, false

      def call(state)
        if config[:windows].nil?
          # Since windows is not set, lets try and guess since kitchen actually knows this infomation
          if instance.platform.os_type == 'windows'
            config[:windows] = true
          else
            config[:windows] = false
          end
        end
        debug("Detected platform for instance #{instance.name}: #{instance.platform.os_type}. Config's windows setting value: #{config[:windows]}")
        if (ENV['ONLY_DOWNLOAD_ARTEFACTS'] || '') == '1'
          only_download_artefacts = true
        else
          only_download_artefacts = false
        end
        if (ENV['DONT_DOWNLOAD_ARTEFACTS'] || '') == '1'
          dont_download_artefacts = true
        else
          dont_download_artefacts = false
        end
        if only_download_artefacts and dont_download_artefacts
          error_msg = "The environment variables 'ONLY_DOWNLOAD_ARTEFACTS' or 'DONT_DOWNLOAD_ARTEFACTS' cannot be both set to '1'"
          error(error_msg)
          raise ActionFailed, error_msg
        end
        if only_download_artefacts
          info("[#{name}] Only downloading artefacts from instance #{instance.name} with state=#{state}")
        else
          info("[#{name}] Verify on instance #{instance.name} with state=#{state}")
        end
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
        elsif config[:runtests] == true
          noxenv = "runtests-zeromq"
        else
          # Default to pytest-zeromq
          noxenv = "pytest-zeromq"
        end

        # Is the nox env already including the Python version?
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
            if not config[:verbose]
              config[:verbose] = true
            end
          else
            sys_stats = ''
          end
        elsif noxenv.include? "runtests"
          tests = config[:tests].collect{|test| "-n #{test}"}.join(' ')
          sys_stats = ''
        end

        if config[:enable_filenames] and ENV['CHANGE_TARGET'] and ENV['BRANCH_NAME'] and ENV['FORCE_FULL'] != 'true'
          require 'git'
          repo = Git.open(Dir.pwd)
          config[:from_filenames] = repo.diff("origin/#{ENV['CHANGE_TARGET']}",
                                              "origin/#{ENV['BRANCH_NAME']}").name_status.keys.select{|file| file.end_with?('.py')}
        end

        if config[:junitxml]
          junitxml = File.join(root_path, config[:testingdir], 'artifacts', 'xml-unittests-output')
          if noxenv.include? "pytest"
            junitxml = "--junitxml=#{File.join(junitxml, "test-results-#{DateTime.now.strftime('%Y%m%d%H%M%S.%L')}.xml")}"
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
          ].join(' ')
          command = "#{command} #{extra_command}"
        else
          command = "#{command} #{tests}"
        end

        environment_vars = {}
        if ENV['CI'] || ENV['DRONE'] || ENV['JENKINS_URL']
          environment_vars['CI'] = 1
        end
        # Hash insert order matters, that's why we define a new one and merge
        # the one from config
        environment_vars.merge!(config[:environment_vars])

        if config[:windows]
          command = "cmd.exe /c --% \"#{command}\" 2>&1"
        end
        instance.transport.connection(state) do |conn|
          begin
            if config[:windows]
              conn.execute('$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")')
              conn.execute("$env:PythonPath = [Environment]::ExpandEnvironmentVariables(\"#{File.join(root_path, config[:testingdir])}\")")
              conn.execute("[Environment]::SetEnvironmentVariable(\"KitchenTestingDir\", [Environment]::ExpandEnvironmentVariables(\"#{File.join(root_path, config[:testingdir])}\"), \"Machine\")")
              environment_vars.each do |key, value|
                conn.execute("[Environment]::SetEnvironmentVariable(\"#{key}\", \"#{value}\", \"Machine\")")
              end
            else
              command_env = []
              environment_vars.each do |key, value|
                command_env.push("#{key}=#{value}")
              end
              if not command_env.empty?
                command = "env #{command_env.join(' ')} #{command}"
              end
              begin
                conn.execute(sudo("chown -R $USER #{root_path}"))
              rescue => e
                error("Failed to chown #{root_path} :: #{e}")
              end
            end
            if not only_download_artefacts
              info("Running Command: #{command}")
              conn.execute(sudo(command))
            end
          ensure
            if not dont_download_artefacts
              save.each do |remote, local|
                if config[:windows]
                  if config[:zip_windows_artifacts]
                    begin
                      conn.execute("7z.exe a #{remote}artifacts.zip #{remote}")
                    rescue => e
                      begin
                        info("7z.exe failed, attempting zip with powershell Compress-Archive")
                        conn.execute("powershell Compress-Archive #{remote} #{remote}artifacts.zip -Force")
                      rescue => e2
                        error("Failed to create zip")
                      end
                    end
                  end
                else
                  begin
                    conn.execute(sudo("chmod -R +r #{remote}"))
                  rescue => e
                    error("Failed to chown #{remote} :: #{e}")
                  end
                end
                begin
                  info("Copying #{remote} to #{local}")
                  if config[:windows]
                    if config[:zip_windows_artifacts]
                      conn.download(remote + "artifacts.zip", local + "/artifacts.zip")
                      system('unzip -o artifacts.zip')
                      system('rm artifacts.zip')
                    end
                  else
                    conn.download(remote, local)
                  end
                rescue => e
                  error("Failed to copy #{remote} to #{local} :: #{e}")
                end
              end
            end
          end
        end
        if only_download_artefacts
          info("[#{name}] Download artefacts completed.")
        else
          debug("[#{name}] Verify completed.")
        end
      end
    end
  end
end
