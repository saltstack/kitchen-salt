# -*- encoding: utf-8 -*-

require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Tox < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      # Opts that carry on
      default_config :testingdir, '/testing'
      default_config :tests, []
      default_config :transport, false
      default_config :save, {}
      default_config :windows, false

      # Deprecated Opts
      default_config :verbose, false
      default_config :run_destructive, false
      default_config :xml, false
      default_config :coverage_xml, false
      default_config :types, []

      # New opts
      default_config :pytest, false
      default_config :coverage, false
      default_config :junitxml, false
      default_config :passthrough_opts, []

      def call(state)
        info("[#{name}] Verify on instance #{instance.name} with state=#{state}")
        root_path = (config[:windows] ? '%TEMP%\\kitchen' : '/tmp/kitchen')
        if ENV['KITCHEN_TESTS']
          ENV['KITCHEN_TESTS'].split(' ').each{|test| config[:tests].push(test)}
        end
        toxenv = instance.suite.name
        if config[:pytest]
          toxenv = "#{toxenv}-pytest"
        else
          toxenv = "#{toxenv}-runtests"
        end
        if config[:coverage]
          toxenv = "#{toxenv}-coverage"
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
        config[:save][File.join(root_path, config[:testingdir], 'artifacts')] = 'artifacts'

        command = [
          'tox -c',
          File.join(root_path, config[:testingdir], 'tox.ini'),
          "-e #{toxenv}",
          '--',
          '--sysinfo',
          '--output-columns=120',
          (config[:junitxml] ? junitxml : ''),
          (config[:windows] ? "--names-file=#{root_path}\\testing\\tests\\whitelist.txt" : ''),
          (config[:transport] ? "--transport=#{config[:transport]}" : ''),
          (config[:verbose] ? '-v' : ''),
          (config[:run_destructive] ? "--run-destructive" : ''),
          config[:passthrough_opts].join(' '),
          config[:tests].join(' '),
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
            config[:save].each do |remote, local|
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
                error("Failed to copy #{remote} to #{local} :: ${e}")
              end
            end
          end
        end
        debug("[#{name}] Verify completed.")
      end
    end
  end
end
