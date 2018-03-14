# -*- encoding: utf-8 -*-

require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Runtests < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :testingdir, '/testing'
      default_config :python_bin, 'python2'
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
        root_path = (config[:windows] ? '$env:TEMP\\kitchen' : '/tmp/kitchen')
        if ENV['KITCHEN_TESTS']
          ENV['KITCHEN_TESTS'].split(' ').each{|test| config[:tests].push(test)}
        end
        command = [
          (config[:windows] ? 'python.exe' : config[:python_bin]),
          File.join(root_path, config[:testingdir], '/tests/runtests.py'),
          '--sysinfo',
          '--output-columns=80',
          (config[:windows] ? "--names-file=#{root_path}\\testing\\tests\\whitelist.txt" : ''),
          (config[:transport] ? "--transport=#{config[:transport]}" : ''),
          (config[:verbose] ? '-vv' : '-v'),
          (config[:run_destructive] ? "--run-destructive" : ''),
          (config[:coverage_xml] ? "--coverage-xml=#{config[:coverage_xml]}" : ''),
          (config[:xml] ? "--xml=#{config[:xml]}" : ''),
          config[:types].collect{|type| "--#{type}"}.join(' '),
          config[:tests].collect{|test| "-n #{test}"}.join(' '),
          '2>&1',
        ].join(' ')
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
