# -*- encoding: utf-8 -*-

require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Salttox < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :testingdir, '/testing'
      default_config :verbose, false
      default_config :run_destructive, false
      default_config :xml, false
      default_config :coverage_xml, false
      default_config :types, []
      default_config :tests, []
      default_config :transport, false
      default_config :save, {}
      default_config :windows, false

      def call(state)
        info("[#{name}] Verify on instance #{instance.name} with state=#{state}")
        root_path = (config[:windows] ? '%TEMP%\\kitchen' : '/tmp/kitchen')
        if ENV['KITCHEN_TESTS']
          ENV['KITCHEN_TESTS'].split(' ').each{|test| config[:tests].push(test)}
        end
        command = [
          'tox -c',
          File.join(root_path, config[:testingdir], 'tox.ini'),
          "-e #{instance.suite.name}",
          '--',
          '--sysinfo',
          '--output-columns=80',
          (config[:windows] ? "--names-file=#{root_path}\\testing\\tests\\whitelist.txt" : ''),
          (config[:transport] ? "--transport=#{config[:transport]}" : ''),
          (config[:verbose] ? '-v' : ''),
          (config[:run_destructive] ? "--run-destructive" : ''),
          (config[:coverage_xml] ? "--cov=salt/ --cov-report xml:#{config[:coverage_xml]}" : ''),
          (config[:xml] ? "--junitxml=#{config[:xml]}" : ''),
          config[:types].collect{|type| "--#{type}"}.join(' '),
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
              conn.execute(sudo("chown -R $USER #{root_path}"))
            end
            conn.execute(sudo(command))
          ensure
            config[:save].each do |remote, local|
              unless config[:windows]
                conn.execute(sudo("chmod -R +r #{remote}"))
              end
              info("Copying #{remote} to #{local}")
              conn.download(remote, local)
            end
          end
        end
        debug("[#{name}] Verify completed.")
      end
    end
  end
end
